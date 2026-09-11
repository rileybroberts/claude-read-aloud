#!/bin/bash
# Probe 4: inside a forked skill, which command shapes does the allowed-tools rule cover, and does the fork's
# Bash carry the main session id in CLAUDE_CODE_SESSION_ID? (Unsettled 1 and 5)
set -u
source "$(dirname "$0")/common.sh"
CMD="${1:-/rap-probe}"
SID=$(uuidgen | tr 'A-Z' 'a-z')
echo "== fresh session $SID, prompt: $CMD"
claude -p "${COMMON[@]}" --session-id "$SID" --output-format stream-json --verbose --forward-subagent-text \
  "$CMD" > "$RESULTS/probe4-stream.jsonl"
echo "claude exit $?"
echo "== fork tool calls and their outcomes"
jq -r 'select(.type=="assistant") | .message.content[]? | select(.type=="tool_use") | "CALL  " + (.input.command // "" | .[0:120] | gsub("\n";" / "))' "$RESULTS/probe4-stream.jsonl"
jq -r 'select(.type=="user") | .message.content[]? | select(.type=="tool_result") | "RESULT " + (if .is_error then "ERROR " else "ok    " end) + ((.content | if type=="array" then map(.text // "") | join(" ") else tostring end) | .[0:200] | gsub("\n";" / "))' "$RESULTS/probe4-stream.jsonl"
echo "== final result"
jq -r 'select(.type=="result") | .result' "$RESULTS/probe4-stream.jsonl"
echo "== env events logged by the CLI (label -> session id seen in the fork's environment); main session is $SID"
grep ' env ' "$STATE/log.txt" | tail -n 8 | cut -d' ' -f4- | jq -r --arg sid "$SID" '.label + ": CLAUDE_CODE_SESSION_ID=" + (.CLAUDE_CODE_SESSION_ID // "unset") + (if .CLAUDE_CODE_SESSION_ID == $sid then " (matches main)" else " (DIFFERS)" end) + " cwd=" + .cwd + " tty=" + (.stdin_tty|tostring)'
