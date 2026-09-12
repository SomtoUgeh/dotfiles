#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# ///
"""Renew an SSH host's configured Executor Cloud login and verify a GitHub read."""

import argparse
import base64
import json
from pathlib import Path
import queue
import re
import shlex
import subprocess
import sys
import tempfile
import threading
import time
from urllib.parse import parse_qs, urlsplit
import urllib.request
import urllib.error
import webbrowser


def authorization_port(url, cloud_url, authorization_endpoint):
    parsed = urlsplit(url)
    endpoint = urlsplit(authorization_endpoint)
    if (parsed.scheme != "https" or parsed.username or parsed.password
            or (parsed.netloc, parsed.path) != (endpoint.netloc, endpoint.path)):
        raise ValueError("Unexpected OAuth authorization endpoint")
    query = parse_qs(parsed.query)
    if query.get("resource") != [cloud_url] or query.get("code_challenge_method") != ["S256"]:
        raise ValueError("Unexpected OAuth resource or PKCE method")
    redirect = urlsplit(query.get("redirect_uri", [""])[0])
    if (redirect.scheme != "http" or redirect.hostname not in ("localhost", "127.0.0.1")
            or redirect.username or redirect.password or redirect.path != "/oauth/callback"
            or redirect.query or redirect.fragment or not redirect.port):
        raise ValueError("Unexpected OAuth callback; refusing to forward it")
    if not 1024 <= redirect.port <= 65535:
        raise ValueError("Unsafe OAuth callback port")
    return redirect.port


def discover_endpoint(cloud_url):
    parsed = urlsplit(cloud_url)
    if parsed.scheme != "https" or parsed.username or parsed.password or parsed.path != "/mcp":
        raise ValueError("Expected a credential-free HTTPS cloud MCP URL")
    origin = f"https://{parsed.netloc}"
    request = urllib.request.Request(
        origin + "/.well-known/oauth-authorization-server",
        headers={"User-Agent": "executor-cloud-login/1.0", "Accept": "application/json"},
    )
    try:
        with urllib.request.urlopen(request, timeout=15) as response:
            metadata = json.load(response)
    except urllib.error.HTTPError as error:
        raise RuntimeError(f"OAuth discovery returned HTTP {error.code}; check Cloudflare access for this computer") from None
    except urllib.error.URLError:
        raise RuntimeError("OAuth discovery could not connect; check this computer's network") from None
    endpoint = metadata["authorization_endpoint"]
    if urlsplit(endpoint).scheme != "https":
        raise ValueError("OAuth authorization endpoint must use HTTPS")
    return endpoint


def pump(stream, events):
    for line in stream:
        events.put(line)
    events.put(None)


def stop(process):
    if process is not None and process.poll() is None:
        process.terminate()
        try:
            process.wait(timeout=5)
        except subprocess.TimeoutExpired:
            process.kill()
            process.wait()


def login(host, check_local=False):
    if not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9._-]*", host):
        raise ValueError("Use a configured SSH host alias")
    source = Path(__file__).resolve().with_name("executor_cloud_remote.py").read_bytes()
    code = "import base64; exec(base64.b64decode(" + repr(base64.b64encode(source).decode()) + "))"
    remote = shlex.join(["timeout", "350s", "python3", "-u", "-c", code,
                         *(["--check-local"] if check_local else [])])
    ssh = ["ssh", "-o", "ConnectTimeout=15", "-o", "ServerAliveInterval=15"]
    events = queue.Queue()
    process = subprocess.Popen([*ssh, "-T", "-o", "ClearAllForwardings=yes", host, remote],
                               stdin=subprocess.PIPE, stdout=subprocess.PIPE, text=True)
    threading.Thread(target=pump, args=(process.stdout, events), daemon=True).start()
    forwarding = None
    ready = False
    cloud_url = None
    seen = set()
    try:
        with tempfile.TemporaryDirectory(prefix="executor-login-") as directory:
            deadline = time.monotonic() + 350
            while time.monotonic() < deadline:
                try:
                    line = events.get(timeout=1)
                except queue.Empty:
                    continue
                if line is None:
                    break
                event = json.loads(line)
                kind = event["kind"]
                if kind == "config":
                    cloud_url = event["url"]
                elif kind == "local_ready":
                    print("Local Executor is running and responding.", flush=True)
                elif kind == "authorize":
                    url = event["url"]
                    if url in seen:
                        continue
                    if cloud_url is None:
                        raise RuntimeError("Missing cloud configuration")
                    port = authorization_port(url, cloud_url, discover_endpoint(cloud_url))
                    stop(forwarding)
                    control = str(Path(directory) / "ssh")
                    forwarding = subprocess.Popen([*ssh, "-M", "-S", control, "-N",
                        "-o", "ExitOnForwardFailure=yes", "-o", "ControlPersist=no",
                        "-L", f"127.0.0.1:{port}:127.0.0.1:{port}",
                        "-L", f"[::1]:{port}:127.0.0.1:{port}", host],
                        stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
                    for _ in range(50):
                        if forwarding.poll() is not None:
                            raise RuntimeError(f"Cannot forward callback port {port}. Close the local process using it, then retry; no process was stopped.")
                        check = subprocess.run(["ssh", "-S", control, "-O", "check", host],
                                               stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
                        if check.returncode == 0:
                            break
                        time.sleep(0.1)
                    else:
                        raise RuntimeError("SSH callback forwarding did not become ready")
                    seen.add(url)
                    print(f"Opening your browser to renew {host}'s cloud login. Complete Cloudflare verification/consent there.", flush=True)
                    if not webbrowser.open(url):
                        raise RuntimeError("Could not open a browser on this computer")
                elif kind == "ready":
                    ready = True
                    print("Executor Cloud ready: authenticated GitHub read passed.", flush=True)
                elif kind == "failed":
                    raise RuntimeError(event["message"])
            if not ready:
                raise RuntimeError("Cloud login did not complete. Check SSH and retry the helper.")
    finally:
        # Closing stdin lets the remote controller shut down its own adapter.
        process.stdin.close()
        try:
            process.wait(timeout=8)
        except subprocess.TimeoutExpired:
            stop(process)
        stop(forwarding)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("host", nargs="?", default="altschool")
    parser.add_argument("--check-local", action="store_true", help="also start/check the VM-local Executor service")
    args = parser.parse_args()
    try:
        login(args.host, args.check_local)
    except KeyboardInterrupt:
        print("Login cancelled; temporary forwarding closed.", file=sys.stderr)
        return 130
    except (ValueError, RuntimeError) as error:
        print(f"Executor login: {error}", file=sys.stderr)
        return 1
    except Exception:
        print("Executor login failed; check SSH, cloud discovery, and the browser, then retry.", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
