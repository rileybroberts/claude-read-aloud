## Managing the daemon's Python runtime: uv vs. pipx vs. system venv

Latency figures below are order-of-magnitude estimates for a warm network on Apple Silicon, not measurements from your hardware — worth benchmarking once on a teammate's laptop before you commit.

| | **uv** | **pipx** | **plain venv (`/usr/bin/python3`)** |
|---|---|---|---|
| **Install footprint** | One static Rust binary, ~40 MB, plus a shared global cache. Can also download its own CPython (~30 MB/version). No Python needed to bootstrap. | Small itself, but needs a pre-existing Python and pip; in practice arrives via Homebrew (~few hundred MB if Homebrew isn't already there). One venv per app under `~/.local/pipx/venvs`. | Zero extra tooling — but the Command Line Tools shim behind `/usr/bin/python3` is a ~1–2 GB install if the teammate has never triggered it. |
| **First-run latency** | Cold: ~5–15 s (fetch interpreter + wheels). Warm: venv from the hardlinked cache in well under a second; `uv run` on an already-synced script is ~50–150 ms. | Cold: ~15–40 s (stdlib venv + pip resolve + download). Warm: pipx re-resolves on install, so re-installs are near-cold; running an installed app is fast. | Cold: `python3 -m venv` ~2–5 s, then pip resolve/download ~15–45 s. Warm: fast to activate, but nothing is cached across venvs. |
| **Reproducibility** | Strongest. `uv.lock` (or `uv lock --script`) pins the full transitive graph with hashes, cross-platform, plus `requires-python` and an exact interpreter version. `--exclude-newer` gives you a time-pinned index. | Weak. pipx resolves at install time from whatever the index offers that day; pinning means shipping your own fully-pinned constraints file and remembering to pass it. | Weak by default, workable by hand: a hash-pinned `requirements.txt` + `pip install --require-hashes`. But the *interpreter* is pinned to whatever the OS shipped — 3.9.6 on current CLT, which is already past EOL. |
| **Native wheels (MLX)** | Best. uv's managed interpreters are native arm64 python-build-standalone builds, so wheel tags resolve cleanly; parallel downloads make the big MLX wheels noticeably faster. Refuses to silently build from source if you set `--only-binary`. | Fine once the underlying Python is a native arm64 build, which Homebrew's is. Inherits any tag weirdness from that interpreter. | Riskiest. Apple's python3 is a universal2 build; arch/tag mismatches (and anything running under Rosetta) turn "no matching wheel" into a source build that fails, or worse, into an x86_64 environment where MLX simply isn't installable. 3.9 also cuts you off from newer MLX releases. |
| **Upgrade story** | `uv self update` for the tool; `uv lock --upgrade-package mlx` for a single dep; interpreter bumps are a one-line `requires-python` change. Old versions stay in the cache, so rollback is cheap. | `pipx upgrade <app>` / `pipx reinstall-all`. Simple for a CLI, but it upgrades to *latest*, so you can't easily express "move to this exact set". Interpreter bumps mean `pipx reinstall --python`. | Manual. `pip install -U`, or blow away the venv and rebuild — which is also your only real rollback. Interpreter upgrades are outside your control entirely: an OS update can change Python underneath you. |
| **Missing-tool failure mode** | Clean and detectable: `command -v uv` fails, you print one install line, or bootstrap it yourself into a plugin-local prefix. Never touches the user's global Python. | Two layers can be missing (pipx *and* Homebrew), and the fix is a multi-minute install you can't reasonably automate inside a plugin hook. | Worst failure mode: on a machine without CLT, invoking `/usr/bin/python3` pops a **GUI installer dialog** and blocks. A plugin hook hangs with no output until someone notices the window. |

### Trade-offs

The plain-venv route's appeal is "no dependencies," but on macOS that's an illusion. You depend on the CLT shim, on an EOL 3.9, and on Apple's universal2 interpreter behaving well with MLX's arm64 wheels — three things you don't control and can't pin. Its failure mode is also the only one that blocks on a modal dialog, which is disqualifying for something invoked from a hook.

pipx is the right tool for the wrong shape of problem. It's built to expose a CLI app on `$PATH` for a human. Your daemon is an implementation detail of a plugin: teammates shouldn't have it on their PATH, and you want it pinned, not "latest." pipx gives you neither locking nor interpreter management, and it's the least likely of the three to already be installed.

uv's real cost is that it's a young, fast-moving third-party binary from a single vendor, and you're adding a non-Python dependency to a Python project. That's a genuine supply-chain and churn consideration. In exchange you get the only option that pins the interpreter *and* the dependency graph, the only one with a fast warm path suitable for per-invocation startup, and the only one whose absence is a clean, scriptable check.

### Recommendation

Use **uv**, with the daemon declaring its deps inline (PEP 723) and a committed `uv.lock`, and a bootstrap that installs uv into a plugin-local prefix rather than mutating the teammate's shell config.

```sh
#!/bin/sh
set -eu
PLUGIN_HOME="${CLAUDE_PLUGIN_ROOT:-$HOME/.claude/read-aloud}"
UV="$PLUGIN_HOME/bin/uv"

if [ ! -x "$UV" ]; then
  echo "read-aloud: installing uv into $PLUGIN_HOME (one time)" >&2
  UV_INSTALL_DIR="$PLUGIN_HOME/bin" UV_NO_MODIFY_PATH=1 \
    sh -c "$(curl -fsSL https://astral.sh/uv/install.sh)"
fi

# --locked fails loudly instead of silently re-resolving.
exec "$UV" run --locked --script "$PLUGIN_HOME/daemon.py" "$@"
```

Two guardrails worth adding: pin the uv version you install (`UV_VERSION=…`) so the bootstrap is itself reproducible, and set `UV_PYTHON_DOWNLOADS=automatic` plus an explicit `requires-python = ">=3.12"` in the script header so MLX resolves against a native arm64 interpreter regardless of what's on the machine.
