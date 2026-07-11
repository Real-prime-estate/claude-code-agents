#!/usr/bin/env python3
"""grok ACP → MCP bridge (single file, stdlib only).

Exposes the Grok CLI agent (which speaks Zed's Agent Client Protocol over
`grok agent stdio`) as an MCP stdio server with two tools:

  grok(prompt, cwd?, timeout_s?)      — new ACP session, run prompt, return final text
  grok_reply(session_id, prompt, ...) — continue an existing ACP session

Design notes
- MCP side: newline-delimited JSON-RPC on stdin/stdout (same framing codex/claude use).
- ACP side: one `grok agent stdio` child per bridge process, lazily spawned;
  sessions multiplex inside it. authenticate uses the cached token
  (~/.grok/auth.json), i.e. the already-logged-in Grok account.
- Agent→client requests (session/request_permission) are auto-approved with the
  first allow-ish option — equivalent of `--permission-mode bypassPermissions`
  in the CLI (this bridge is for the multi-ai-debate workflow where bypass is
  always on). fs capabilities are advertised as false so the agent uses its own
  tools instead of asking the client.
"""

from __future__ import annotations

import json
import os
import queue
import shutil
import subprocess
import sys
import threading
import time
from typing import Any

PROTOCOL_VERSION = '2025-06-18'
DEFAULT_TIMEOUT_S = 900.0
ACP_SPAWN_TIMEOUT_S = 60.0

TOOLS = [
    {
        'name': 'grok',
        'description': (
            'Run a prompt in a NEW Grok agent session (xAI Grok CLI via ACP). '
            'The agent has its own workspace tools (read/write/shell) rooted at '
            'cwd. Returns the final assistant text plus the session_id, which '
            'can be passed to grok_reply to continue the conversation.'
        ),
        'inputSchema': {
            'type': 'object',
            'properties': {
                'prompt': {'type': 'string', 'description': 'Task / question for Grok.'},
                'cwd': {
                    'type': 'string',
                    'description': 'Workspace directory for the session (absolute path).',
                },
                'timeout_s': {
                    'type': 'number',
                    'description': f'Max seconds to wait (default {DEFAULT_TIMEOUT_S:.0f}).',
                },
            },
            'required': ['prompt'],
        },
    },
    {
        'name': 'grok_reply',
        'description': 'Continue an existing Grok session created by the grok tool.',
        'inputSchema': {
            'type': 'object',
            'properties': {
                'session_id': {'type': 'string'},
                'prompt': {'type': 'string'},
                'timeout_s': {'type': 'number'},
            },
            'required': ['session_id', 'prompt'],
        },
    },
]


def log(msg: str) -> None:
    print(f'[grok-acp-bridge] {msg}', file=sys.stderr, flush=True)


