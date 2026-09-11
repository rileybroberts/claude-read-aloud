#!/bin/bash
# Probe 1: does the Stop hook capture the Response per session, how much does it cost per turn,
# and does a detached child of the hook outlive the hook and the session? (Unsettled 4 and 10)
set -u
source "$(dirname "$0")/common.sh"
SID=$(uuidgen | tr 'A-Z' 'a-z')
echo "$SID" > "$RESULTS/session-id"
echo "== session $SID"
echo '{"silent": true, "rate": 190}' > "$STATE/config.json"
rm -f "$STATE/detach-probe.json"

T=$(python3 -c 'import time; print(time.time())')
RAP_PROBE_DETACH=1 claude -p "${COMMON[@]}" --session-id "$SID" --output-format json \
  "In about 350 words, explain how a shell pipeline differs from a subshell. Include one short bash code block, a two-column markdown table comparing them, and a bulleted list of three gotchas." \
  > "$RESULTS/probe1.json"
echo "claude exit $? after $(python3 -c "import time; print(round(time.time()-$T,1))")s"

echo "== result vs captured file"
jq -r .result "$RESULTS/probe1.json" > "$RESULTS/probe1-result.md"
wc -w "$RESULTS/probe1-result.md" "$STATE/sessions/$SID/response.md"
if diff -q "$RESULTS/probe1-result.md" "$STATE/sessions/$SID/response.md" > "$RESULTS/probe1-diff.txt"; then echo "IDENTICAL"; else echo "DIFFER (see results/probe1-diff.txt)"; diff "$RESULTS/probe1-result.md" "$STATE/sessions/$SID/response.md" | head -n 10; fi
echo "== stop-hook input keys (sizes)"; cat "$STATE/sessions/$SID/last-stop-input.json"
echo "== stop-hook log line"; grep stop-hook "$STATE/log.txt" | tail -n 1

echo "== detached-process survival"
cat "$STATE/detach-probe.json"; echo
S=$(jq .probe_setsid_pid "$STATE/detach-probe.json"); P=$(jq .probe_plain_pid "$STATE/detach-probe.json")
for wait in 2 8 20; do
  sleep "$wait"
  s=alive; p=alive
  ps -p "$S" > /dev/null || s=dead
  ps -p "$P" > /dev/null || p=dead
  echo "t+$((wait))s (cumulative): setsid child $S $s; plain child $P $p"
done
kill "$S" "$P" 2> /dev/null || true
