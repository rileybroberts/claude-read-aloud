#!/bin/bash
# Probe 3: control verbs through the UserPromptExpansion hook. Does the block skip the model turn,
# and what comes back? (Unsettled 2)
set -u
source "$(dirname "$0")/common.sh"
SID=$(cat "$RESULTS/session-id")
PREFIX="${PREFIX:-/read-aloud}"
VERBS=("$@"); [ ${#VERBS[@]} -eq 0 ] && VERBS=("status" "auto on" "stop")
for verb in "${VERBS[@]}"; do
  echo "== $PREFIX $verb"
  T=$(python3 -c 'import time; print(time.time())')
  claude -p "${COMMON[@]}" --resume "$SID" --output-format stream-json --verbose --include-hook-events \
    "$PREFIX $verb" > "$RESULTS/probe3-$(echo "$verb" | tr ' ' '-').jsonl"
  echo "exit $? after $(python3 -c "import time; print(round(time.time()-$T,1))")s"
  F="$RESULTS/probe3-$(echo "$verb" | tr ' ' '-').jsonl"
  echo "-- event types:"; jq -r '[.type, (.subtype // ""), (.hook_event_name // .hook_name // "")] | join(" ")' "$F" | sort | uniq -c
  echo "-- assistant messages (a model turn happened if any):"; jq -r 'select(.type=="assistant") | .message.content[]? | select(.type=="text") | .text' "$F"
  echo "-- result:"; jq -r 'select(.type=="result") | {subtype, result, is_error, num_turns} | tostring' "$F"
  echo "-- hook events:"; jq -c 'select(.type | test("hook"))' "$F" | cut -c1-400
done
echo "== log tail"; grep -E 'expansion' "$STATE/log.txt" | tail -n 8
