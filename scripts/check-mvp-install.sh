#!/usr/bin/env bash
# Build and install the public lean runtime into an isolated temporary venv.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PYTHON_BIN="${PYTHON:-python3}"

"$PYTHON_BIN" -c 'import sys; assert sys.version_info >= (3, 9)' \
    || {
        echo "error: AWT local workbench requires Python 3.9+" >&2
        exit 1
    }

temporary="$(mktemp -d)"
server_pid=""
cleanup() {
    if [[ -n "$server_pid" ]]; then
        kill "$server_pid" >/dev/null 2>&1 || true
        wait "$server_pid" 2>/dev/null || true
    fi
    rm -rf "$temporary"
}
trap cleanup EXIT
mkdir -p "$temporary/dist" "$temporary/run"

"$PYTHON_BIN" -m pip wheel \
    --no-deps \
    --no-build-isolation \
    --wheel-dir "$temporary/dist" \
    "$REPO_ROOT" >/dev/null

wheel="$(find "$temporary/dist" -maxdepth 1 -type f -name '*.whl' -print -quit)"
[[ -n "$wheel" && -f "$wheel" ]] || {
    echo "error: wheel was not created" >&2
    exit 1
}

"$PYTHON_BIN" - "$wheel" <<'PY'
from pathlib import Path
import sys
import zipfile

wheel = Path(sys.argv[1])
with zipfile.ZipFile(wheel) as archive:
    runtime = sorted(
        name for name in archive.namelist()
        if name.startswith("awt/") and not name.endswith("/")
    )
expected = sorted(
    [
        "awt/__init__.py",
        "awt/context_pack.py",
        "awt/demo-paper.md",
        "awt/mvp.py",
        "awt/mvp_index.html",
        "awt/workflow_io.py",
    ]
)
if runtime != expected:
    raise SystemExit(
        "public runtime allowlist mismatch:\n"
        f"expected={expected!r}\nobserved={runtime!r}"
    )
PY

"$PYTHON_BIN" -m venv "$temporary/venv"
"$temporary/venv/bin/python" -m pip install --no-deps "$wheel" >/dev/null

(
    cd "$temporary/run"
    "$temporary/venv/bin/python" - <<'PY'
from importlib.resources import files
import awt
from awt.mvp import WORKFLOWS

assert awt.__version__ == "0.5.0rc2"
assert len(WORKFLOWS) == 5
assert files("awt").joinpath("mvp_index.html").is_file()
assert files("awt").joinpath("demo-paper.md").is_file()
PY
    PYTHONDONTWRITEBYTECODE=1 "$temporary/venv/bin/python" -m unittest discover \
        -s "$REPO_ROOT/tests/runtime" -p 'test_*.py' >/dev/null
    "$temporary/venv/bin/awt" --help >/dev/null
)

port="$("$temporary/venv/bin/python" - <<'PY'
import socket

with socket.socket() as listener:
    listener.bind(("127.0.0.1", 0))
    print(listener.getsockname()[1])
PY
)"
(
    cd "$temporary/run"
    AWT_SESSION_DIR="$temporary/sessions" \
        "$temporary/venv/bin/awt" --host 127.0.0.1 --port "$port" \
        >"$temporary/server.log" 2>&1
) &
server_pid=$!

"$temporary/venv/bin/python" - "$port" <<'PY'
import json
import sys
import time
from urllib.error import URLError
from urllib.request import urlopen

base = f"http://127.0.0.1:{sys.argv[1]}"
for _ in range(50):
    try:
        with urlopen(base + "/api/workflows", timeout=1) as response:
            workflows = json.load(response)
        break
    except URLError:
        time.sleep(0.1)
else:
    raise SystemExit("installed AWT server did not become ready")

if len(workflows) != 5:
    raise SystemExit(f"expected five workflows, observed {sorted(workflows)}")
with urlopen(base + "/", timeout=2) as response:
    page = response.read().decode("utf-8")
with urlopen(base + "/demo-paper.md", timeout=2) as response:
    demo = response.read().decode("utf-8")
if "AWT 本地写作工作台" not in page or "A Small Demonstration Paper" not in demo:
    raise SystemExit("installed package resources were not served")
PY

kill "$server_pid"
wait "$server_pid" 2>/dev/null || true
server_pid=""

printf 'AWT lean runtime fresh-install check passed: %s\n' "$(basename "$wheel")"
