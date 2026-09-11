#!/bin/bash
# Dump the timeline of every Reading in the prototype log into results/timelines.txt.
set -u
source "$(dirname "$0")/common.sh"
OUT="$RESULTS/timelines.txt"
{
  echo "Timelines of every Reading the probes produced (silent mode: say -o to a file plus simulated playback time)."
  echo "Generated $(date '+%Y-%m-%d %H:%M %Z') by read-aloud-ctl report."
  echo
  for rid in $(grep ' start ' "$STATE/log.txt" | cut -d' ' -f4- | jq -r .reading); do
    "$CTL" report --reading "$rid"
    echo
  done
} > "$OUT"
wc -l "$OUT"
