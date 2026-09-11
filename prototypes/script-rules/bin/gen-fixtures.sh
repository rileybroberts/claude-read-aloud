#!/bin/zsh
# PROTOTYPE. Generate the two Response shapes the real transcripts lacked, as genuine
# headless Claude answers (default model, no thinking cap), so they read like real Responses.
here=${0:a:h:h}
cd "$here/responses"

# 07: a one-line confirmation, the thin case.
echo "In one sentence, no list: does this repository have a CONTEXT.md at its root, and what is it for?" \
  | claude -p --no-session-persistence --output-format text > 07-short-confirmation.md

# 08: a long, table-heavy comparison, long enough to trip a four-minute duration cap.
cat <<'Q' | claude -p --no-session-persistence --output-format text > 08-long-comparison.md
I'm shipping a small Python daemon inside a Claude Code plugin for macOS teammates. Compare three ways to
manage its Python runtime: uv, pipx, and a plain venv created by the system python3. I want a comparison
table with rows for install footprint, first-run latency, reproducibility, handling of native wheels such
as MLX, upgrade story, and failure modes when the tool is missing, then a discussion of the trade-offs and a
recommendation. Around 800 words, with at least one short shell snippet showing the recommended bootstrap.
Q

wc -w 07-short-confirmation.md 08-long-comparison.md
