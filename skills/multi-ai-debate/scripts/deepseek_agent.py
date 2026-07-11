#!/usr/bin/env python3
"""DeepSeek V4 Pro 미니 에이전트 (multi-ai-debate 5번째 멤버).

DeepSeek는 에이전틱 CLI가 없고(Responses API 미지원 → codex 경로 불가),
chat completions + function calling만 제공한다. 이 스크립트가 그 위에
read_file / list_dir / write_file / run_cmd 도구 루프를 얹어 에이전트로 만든다.

사용:  deepseek_agent.py --cwd <프로젝트루트> --prompt-file <프롬프트> [--max-turns 40]
키:    ~/.deepseek/api_key 또는 $DEEPSEEK_API_KEY
출력:  최종 응답 텍스트를 stdout으로. (산출 파일은 write_file 도구로 에이전트가 직접 씀)
정책:  cwd 밖 접근 금지. run_cmd는 화이트리스트(python3/venv python·ls·wc)만.
       git 계열·삭제·리다이렉션 금지(Audit Packet 규칙과 이중 방어).
비용:  종료 시 usage 합계를 stderr로 보고.
"""
from __future__ import annotations

import argparse
import json
import os
import shlex
import subprocess
import sys
import urllib.request
from pathlib import Path

# OpenAI 호환 엔드포인트 — env로 교체 가능(GLM 등 타 provider 재사용).
API = os.environ.get("AGENT_API_URL", "https://api.deepseek.com/v1/chat/completions")
MODEL = os.environ.get("AGENT_MODEL") or os.environ.get("DEEPSEEK_MODEL", "deepseek-v4-pro")

TOOLS = [
    {"type": "function", "function": {
        "name": "read_file",
        "description": "프로젝트 내 텍스트 파일을 읽는다(경로는 cwd 상대).",
        "parameters": {"type": "object", "properties": {
            "path": {"type": "string"},
            "max_bytes": {"type": "integer", "default": 200000}},
            "required": ["path"]}}},
    {"type": "function", "function": {
        "name": "list_dir",
        "description": "디렉토리 목록(경로는 cwd 상대, 기본 '.').",
        "parameters": {"type": "object", "properties": {
            "path": {"type": "string", "default": "."}}}}},
    {"type": "function", "function": {
        "name": "write_file",
        "description": "산출 파일을 쓴다(경로는 cwd 상대). 지시된 산출 파일 외 쓰기 금지.",
        "parameters": {"type": "object", "properties": {
            "path": {"type": "string"}, "content": {"type": "string"}},
            "required": ["path", "content"]}}},
    {"type": "function", "function": {
        "name": "run_cmd",
        "description": "검증용 명령 실행. 허용: python3/venv python 스크립트, ls, wc. git·rm 등 금지.",
        "parameters": {"type": "object", "properties": {
            "cmd": {"type": "string"}}, "required": ["cmd"]}}},
]

ALLOWED_CMD0 = {"python3", "ls", "wc", "cat", "head", "tail", "grep"}


def _safe(root: Path, rel: str) -> Path:
    p = (root / rel).resolve()
    if not str(p).startswith(str(root.resolve())):
        raise ValueError(f"cwd 밖 접근 거부: {rel}")
    return p


def do_tool(root: Path, name: str, args: dict) -> str:
    try:
        if name == "read_file":
            p = _safe(root, args["path"])
            data = p.read_bytes()[: int(args.get("max_bytes", 200000))]
            return data.decode("utf-8", errors="replace")
        if name == "list_dir":
            p = _safe(root, args.get("path", "."))
            return "\n".join(sorted(x.name + ("/" if x.is_dir() else "") for x in p.iterdir())[:300])
        if name == "write_file":
            p = _safe(root, args["path"])
            p.parent.mkdir(parents=True, exist_ok=True)
            p.write_text(args["content"], encoding="utf-8")
            return f"written: {args['path']} ({len(args['content'])} chars)"
        if name == "run_cmd":
            toks = shlex.split(args["cmd"])
            if not toks:
                return "빈 명령"
            base = Path(toks[0]).name
            if base not in ALLOWED_CMD0 and not toks[0].endswith("/python"):
                return f"거부됨(화이트리스트 외): {base}"
            if any(t in ("git",) or t.startswith(">") or t == "rm" for t in toks):
                return "거부됨(git/rm/리다이렉션 금지)"
            r = subprocess.run(toks, cwd=root, capture_output=True, text=True, timeout=600)
            out = (r.stdout + r.stderr)[-8000:]
            return f"exit={r.returncode}\n{out}"
    except Exception as exc:  # noqa: BLE001
        return f"도구 오류: {exc}"
    return f"알 수 없는 도구: {name}"


def call_api(key: str, messages: list, tools: list) -> dict:
    extra = {}
    # AGENT_THINKING=disabled → z.ai류 reasoning 억제(비용 절감). 미설정 시 provider 기본.
    th = os.environ.get("AGENT_THINKING")
    if th:
        extra["thinking"] = {"type": th}
    body = json.dumps({**extra, "model": MODEL, "messages": messages, "tools": tools,
                       "temperature": 0.3}).encode()
    req = urllib.request.Request(API, data=body, headers={
        "Content-Type": "application/json", "Authorization": f"Bearer {key}"})
    with urllib.request.urlopen(req, timeout=600) as r:
        return json.load(r)


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--cwd", required=True)
    ap.add_argument("--prompt-file", required=True)
    ap.add_argument("--max-turns", type=int, default=40)
    a = ap.parse_args()

    key = os.environ.get("AGENT_API_KEY") or os.environ.get("DEEPSEEK_API_KEY") or \
        (Path.home() / ".deepseek/api_key").read_text().strip()
    root = Path(a.cwd).resolve()
    prompt = Path(a.prompt_file).read_text(encoding="utf-8")

    messages = [
        {"role": "system", "content":
         "당신은 multi-AI 연구 토론의 참여자다. 도구로 원문을 직접 읽고 근거를 대조하라. "
         "git 조작·소스 수정 금지. 산출은 지시된 파일 하나만 write_file로 작성. "
         "응답 첫 부분에 read-set(실제 읽은 파일)을 선언하라."},
        {"role": "user", "content": prompt},
    ]
    usage_in = usage_out = 0
    for turn in range(a.max_turns):
        resp = call_api(key, messages, TOOLS)
        u = resp.get("usage", {})
        usage_in += u.get("prompt_tokens", 0); usage_out += u.get("completion_tokens", 0)
        msg = resp["choices"][0]["message"]
        messages.append(msg)
        calls = msg.get("tool_calls")
        if not calls:
            print(msg.get("content") or "")
            break
        for tc in calls:
            fn = tc["function"]
            try:
                args = json.loads(fn.get("arguments") or "{}")
            except json.JSONDecodeError:
                args = {}
            result = do_tool(root, fn["name"], args)
            messages.append({"role": "tool", "tool_call_id": tc["id"],
                             "content": result[:60000]})
    else:
        print("[deepseek_agent] max-turns 도달", file=sys.stderr)

    cost = usage_in/1e6*0.435 + usage_out/1e6*0.87  # cache-hit 미분리 상한
    print(f"[usage] in={usage_in:,} out={usage_out:,} tok  비용상한≈${cost:.4f}",
          file=sys.stderr)
    return 0


if __name__ == "__main__":
    sys.exit(main())
