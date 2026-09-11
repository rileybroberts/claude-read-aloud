# PROTOTYPE: `/read-aloud` Command with macOS `say` as a stand-in Engine

Throwaway. Answers [ticket #4](https://github.com/rileybroberts/claude-read-aloud/issues/4) on the
[Read Aloud v1 design map](https://github.com/rileybroberts/claude-read-aloud/issues/1). Nothing here is
production code; the validated decisions go to the ticket, and from there to `docs/spec.md`.

This is an integration prototype in the shape the ticket asked for (a real plugin exercised by real Claude Code
sessions), not the prototype skill's HTML state-machine or UI-variant shapes; neither fits a "do the mechanics
work and does it feel right" question.

## What it is

`plugin/` is a Claude Code plugin loaded with `--plugin-dir`:

- `hooks/hooks.json`: a `Stop` hook that saves every Response to `~/.claude/read-aloud-proto/sessions/<session>/response.md`,
  and a `UserPromptExpansion` hook that handles `/read-aloud stop|status|auto on|off` with no model turn.
- `skills/read-aloud/SKILL.md`: the Command. `context: fork`, model haiku, effort low, `allowed-tools` for the plugin CLI only.
  The saved Response is injected with `` !`read-aloud-ctl response --session ${CLAUDE_SESSION_ID}` ``. The fork writes the
  Script paragraph by paragraph, each paragraph a heredoc into `read-aloud-ctl say`, and ends with the one line `Reading started.`
- `agents/read-aloud-writer.md`: the fork's agent (Bash only, haiku).
- `bin/read-aloud-ctl`: one Python 3 stdlib CLI for every caller (hooks, skill, probes) plus the detached player
  that feeds paragraphs to `say` in order. Every action appends to `~/.claude/read-aloud-proto/log.txt`; `read-aloud-ctl report`
  prints the timeline of the last Reading (time to first audio, stalls).
- `skills/rap-probe/SKILL.md`: a probe skill for permission matching inside a fork.

State lives under `~/.claude/read-aloud-proto/` (**PROTOTYPE, wipe me**: `plugin/bin/read-aloud-ctl reset`).
`config.json` there takes `silent` (write audio to files instead of the speaker), `rate`, `voice`, `auto`, `threshold`.

## Run it

Interactive, audible, from any checkout of this branch:

```
claude --plugin-dir /path/to/prototypes/read-aloud-say/plugin
```

Then ask anything long, and when the Response lands type `/read-aloud`. Try `/read-aloud brief`, `/read-aloud --show`,
`/read-aloud stop`, `/read-aloud status`, `/read-aloud auto on`. Afterwards, `plugin/bin/read-aloud-ctl report` shows the timeline.

To try the fast variant (extended thinking off for the whole session, see finding 9):

```
MAX_THINKING_TOKENS=0 claude --plugin-dir /path/to/prototypes/read-aloud-say/plugin
```

Non-interactive probes (silent; they use `claude -p` with `--permission-mode manual --permission-prompts none`, so
anything not pre-approved by the skill is denied):

```
probes/smoke.sh            # the CLI alone, no Claude
probes/probe1-capture.sh   # Stop hook capture, hook cost, detached-child survival
probes/probe2-command.sh   # /read-aloud end to end in the probe-1 session, with debug timing
probes/probe3-control.sh   # stop / auto on / status through the expansion hook
probes/probe4-fork-env.sh  # permission matching and env inside a fork
```

Outputs land in `results/` (stream-json event logs, debug log, the captured Response).

## Findings (2026-09-11, Claude Code 2.1.269, Bedrock, haiku 4.5 as the writer)

Numbers refer to the "Unsettled" list in the
[mechanics research](https://github.com/rileybroberts/claude-read-aloud/blob/research/skill-and-hook-mechanics/docs/research/skill-and-hook-mechanics.md).

1. **Fork carries the main session id.** `CLAUDE_CODE_SESSION_ID` inside the fork's Bash equals the main session's id, and
   `${CLAUDE_SESSION_ID}` in the skill body is substituted before the injected command runs. Either route works.
2. **UserPromptExpansion block, print mode.** No model turn (`num_turns: 0`), about 1.5 s end to end. The result reads
   `UserPromptExpansion operation blocked by hook:` / `<reason>` / `Original prompt: /read-aloud-proto:read-aloud stop`.
   Interactive rendering still needs the human (checklist below).
   **Matcher gotcha:** the hook's `matcher` must be the full command name, `read-aloud-proto:read-aloud`; a matcher of
   `read-aloud` never fired. Input fields: `command_name`, `command_args`, `command_source` (`plugin`), `expansion_type`,
   `prompt`, plus the common fields.
3. **Stop fires on the relay turn.** After the fork finishes, `Stop` runs with `last_assistant_message` = `Reading started.`
   The sentinel check catches it. In print mode the main model made no API call at all for the relay (only haiku usage
   was billed); interactive mode may differ.
   **Design bug found:** the relay's Stop must **not** overwrite the saved Response, or the next `/read-aloud` reads
   "Reading started." aloud. Fixed in the prototype by skipping the write when the message is the sentinel.
4. **Detached children survive.** Children spawned by the synchronous Stop hook (both `start_new_session=True` and a plain
   `Popen`) were alive 20 s after `claude -p` exited. No launchd agent is needed; macOS has no `setsid`, Python's
   `start_new_session` does the job and gives a process group to kill for stop.
5. **`allowed-tools: Bash(${CLAUDE_PLUGIN_ROOT}/bin/read-aloud-ctl *)`** matches: a direct call, a heredoc on stdin, and
   `ctl ... | cat`. It does **not** match `uv run ctl ...`, `VAR=1 ctl ...`, or `cd /tmp && ctl ...` (all denied). So the
   real CLI must be invoked by absolute path with no prefix; a `uv`-managed Python must hide behind a shebang or wrapper.
   The grant held for the fork's whole run in print mode (9 tool calls).
6. Sandbox: not tested (sandbox is off on this machine).
7. **On-screen footprint, print mode:** the only visible output is `Reading started.` Interactive footprint needs the human.
8. Not this ticket (Auto mode writer), but see 9 for the thinking finding that applies to it.
9. **Time to first audio (stand-in Engine).** Measured from the keystroke (the expansion hook's timestamp) to the first `say`:

   | variant | first audio | notes |
   |---|---|---|
   | separate `start` call, thinking on | 11.6 s | first fork turn 6.9 s, of which about 5.5 s generating a thinking block |
   | `start` folded into first `say`, thinking on | 12.6 s | first turn 11.3 s: haiku drafted the whole Script in a 3.9K-char thinking block first |
   | folded, `MAX_THINKING_TOKENS=0` | **5.4 s** | first turn 4.2 s (1.3 s first byte); later paragraphs every 2.3 to 2.7 s |

   Fixed costs: expansion hook to injection about 1.0 s (includes a one-time 0.9 s zsh shell snapshot, which an interactive
   session has usually already paid); paragraph write to `say` start under 50 ms.
   **Streaming keeps ahead of speech:** paragraphs of 30 to 75 words take 9 to 20 s to speak at 190 wpm and arrive every
   2.5 s, so the speaker never waited on the writer in any run (the report would print a "speaker waited" marker).
   The writer finishes a 370-word Response in about 25 to 35 s while playback runs about 2 minutes.
   Extended thinking is the dominant cost and `MAX_THINKING_TOKENS` is session-wide; whether a fork or agent can disable
   thinking on its own is an open question for the spec.
10. **Race, hook write vs immediate `/read-aloud`:** the Stop hook costs 1 to 3 ms per turn and completes before the turn
    ends; in every probe the injection read a file written seconds earlier. Interactive fast typing still needs the human.

Also settled: the plugin skill is registered as `read-aloud-proto:read-aloud` but `/read-aloud` resolves to it when
unambiguous; the skill's `agent:` field needs the **prefixed** name `read-aloud-proto:read-aloud-writer` (the bare name
silently fell back to `general-purpose`); interrupt-and-replace works from both the fork path and the hook path, killing
the player's process group takes `say` with it; a fork that dies before `end` leaves a player idling until its 300 s timeout.

## Human checklist (the part only a listener can settle)

Run the interactive command above (try both with and without `MAX_THINKING_TOKENS=0`), then:

1. Ask a long question (code block, table, list). When it lands, type `/read-aloud`. How long until you hear speech? Does
   the Script sound like someone talking, and does it handle the code, table, and list sensibly? Any silences between paragraphs?
2. What appears on screen while the fork runs, and when it finishes? Is there a `/tasks` footer hint, a task row, and a
   relayed `Reading started.` turn? Is that acceptable as the one-line notice?
3. Mid-Reading, type `/read-aloud stop`. How does the blocked expansion render (plain line, banner, error)? Did speech stop
   within a second? Did anything land in the conversation?
4. Mid-Reading, type `/read-aloud` again. Does the new Reading replace the old one cleanly?
5. `/read-aloud status`, `/read-aloud auto on`, `/read-aloud auto off`: rendering only (auto does nothing yet).
6. `/read-aloud brief` on a long Response; `/read-aloud --show` to see the Script the fork wrote.
7. Type `/read-aloud` the instant a Response lands. Does it read the new Response? (`read-aloud-ctl report` shows the file's age.)
8. Quit Claude Code mid-Reading. Does speech continue? (Expected yes.)
9. `plugin/bin/read-aloud-ctl report` for the measured time to first audio in interactive mode.

Record the verdict on ticket #4, then `plugin/bin/read-aloud-ctl reset`.
