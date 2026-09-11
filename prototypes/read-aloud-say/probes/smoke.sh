#!/bin/bash
# PROTOTYPE smoke test for read-aloud-ctl alone (no Claude involved). Silent mode: say writes to files, no speaker.
set -u
HERE="$(cd "$(dirname "$0")/.." && pwd)"
CTL="$HERE/plugin/bin/read-aloud-ctl"
STATE="$HOME/.claude/read-aloud-proto"

echo "== reset, silent config"
"$CTL" reset
mkdir -p "$STATE" && echo '{"silent": true, "rate": 190}' > "$STATE/config.json"

echo "== capture (fake Stop hook input)"
printf '%s' '{"session_id":"smoke-1","hook_event_name":"Stop","stop_hook_active":false,"last_assistant_message":"Here is a test response with enough words to count as readable. It goes on for a while so that the word count clears the threshold of sixty words. Worktrees let you check out several branches at once in separate directories that share one object store. Each has its own index and HEAD. That is the whole trick, and it is a good one for parallel agents. One more sentence for luck."}' | "$CTL" capture
cat "$STATE/sessions/smoke-1/last-stop-input.json"; echo
"$CTL" response --session smoke-1 | head -c 80; echo

echo "== expansion: plain /read-aloud (should print nothing, exit 0)"
printf '%s' '{"session_id":"smoke-1","hook_event_name":"UserPromptExpansion","command_name":"read-aloud","command_args":"","prompt":"x"}' | "$CTL" expansion; echo "(exit $?)"
echo "== expansion: stop with nothing playing (should block)"
printf '%s' '{"session_id":"smoke-1","command_name":"read-aloud-proto:read-aloud","command_args":"stop"}' | "$CTL" expansion

echo "== start / say (heredoc) / say (--text) / end"
RID=$("$CTL" start --session smoke-1); echo "rid=$RID"
"$CTL" say --reading "$RID" <<'RAP'
This is the first short paragraph, so audio starts quickly.
RAP
sleep 1
"$CTL" say --reading "$RID" --text "Second paragraph here with a few more words in it so it takes a moment to speak in silent mode."
"$CTL" end --reading "$RID"
"$CTL" status
sleep 5

echo "== interrupt-and-replace"
RID2=$("$CTL" start --session smoke-1)
"$CTL" say --reading "$RID2" --text "Replacement reading."
"$CTL" end --reading "$RID2"
sleep 1.5
"$CTL" status

echo "== report first"
"$CTL" report --reading "$RID"
echo "== report second"
"$CTL" report --reading "$RID2"

echo "== expansion stop while playing"
RID3=$("$CTL" start --session smoke-1)
"$CTL" say --reading "$RID3" --text "A long paragraph that will keep the player busy for several seconds while we test stopping it from the expansion hook path, with enough words to matter."
sleep 0.5
printf '%s' '{"session_id":"smoke-1","command_name":"read-aloud","command_args":"stop"}' | "$CTL" expansion
sleep 0.3
if ps -p "$(cat "$STATE/readings/$RID3/player.pid")" > /dev/null; then echo "PLAYER STILL ALIVE (bad)"; else echo "player $RID3 gone (expected)"; fi

echo "== log tail"
tail -n 14 "$STATE/log.txt"
