#!/bin/zsh
# PROTOTYPE. One-time: a throwaway venv with mlx-audio so Scripts can be heard in Kokoro, the chosen Engine,
# instead of macOS say. Then a one-sentence smoke render to /tmp so the model downloads now, not mid-listen.
set -e
here=${0:a:h:h}
cd "$here"
start=$(date +%s)
uv venv --python 3.12 .venv --quiet
uv pip install --python .venv/bin/python --quiet mlx-audio "misaki[en]"   # misaki is Kokoro's G2P, an optional extra mlx-audio does not pull in
.venv/bin/python -c "import importlib.metadata as m; print('mlx-audio', m.version('mlx-audio'), 'mlx', m.version('mlx'))"
echo "install: $(( $(date +%s) - start ))s"
.venv/bin/python bin/render.py --text "Hello. This is Kokoro on MLX, standing in for the say voice." --out /tmp/kokoro-smoke.wav
