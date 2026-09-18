---
status: accepted
date: 2026-09-18
ticket: https://github.com/rileybroberts/claude-read-aloud/issues/7
---

# Synthesizer-only Engines behind one Daemon per user

An Engine does one thing: turn one Chunk of text into audio samples. Its whole contract is `load()`, which brings the model up and runs one warm-up synthesis; `synthesize(text, voice, speed)`, which yields float32 PCM arrays at a fixed `sample_rate`; `voices()`; and a `state` of `cold`, `loading`, `ready`, or `failed` with a reason. Speed is a multiplier each adapter maps (Kokoro passes it through, `say` turns it into words per minute). Everything else is shared and lives in one Daemon per user, reached only through the plugin's hooks over a unix socket at `~/.claude/read-aloud/daemon.sock`: the Writer's process, the Chunker, the ordered Chunk queue, the Player (one output stream at the Engine's sample rate, started on the first array, aborted on stop), the last Script per session on disk, the config read on every request, and the registry of live interactive sessions that keeps the model warm. Stop is one path: abort the stream, clear the queue, discard in-flight synthesis, kill the Writer's process group. The speaker is the shared resource, so a Reading from any session replaces the one playing. The Engine is named in config; a load failure is reported and never silently replaced by `say`. The `say` adapter fits the seam by writing a 24 kHz WAV per Chunk and reading it back, since `say` refuses to write to a pipe.

## Considered options

- **Engines that play their own audio** (`say` natively, mlx-audio's `--play`): two stop paths, two gap tunings, and no single owner of the speaker across sessions.
- **One Daemon per session**: multiplies the resident model (estimated 0.6 to 1 GB each) and breaks the rule that exactly one MLX process owns the GPU. Queueing Readings across sessions instead of replacing was rejected too: there is one listener.
- **Automatic fallback to `say`** when Kokoro fails to load: hides breakage behind a worse voice, the same reason the Writer has no stripped-text fallback (ADR 0001).
- **A fixed idle timeout** instead of a session registry: simpler, but every first Reading after a lull would start cold at roughly 4 to 5 s to first audio against about 2.5 s warm. The registry (SessionStart registers the session with the Claude Code pid, SessionEnd unregisters, a 60 s sweep drops dead pids, a 10 min grace after the last session) keeps the daemon warm exactly while Claude Code is open.
- **Running `mlx_audio.server` verbatim**: no queue, stop, Writer, or per-session state of its own.
- **One Python for hooks and daemon**: the hook would die with the environment it is supposed to report on. Hooks and the CLI run on the macOS system `python3` with the standard library only; the daemon runs on the uv-managed Python 3.12 environment under `${CLAUDE_PLUGIN_DATA}`.
- **A version-number check for plugin updates**: needs a bump on every release and misses local edits. The daemon instead compares the request's plugin root and its own source files' modification times against launch, and exits for respawn on any difference.

## Consequences

- The Daemon holds an estimated 0.6 to 1 GB while any interactive Claude Code session is open; the Engine prototype measures the real figure.
- `say` pays about 1 s per Chunk for the temp WAV round trip, acceptable for a fallback voice.
- The hook-to-daemon verbs (`read`, `stop`, `status`, `show`, `register`, `unregister`, `shutdown`) are the plugin's internal API. User-facing subcommands map onto them, and config edits never reach the daemon: the hook writes the file, the daemon reads it per request.
- A Reading that arrives while the Engine is loading is accepted: the Writer starts at once, Chunks buffer until the Engine is ready, and the Reading fails with a report if the load passes 20 s.
- Two things are assumed and must be verified by the Engine prototype: that a hook's parent pid is the Claude Code process, and that a `systemMessage` from a synchronous Stop hook renders as a visible line.
