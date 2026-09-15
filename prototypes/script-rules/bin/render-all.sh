#!/bin/zsh
# PROTOTYPE. Render every Script of one revision to results/audio/*.wav with Kokoro. Usage: bin/render-all.sh rev6
set -e
here=${0:a:h:h}
cd "$here"
rev=${1:-rev6}
for f in results/*.$rev.txt; do
  echo "== $f"
  .venv/bin/python bin/render.py "$f"
done
ls -la results/audio/