class AcpClient:
    """Minimal ACP (Agent Client Protocol) client over `grok agent stdio`."""

    def __init__(self) -> None:
        self._proc: subprocess.Popen[str] | None = None
        self._next_id = 100
        self._lock = threading.Lock()

    def _spawn(self) -> None:
        # reasoning effort: grok effort는 [low, medium, high, xhigh, max]. auto 없음 →
        # 최대(max)보다 한 단계 아래 xhigh (2026-07-03 사용자 지시). GROK_EFFORT로 override.
        # --effort는 전역 플래그라 서브커맨드(agent stdio) 앞에 와야 한다.
        effort = os.environ.get('GROK_EFFORT', 'xhigh')
        # grok 실행 파일 해석: $GROK_BIN → PATH → 기본 설치 위치(~/.grok/bin).
        # (Windows에서 ~/.grok/bin이 PATH에 없어도 동작하게.)
        grok_bin = os.environ.get('GROK_BIN') or shutil.which('grok') \
            or os.path.expanduser('~/.grok/bin/grok.exe' if os.name == 'nt' else '~/.grok/bin/grok')
        self._proc = subprocess.Popen(
            [grok_bin, '--effort', effort, 'agent', 'stdio'],
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=subprocess.DEVNULL,
            text=True,
            encoding='utf-8',  # 로케일(cp949 등) 아닌 UTF-8 고정 — 프롬프트에 한글 포함
            bufsize=1,
        )
        # Windows select()는 소켓 전용 → 파이프는 리더 스레드 + 큐로 크로스플랫폼 통일.
        self._lines = queue.Queue()
        threading.Thread(target=self._pump_stdout, args=(self._proc,), daemon=True).start()
        init = self._request(
            'initialize',
            {
                'protocolVersion': 1,
                'clientCapabilities': {'fs': {'readTextFile': False, 'writeTextFile': False}},
            },
            timeout=ACP_SPAWN_TIMEOUT_S,
        )
        if 'result' not in init:
            raise RuntimeError(f'ACP initialize failed: {init}')
        auth = self._request(
            'authenticate', {'methodId': 'cached_token'}, timeout=ACP_SPAWN_TIMEOUT_S
        )
        if 'result' not in auth:
            raise RuntimeError(
                f'ACP authenticate failed (grok login 필요?): {auth}'
            )
        log('grok agent spawned + authenticated')

    def _ensure(self) -> None:
        if self._proc is None or self._proc.poll() is not None:
            self._spawn()

    def _send(self, obj: dict[str, Any]) -> None:
        assert self._proc and self._proc.stdin
        self._proc.stdin.write(json.dumps(obj) + '\n')
        self._proc.stdin.flush()

    def _pump_stdout(self, proc: subprocess.Popen) -> None:
        try:
            for line in proc.stdout:
                self._lines.put(line)
        except Exception:
            pass
        self._lines.put(None)

    def _read_msg(self, timeout: float) -> dict[str, Any] | None:
        assert self._proc
        try:
            line = self._lines.get(timeout=timeout)
        except queue.Empty:
            return None
        if line is None:
            raise RuntimeError('grok agent stdio closed')
        line = line.strip()
        if not line:
            return None
        return json.loads(line)

    def _handle_agent_request(self, msg: dict[str, Any]) -> None:
        """Auto-answer agent→client requests (permission bypass semantics)."""
        method = msg.get('method', '')
        if method == 'session/request_permission':
            options = msg.get('params', {}).get('options', [])
            chosen = None
            for opt in options:
                if 'allow' in str(opt.get('kind', '')).lower():
                    chosen = opt.get('optionId')
                    break
            if chosen is None and options:
                chosen = options[0].get('optionId')
            self._send(
                {
                    'jsonrpc': '2.0',
                    'id': msg['id'],
                    'result': {'outcome': {'outcome': 'selected', 'optionId': chosen}},
                }
            )
            log(f'auto-approved permission request (option={chosen})')
        else:
            self._send(
                {
                    'jsonrpc': '2.0',
                    'id': msg['id'],
                    'error': {'code': -32601, 'message': f'bridge: unsupported {method}'},
                }
            )

    def _request(
        self,
        method: str,
        params: dict[str, Any],
        timeout: float,
        collect_session: str | None = None,
    ) -> dict[str, Any]:
        """Send a request; pump messages until its response arrives.

        If collect_session is given, agent_message_chunk updates for that
        session are accumulated into result['_bridge_text'].
        """
        with self._lock:
            self._next_id += 1
            rid = self._next_id
            self._send({'jsonrpc': '2.0', 'id': rid, 'method': method, 'params': params})
            chunks: list[str] = []
            deadline = time.monotonic() + timeout
            while time.monotonic() < deadline:
                msg = self._read_msg(timeout=min(5.0, max(0.1, deadline - time.monotonic())))
                if msg is None:
                    continue
                if msg.get('id') == rid and ('result' in msg or 'error' in msg):
                    if collect_session is not None and 'result' in msg:
                        msg['result']['_bridge_text'] = ''.join(chunks)
                    return msg
                if 'method' in msg and 'id' in msg:
                    self._handle_agent_request(msg)
                elif msg.get('method') == 'session/update' and collect_session is not None:
                    upd = msg.get('params', {})
                    if upd.get('sessionId') == collect_session:
                        u = upd.get('update', {})
                        if u.get('sessionUpdate') == 'agent_message_chunk':
                            chunks.append(u.get('content', {}).get('text', ''))
            raise TimeoutError(f'{method} timed out after {timeout:.0f}s')

    def new_session(self, cwd: str) -> str:
        self._ensure()
        resp = self._request(
            'session/new', {'cwd': cwd, 'mcpServers': []}, timeout=ACP_SPAWN_TIMEOUT_S
        )
        if 'result' not in resp:
            raise RuntimeError(f'session/new failed: {resp}')
        return str(resp['result']['sessionId'])

    def prompt(self, session_id: str, text: str, timeout: float) -> tuple[str, str]:
        self._ensure()
        resp = self._request(
            'session/prompt',
            {'sessionId': session_id, 'prompt': [{'type': 'text', 'text': text}]},
            timeout=timeout,
            collect_session=session_id,
        )
        if 'result' not in resp:
            raise RuntimeError(f'session/prompt failed: {resp}')
        return resp['result'].get('_bridge_text', ''), str(
            resp['result'].get('stopReason', '')
        )


