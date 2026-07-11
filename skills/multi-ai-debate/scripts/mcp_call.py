#!/usr/bin/env python3
"""One-shot MCP stdio client for mad-dispatch (single file, stdlib only).

Spawns an MCP stdio server (e.g. `codex mcp-server`, or the grok ACP→MCP
bridge), performs the initialize handshake, calls one tool to completion, and
prints the tool's final text result to stdout. Used by mad-dispatch.sh to drive
codex (native MCP) and grok (ACP-bridged MCP) the same way.

The tool's `prompt` argument is read from --prompt-file (avoids arg-length /
shell-escaping limits on the large Audit-Packet prompt). Extra tool arguments
(model/sandbox/cwd/timeout_s/…) come from --extra-json (a JSON object file).

These agents are agentic: given a cwd with write access they write their output
file themselves (per the Audit Packet). This client's stdout is the fallback
the dispatch supervisor uses if the file was not written.

Usage:
  mcp_call.py --tool <name> --prompt-file <path> --cwd <dir> --timeout <s> \
              [--extra-json <path>] -- <server argv...>

Exit codes: 0 ok, 1 tool/server error, 2 timeout, 3 usage/spawn error.
"""

from __future__ import annotations

import argparse
import json
import os
import queue
import subprocess
import sys
import threading
import time
from typing import Any

PROTOCOL_VERSION = "2025-06-18"


def log(msg: str) -> None:
    print(f"[mcp_call] {msg}", file=sys.stderr, flush=True)


class McpStdioClient:
    def __init__(self, server_argv: list[str]) -> None:
        self._proc = subprocess.Popen(
            server_argv,
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=subprocess.DEVNULL,
            text=True,
            encoding="utf-8",  # 로케일(cp949 등)이 아닌 UTF-8로 고정 — JSON-RPC는 UTF-8
            bufsize=1,
        )
        self._next_id = 0
        # Windows에서는 select()가 소켓 전용이라 파이프 폴링 불가 → 리더 스레드 + 큐로
        # 크로스플랫폼 통일. EOF는 None 센티널로 전달.
        self._lines: queue.Queue[str | None] = queue.Queue()
        self._reader = threading.Thread(target=self._pump_stdout, daemon=True)
        self._reader.start()

    def _pump_stdout(self) -> None:
        assert self._proc.stdout
        try:
            for line in self._proc.stdout:
                self._lines.put(line)
        except Exception:
            pass
        self._lines.put(None)

    def _send(self, obj: dict[str, Any]) -> None:
        assert self._proc.stdin
        self._proc.stdin.write(json.dumps(obj) + "\n")
        self._proc.stdin.flush()

    def _new_id(self) -> int:
        self._next_id += 1
        return self._next_id

    def _read_until(self, rid: int, deadline: float) -> dict[str, Any]:
        """Pump messages until the response for `rid` arrives.

        Notifications are ignored. Server→client requests are auto-answered so
        the agent never blocks (approvals are disabled server-side anyway).
        """
        while time.monotonic() < deadline:
            try:
                line = self._lines.get(timeout=min(5.0, max(0.1, deadline - time.monotonic())))
            except queue.Empty:
                if self._proc.poll() is not None and self._lines.empty():
                    raise RuntimeError("MCP server exited before responding")
                continue
            if line is None:
                raise RuntimeError("MCP server closed stdout")
            line = line.strip()
            if not line:
                continue
            try:
                msg = json.loads(line)
            except json.JSONDecodeError:
                continue
            if msg.get("id") == rid and ("result" in msg or "error" in msg):
                return msg
            # server→client request (elicitation/permission/sampling): auto-answer minimally.
            if "method" in msg and "id" in msg:
                self._auto_answer(msg)
            # otherwise a notification (progress/events) → ignore.
        raise TimeoutError(f"tool call timed out (id={rid})")

    def _auto_answer(self, msg: dict[str, Any]) -> None:
        method = str(msg.get("method", ""))
        # Best-effort: approve permission-like requests, else return an empty result.
        params = msg.get("params", {})
        if "permission" in method or "approval" in method:
            options = params.get("options", []) if isinstance(params, dict) else []
            chosen = None
            for opt in options:
                if "allow" in str(opt.get("kind", "")).lower() or "approve" in str(opt.get("optionId", "")).lower():
                    chosen = opt.get("optionId")
                    break
            if chosen is None and options:
                chosen = options[0].get("optionId")
            self._send({"jsonrpc": "2.0", "id": msg["id"], "result": {"outcome": {"outcome": "selected", "optionId": chosen}}})
        else:
            self._send({"jsonrpc": "2.0", "id": msg["id"], "result": {}})

    def initialize(self, deadline: float) -> None:
        rid = self._new_id()
        self._send({
            "jsonrpc": "2.0", "id": rid, "method": "initialize",
            "params": {"protocolVersion": PROTOCOL_VERSION, "capabilities": {}, "clientInfo": {"name": "mad-dispatch", "version": "0.1.0"}},
        })
        resp = self._read_until(rid, deadline)
        if "result" not in resp:
            raise RuntimeError(f"initialize failed: {resp}")
        self._send({"jsonrpc": "2.0", "method": "notifications/initialized"})

    def call_tool(self, name: str, arguments: dict[str, Any], deadline: float) -> str:
        rid = self._new_id()
        self._send({"jsonrpc": "2.0", "id": rid, "method": "tools/call", "params": {"name": name, "arguments": arguments}})
        resp = self._read_until(rid, deadline)
        if "error" in resp:
            raise RuntimeError(f"tool error: {resp['error']}")
        result = resp.get("result", {})
        parts = [c.get("text", "") for c in result.get("content", []) if isinstance(c, dict) and c.get("type") == "text"]
        text = "".join(parts)
        if result.get("isError"):
            raise RuntimeError(f"tool reported isError: {text[:500]}")
        return text

    def close(self) -> None:
        try:
            if self._proc.stdin:
                self._proc.stdin.close()
        except Exception:
            pass
        try:
            self._proc.terminate()
        except Exception:
            pass


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--tool", required=True)
    ap.add_argument("--prompt-file", required=True)
    ap.add_argument("--cwd")
    ap.add_argument("--timeout", type=float, default=900.0)
    ap.add_argument("--extra-json", help="path to a JSON object file merged into tool arguments")
    ap.add_argument("server", nargs=argparse.REMAINDER, help="-- <server argv...>")
    args = ap.parse_args()

    # 산출 텍스트(한글 포함)를 로케일 무관하게 내보낸다 — dispatch가 stdout을 파일 폴백으로 사용.
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")

    server_argv = args.server[1:] if args.server and args.server[0] == "--" else args.server
    if not server_argv:
        log("missing server argv after --")
        return 3

    with open(args.prompt_file, "r", encoding="utf-8") as f:
        prompt = f.read()
    tool_args: dict[str, Any] = {"prompt": prompt}
    if args.cwd:
        tool_args["cwd"] = args.cwd
    if args.extra_json:
        with open(args.extra_json, "r", encoding="utf-8") as f:
            tool_args.update(json.load(f))

    deadline = time.monotonic() + args.timeout
    client: McpStdioClient | None = None
    try:
        client = McpStdioClient(server_argv)
        client.initialize(deadline)
        text = client.call_tool(args.tool, tool_args, deadline)
        sys.stdout.write(text)
        sys.stdout.flush()
        return 0
    except TimeoutError as e:
        log(str(e))
        return 2
    except Exception as e:  # noqa: BLE001
        log(f"error: {e}")
        return 1
    finally:
        if client is not None:
            client.close()


if __name__ == "__main__":
    sys.exit(main())
