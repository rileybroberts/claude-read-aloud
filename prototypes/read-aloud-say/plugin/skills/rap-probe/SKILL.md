---
name: rap-probe
description: PROTOTYPE probe for permission matching and environment inside a forked skill. Only runs when the user types /rap-probe.
context: fork
background: false
disable-model-invocation: true
allowed-tools: Bash(${CLAUDE_PLUGIN_ROOT}/bin/read-aloud-ctl *)
model: haiku
effort: low
---

Run each of the following Bash commands exactly as written, one per tool call, in order. Do not modify them, do not combine them, and do not retry one that fails or is denied. Note for each whether it ran or was denied, and the first line of its output.

1. Direct call:

   ```
   ${CLAUDE_PLUGIN_ROOT}/bin/read-aloud-ctl env --label direct
   ```

2. Through uv run:

   ```
   uv run ${CLAUDE_PLUGIN_ROOT}/bin/read-aloud-ctl env --label uv-run
   ```

3. With a leading variable assignment:

   ```
   RAP_X=1 ${CLAUDE_PLUGIN_ROOT}/bin/read-aloud-ctl env --label var-prefix
   ```

4. With a heredoc on stdin:

   ```
   ${CLAUDE_PLUGIN_ROOT}/bin/read-aloud-ctl echo --label heredoc <<'RAP'
   hello from a heredoc
   RAP
   ```

5. Piped into cat:

   ```
   ${CLAUDE_PLUGIN_ROOT}/bin/read-aloud-ctl env --label pipe | cat
   ```

6. Chained after cd:

   ```
   cd /tmp && ${CLAUDE_PLUGIN_ROOT}/bin/read-aloud-ctl env --label cd-chain
   ```

Injected from the main session before the fork started:

!`${CLAUDE_PLUGIN_ROOT}/bin/read-aloud-ctl env --label injected`

Final message: a compact list, one line per command: its number, RAN or DENIED, and the first line of output.
