#!/bin/bash
# Probe 2: the /read-aloud Command end to end in the session probe 1 created.
# Checks: injection of the saved Response, allowed-tools grant inside the fork, paragraph streaming,
# the sentinel relay, whether Stop fires on the relay, and time to first audio (Unsettled 1, 3, 5, 7, 10).
set -u
source "$(dirname "$0")/common.sh"
SID=$(cat "$RESULTS/session-id")
CMD="${1:-/read-aloud}"
echo "== session $SID, prompt: $CMD"
echo '{"silent": true, "rate": 190}' > "$STATE/config.json"

T=$(python3 -c 'import time; print(time.time())')
rm -f "$RESULTS/probe2-debug.log"
claude -p "${COMMON[@]}" --resume "$SID" --output-format stream-json --verbose --include-hook-events --forward-subagent-text \
  --debug-file "$RESULTS/probe2-debug.log" "$CMD" > "$RESULTS/probe2-stream.jsonl"
echo "claude exit $? after $(python3 -c "import time; print(round(time.time()-$T,1))")s"

echo "== event types in the stream"
jq -r '[.type, (.subtype // ""), (.hook_event_name // .hook_name // ""), (if .parent_tool_use_id then "subagent" else "" end)] | join(" ")' "$RESULTS/probe2-stream.jsonl" | sort | uniq -c | sort -rn
echo "== hook events"
jq -c 'select(.type=="system" and (.subtype|test("hook"))) | {subtype, hook_event_name, hook_name, exit: (.exit_code // "")}' "$RESULTS/probe2-stream.jsonl" | sort | uniq -c
echo "== debug log: timestamped skill, fork, subagent, hook, and API lines"
grep -iE 'skill|fork|subagent|agent|hook|querying|stream_request|model' "$RESULTS/probe2-debug.log" | grep -vE 'PreToolUse|PostToolUse' | cut -c1-220 | head -n 80
echo "== fork tool calls (Bash commands, first 160 chars)"
jq -r 'select(.type=="assistant") | .message.content[]? | select(.type=="tool_use") | .input.command // .input.description // (.name) | .[0:160]' "$RESULTS/probe2-stream.jsonl"
echo "== fork text (forwarded)"
jq -r 'select(.type=="assistant" and .parent_tool_use_id != null) | .message.content[]? | select(.type=="text") | .text' "$RESULTS/probe2-stream.jsonl"
echo "== final result (what the main model printed)"
jq -r 'select(.type=="result") | .result' "$RESULTS/probe2-stream.jsonl"
echo "== Stop hook lines since the command"
grep -E 'expansion-hook|response|stop-hook' "$STATE/log.txt" | tail -n 6
echo "== timeline"
"$CTL" report
