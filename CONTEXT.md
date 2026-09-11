# Read Aloud

A Claude Code plugin that speaks Claude's answers so long responses are listened to rather than skimmed. This glossary fixes the words the design uses.

## Language

**Response**:
The final message of the most recent assistant turn. Excludes the narration between tool calls, tool output, and thinking.
_Avoid_: Output, answer, reply, last message

**Script**:
The spoken-friendly rendition of a Response, written by the model with judgement about what to keep, describe, or drop. Full content by default; a brief variant carries only the key points.
_Avoid_: Summary, transcript, rewrite, TTS text

**Reading**:
One playback of a Script from start to finish or until stopped.
_Avoid_: Playback, speech, utterance

**Engine**:
A text-to-speech backend that turns a Script into audible speech. Engines are interchangeable behind one interface.
_Avoid_: Voice, TTS provider, model, backend

**Trigger**:
The event that starts a Reading. Either a Command or Auto mode.
_Avoid_: Hook, invocation

**Command**:
The Trigger where the user asks for a Reading after a Response has landed, via the `/read-aloud` slash command.
_Avoid_: Manual mode, on-demand

**Auto mode**:
The Trigger where every Response starts a Reading until the user turns it off.
_Avoid_: Always-on, continuous, streaming mode
