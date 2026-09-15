---
status: accepted
date: 2026-09-15
ticket: https://github.com/rileybroberts/claude-read-aloud/issues/6
---

# One bare headless Writer, run by the daemon, for both Triggers

The Script has to be written by a model, and the obvious model, the conversation's own, cannot do it well. A forked `/read-aloud` skill inherits the session's extended thinking (6 to 7 s of first audio, with no per-skill switch), ends in a relay turn the main model paraphrased four times in six so a sentinel could not keep Auto mode quiet, and cannot be killed on stop or replace. Auto mode has no model turn at all: a Stop hook fires when the Response lands. So both Triggers use one **Writer**: a separate `claude -p --bare --no-session-persistence --model haiku --effort low` process with `MAX_THINKING_TOKENS=0`, the Script rules as its system prompt and the Response wrapped in `<response>` tags on stdin, its text deltas streamed through the sentence chunker to the Engine. The daemon spawns it, using the environment the hook forwarded verbatim with the request, and kills its process group on stop or replace. The Command is handled entirely by a `UserPromptExpansion` hook that blocks the expansion, hands the saved Response and verb to the daemon, and shows the block's one-line reason as the Notice; the slash command's skill body is only a fallback message. Measured on Bedrock: first token 1.9 to 2.1 s, a 350-word Script in 5.2 s, $0.0075 per Script, and a listening verdict of "a person explaining".

## Considered options

- **Output style** that makes the main model append a hidden Script to every Response: taxes every main turn with Opus output tokens, cannot be hidden from the screen or transcript, and is undone by any other output style.
- **Mechanical markdown strip**, no rewrite: free and instant, but reads code as syntax, walks tables row by row, and speaks paths with "slash"; rejected even as a failure fallback, since a stripped Reading hides Writer breakage.
- **Direct API call from the daemon**: does not help subscription logins either and adds credential handling the CLI already does.
- **Running the Writer without `--bare`**: measured 2.7 to 3.6 s to first token, and the Writer then loads the user's CLAUDE.md, auto-memory, every plugin, and hooks, including this plugin's own Stop hook.
- **The hook spawns the Writer** instead of the daemon: fresh environment every turn, but the daemon cannot kill a process it did not start. Forwarding the hook's environment with each request gets the freshness without giving up ownership.

## Consequences

- `--bare` never reads OAuth or the keychain, so a claude.ai subscription login cannot run the Writer. Teammates need an API key or a Bedrock, Vertex, or Foundry environment. Accepted because the team is on Bedrock; the escape hatch is adaptive bare (bare when such an environment is present, plain `-p` otherwise).
- The Stop hook must exit at once when the recursion-guard variable is set, so the design survives dropping `--bare` later.
- Every Auto mode Reading costs a Writer call, about a dollar per 150 Responses at list price.
- The daemon keeps the last Script per session: a repeat Command replays it without a Writer call, and `show` prints it. A failed Writer is retried once, then reported; it is never disguised as a Reading.
