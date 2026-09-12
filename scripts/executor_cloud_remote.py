"""Private SSH-side MCP probe. Stdout is a JSON event stream, never raw tools/logs."""

import json
import os
from pathlib import Path
import queue
import re
import subprocess
import sys
import threading
import time
import tomllib
import urllib.request


def emit(kind, **fields):
    print(json.dumps({"kind": kind, **fields}), flush=True)


def pump(stream, kind, events):
    for line in stream:
        events.put((kind, line))
    events.put((kind, None))


def probe(check_local=False):
    config = tomllib.loads((Path.home() / ".codex/config.toml").read_text())
    cloud = config["mcp_servers"]["executor_cloud"]
    if cloud.get("enabled") is False:
        raise RuntimeError("Executor Cloud is disabled in the VM configuration")
    args = cloud["args"]
    if (len(args) < 2 or not args[0].endswith("/mcp-remote/dist/proxy.js")
            or cloud.get("env") or cloud.get("env_vars")):
        raise RuntimeError("Unsupported cloud adapter configuration; review it before login")
    if check_local:
        subprocess.run(["systemctl", "--user", "start", "sh.executor.daemon.service"],
                       check=True, stdout=subprocess.DEVNULL)
        with urllib.request.urlopen("http://127.0.0.1:4789/", timeout=10) as response:
            if response.status != 200:
                raise RuntimeError("Local Executor HTTP check failed")
        emit("local_ready")
    emit("config", url=args[1])
    events = queue.Queue()
    process = subprocess.Popen([cloud["command"], *args], stdin=subprocess.PIPE,
                               stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                               text=True, bufsize=1, start_new_session=True)
    for stream, kind in [(process.stdout, "out"), (process.stderr, "err"), (sys.stdin, "control")]:
        threading.Thread(target=pump, args=(stream, kind, events), daemon=True).start()

    def send(message):
        process.stdin.write(json.dumps({"jsonrpc": "2.0", **message}) + "\n")
        process.stdin.flush()

    try:
        send({"id": 1, "method": "initialize", "params": {
            "protocolVersion": "2025-03-26", "capabilities": {},
            "clientInfo": {"name": "executor-cloud-login", "version": "1.0.0"}}})
        deadline = time.monotonic() + 45
        awaiting_auth = False
        phase = "initialization"
        while time.monotonic() < deadline:
            try:
                kind, line = events.get(timeout=1)
            except queue.Empty:
                continue
            if kind == "control" and line is None:
                raise RuntimeError("Login controller disconnected")
            if kind == "err" and line:
                for url in re.findall(r"https://[^\s\x1b]+", line):
                    if "code_challenge=" in url:
                        if not awaiting_auth:
                            deadline = time.monotonic() + 330
                            awaiting_auth = True
                            phase = "browser authorization"
                        emit("authorize", url=url)
                continue
            if kind != "out":
                continue
            if line is None:
                raise RuntimeError("Cloud adapter closed before verification completed")
            message = json.loads(line)
            if "error" in message:
                raise RuntimeError("Cloud MCP request failed; renew login or inspect the server")
            request_id = message.get("id")
            if request_id == 1:
                deadline = time.monotonic() + 45
                phase = "cloud read"
                send({"method": "notifications/initialized"})
                send({"id": 2, "method": "tools/call", "params": {
                    "name": "skills", "arguments": {"name": "execute"}}})
            elif request_id == 2:
                if message.get("result", {}).get("isError"):
                    raise RuntimeError("Could not read the Executor execute skill")
                send({"id": 3, "method": "tools/call", "params": {
                    "name": "execute", "arguments": {"code":
                        "const r = await tools.github.org.personal.get_me({}); return {ok:r.ok === true};"}}})
            elif request_id == 3:
                result = message.get("result", {})
                structured = result.get("structuredContent", {})
                if (result.get("isError") or structured.get("status") != "completed"
                        or structured.get("result", {}).get("ok") is not True):
                    raise RuntimeError("Cloud GitHub read did not succeed; check its connection/policy")
                emit("ready")
                return
        raise RuntimeError(f"Executor {phase} timed out; SSH access is independent of Executor")
    finally:
        if process.poll() is None:
            os.killpg(process.pid, 15)
            try:
                process.wait(timeout=5)
            except subprocess.TimeoutExpired:
                os.killpg(process.pid, 9)
                process.wait()


if __name__ == "__main__":
    try:
        probe("--check-local" in sys.argv)
    except Exception as error:
        # Exception messages from config/protocol parsing can contain private data.
        emit("failed", message=str(error) if isinstance(error, RuntimeError)
             else "VM configuration, local service, or MCP transport check failed")
        sys.exit(1)
