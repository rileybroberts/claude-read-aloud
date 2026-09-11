# PROTOTYPE probe helpers. Source me.
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PLUGIN="$HERE/plugin"
CTL="$PLUGIN/bin/read-aloud-ctl"
STATE="$HOME/.claude/read-aloud-proto"
RESULTS="$HERE/results"
mkdir -p "$RESULTS" "$STATE"
# Strict permission posture: nothing is pre-approved except what the skill's allowed-tools grants; any prompt is a denial.
COMMON=(--plugin-dir "$PLUGIN" --model sonnet --effort low --permission-mode manual --permission-prompts none)
