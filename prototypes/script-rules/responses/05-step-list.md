Prototype state is ready: `silent` is off, no stale player or `say` processes, Claude Code is 2.1.269, and `MAX_THINKING_TOKENS` is not set anywhere in your environment, so the two variants will differ as the probes measured.

Your part now. Open a second terminal and start Claude Code with the prototype plugin. Run the fast variant first, since it is the one the design is leaning toward:

```
MAX_THINKING_TOKENS=0 claude --plugin-dir /Users/rileyroberts/Desktop/claude-read-aloud/.claude/worktrees/prototype+read-aloud-say/prototypes/read-aloud-say/plugin
```

Then, if you have the patience, one more run without the env var for item 1 only, to feel the thinking delay.

Ask something that produces a long Response with a code block, a table, and a list, and work through this checklist. Jot a line per item and paste them back here; I'll pull the measured timings from the log myself.

1. **First Reading.** Type `/read-aloud` when the Response lands. Rough seconds to speech. Does the Script sound like a person talking? How did it handle the code, table, and list? Any dead air between paragraphs?
2. **Screen footprint.** What shows while the fork runs and when it finishes: a `/tasks` footer hint, a task row, a relayed `Reading started.` line? Is that acceptable as the one-line notice?
3. **Stop.** Mid-Reading, `/read-aloud stop`. How does the blocked expansion render, plain line or error banner? Did speech stop within a second? Did anything land in the conversation?
4. **Replace.** Mid-Reading, `/read-aloud` again. Clean handover to the new Reading?
5. **Control verbs.** `/read-aloud status`, `/read-aloud auto on`, `/read-aloud auto off`. Rendering only.
6. **Variants.** `/read-aloud brief` on a long Response, then `/read-aloud --show` to see a Script on screen.
7. **Fast typing.** Type `/read-aloud` the instant a Response lands. Did it read the new one or the previous one?
8. **Quit mid-Reading.** Exit Claude Code while speech plays. Expected: speech continues.
9. **Gut verdict.** Would you leave this on? What would make you turn it off?

Do not run `reset` afterwards; I need the log intact to report the timings.