ACP = AcpClient()


def tool_call(name: str, args: dict[str, Any]) -> tuple[str, dict[str, Any]]:
    """Return (final_text, structured) — text is the clean assistant output so an
    MCP client can use it directly; session_id/stop_reason go in structured."""
    timeout = float(args.get('timeout_s') or DEFAULT_TIMEOUT_S)
    if name == 'grok':
        cwd = args.get('cwd') or '.'
        sid = ACP.new_session(cwd)
        text, stop = ACP.prompt(sid, args['prompt'], timeout)
        return text, {'session_id': sid, 'stop_reason': stop}
    if name == 'grok_reply':
        text, stop = ACP.prompt(args['session_id'], args['prompt'], timeout)
        return text, {'session_id': args['session_id'], 'stop_reason': stop}
    raise ValueError(f'unknown tool: {name}')


def mcp_respond(rid: Any, result: dict[str, Any]) -> None:
    print(json.dumps({'jsonrpc': '2.0', 'id': rid, 'result': result}), flush=True)


def mcp_error(rid: Any, code: int, message: str) -> None:
    print(
        json.dumps({'jsonrpc': '2.0', 'id': rid, 'error': {'code': code, 'message': message}}),
        flush=True,
    )


def main() -> None:
    for raw in sys.stdin:
        raw = raw.strip()
        if not raw:
            continue
        try:
            msg = json.loads(raw)
        except json.JSONDecodeError:
            continue
        method = msg.get('method', '')
        rid = msg.get('id')
        if method == 'initialize':
            mcp_respond(
                rid,
                {
                    'protocolVersion': PROTOCOL_VERSION,
                    'capabilities': {'tools': {}},
                    'serverInfo': {'name': 'grok-acp-bridge', 'version': '0.1.0'},
                },
            )
        elif method == 'notifications/initialized':
            continue
        elif method == 'tools/list':
            mcp_respond(rid, {'tools': TOOLS})
        elif method == 'tools/call':
            params = msg.get('params', {})
            try:
                text, structured = tool_call(params.get('name', ''), params.get('arguments', {}))
                mcp_respond(
                    rid,
                    {'content': [{'type': 'text', 'text': text}], 'structuredContent': structured},
                )
            except Exception as exc:  # noqa: BLE001 — bridge must report, not die
                log(f'tool error: {exc}')
                mcp_respond(
                    rid,
                    {
                        'content': [{'type': 'text', 'text': f'ERROR: {exc}'}],
                        'isError': True,
                    },
                )
        elif rid is not None:
            mcp_error(rid, -32601, f'unsupported method: {method}')


if __name__ == '__main__':
    main()
