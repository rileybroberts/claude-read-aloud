# PROTOTYPE: the rules for turning a Response into a Script

Throwaway. Answers [ticket #5](https://github.com/rileybroberts/claude-read-aloud/issues/5) on the
[Read Aloud v1 design map](https://github.com/rileybroberts/claude-read-aloud/issues/1). Nothing here is
production code; the validated rules go to the ticket, and from there to `docs/spec.md`.

Like the [say prototype](https://github.com/rileybroberts/claude-read-aloud/tree/prototype/read-aloud-say/prototypes/read-aloud-say),
this is neither of the prototype skill's shapes (HTML state machine, UI variants). The question is "does the
Script sound right", which is judged by ear, so the artifact is a listening harness: a writer prompt, eight real
Responses, a runner that streams the writer's output to macOS `say`, and a lint pass for the rules a machine can check.

## What it is

- `prompt/rules.md`: the writer's system prompt, the deliverable. `prompt/mode-full.md` or `prompt/mode-brief.md` is
  appended for the length; the harness picks one, so the prompt has one unconditional job and no flags.
  `prompt/user.md` wraps the Response in `<response>` tags with a one-line instruction after it (finding 1).
- `responses/`: eight Responses of different shapes. Six are real Responses lifted from this repo's own sessions
  (three fixtures the model wrote to be read aloud in the say-prototype listening session, a shell-pipeline
  explanation with code and a table, a nine-step checklist, a ticket status report with a table); two were generated
  headlessly to fill gaps (`bin/gen-fixtures.sh`: a one-line confirmation, and a 930-word table-heavy comparison
  long enough to trip the duration cap).
- `bin/write-script RESPONSE.md [--brief] [--cap-words 680] [--model haiku] [--chunk] [--speak] [--tag rev]`:
  runs `claude -p --bare --no-session-persistence --model haiku --effort low` with `MAX_THINKING_TOKENS=0`, the rules as
  `--system-prompt`, and the wrapped Response on stdin. Streams `stream-json` deltas, cuts paragraphs as blank lines
  arrive (or, with `--chunk`, re-cuts mechanically: first sentence alone, then sentences up to 80 words, closing a
  chunk at the writer's blank line once it holds 20), speaks each one with `say` the moment it completes if
  `--speak`, lints the result, saves the Script to `results/<name>.<mode>.<tag>.txt`, and appends one stats line to
  `results/runs.jsonl`.
- `bin/run-all [--tag rev] [--model haiku] [--chunk] [--only 04]`: every Response in both modes, silently, four at a
  time, then a table: response words, Script words, opening words, the other chunks' words, time to the first chunk,
  total time, lint flags.
- `bin/listen results/<file>.txt [--from N]`: speaks a saved Script paragraph by paragraph with `say`. Ctrl-C stops.
- `bin/kokoro-setup.sh`, `bin/render.py`, `bin/render-all.sh`: the same Scripts in Kokoro, the Engine the map chose,
  because the `say` voice was unlistenable. Setup makes a throwaway venv with `mlx-audio` and `misaki[en]`; render
  synthesises a Script one paragraph per call (as the daemon would) into `results/audio/<name>.wav` and prints
  per-paragraph synthesis time. Needs Homebrew's `espeak-ng` (finding 9).
- Over the duration cap (default 680 words, about four minutes at 170 words a minute) the harness switches to brief
  and speaks a fixed notice first, before the writer has produced anything: "That was a long one, so here's the one
  minute version."

## Run it

Listening, in Kokoro (the rendered wavs for rev6 are already in `results/audio/`):

```
open results/audio                                                  # Finder; double-click any wav
afplay results/audio/04-code-explanation.full.rev6.wav              # or from the terminal, Ctrl-C stops
```

Writing new Scripts and rendering them:

```
bin/run-all --tag mine --chunk                                      # all eight, both modes, silent; prints the table
bin/write-script responses/04-code-explanation.md --chunk           # one Response; --speak adds the say voice
brew install espeak-ng && bin/kokoro-setup.sh                       # once: Kokoro venv + model (about 1 GB)
.venv/bin/python bin/render.py results/04-code-explanation.full.mine.txt --play   # Kokoro, then afplay
bin/render-all.sh mine                                              # every Script of one tag to results/audio/
```

Edit `prompt/rules.md`, bump the tag, run again, render, listen to what changed.

## Findings (2026-09-11, Claude Code 2.1.269, Bedrock, haiku 4.5 as the writer)

Six prompt revisions, each run over all eight Responses in both modes (fifteen runs each; the 930-word Response is
capped, so its full run is the brief run), plus one sonnet run for comparison: 106 writer calls in all.
`results/*.rev1.txt` through `*.rev6.txt` are the Scripts; `results/runs.jsonl` has every run's numbers.

1. **The Response must be wrapped, or the writer answers it.** With the rules as system prompt and the raw Response
   as the user message (rev1), haiku treated the Response as a message to itself in 3 of 15 runs: the one-line
   confirmation got "I'm ready to help. What Response would you like me to turn into a Script?", the nine-step
   checklist got "I'm Claude, an AI assistant, and I can't actually open terminals", and five other runs opened with
   "Let me read it carefully first" before the Script. Wrapping the Response in `<response>` tags, ending the user
   message with "Write the Script for the Response above. Begin with the headline sentence.", and stating in the rules
   that the Response is material, not a message, fixed every case: zero misfires in the 90 runs since.
2. **Haiku overshoots any size target by about half, and sonnet is worse.** Asked for an opening of at most 15 words,
   haiku wrote 6 to 45 (median about 20). Asked for paragraphs of 40 to 70 words, it wrote 10 to 130, the long
   ones where it merged a whole list into one paragraph and the short ones where it kept one list item per paragraph
   despite a rule against it. Sonnet 4.5 on the same rev2 prompt wrote briefs of 206 to 578 words and paragraphs up
   to 165 words, and took 5 to 16 s per Script against haiku's 2 to 7 s. So the rules are the limit, not the model;
   haiku stays the writer, and paragraph size is not a thing to enforce by prompt.
3. **Mechanical chunking holds the shape the prompt cannot.** Re-cutting the writer's stream at sentence ends (first
   sentence alone; then accumulate sentences, cutting before a chunk would pass 80 words; the writer's blank line
   closes a chunk once it holds 20) gave, over the final three revisions, chunks of 14 to 80 words with no cut inside
   a sentence and no words lost, and opened every Script with its first sentence. The checklist's one-step paragraphs
   and the 113-word merged findings both came out as 20 to 60 word chunks. The daemon already has to split over-long
   paragraphs for Kokoro's 510-phoneme cap, so this is the same code path; the writer's paragraph rules stay in the
   prompt as guidance for where thoughts end, not as the guarantee. Residual: the opening is the writer's first
   sentence, which ran to 39 or 44 words on two Responses; a clause-level cut for a first sentence over about 25
   words is possible if the Engine prototype shows first-sentence length matters for first audio.
4. **Brief is a judgement, not a length, and no phrasing changes that.** Five definitions were tried on the same
   Responses: "120 to 180 words" gave 153 to 281; "exactly three paragraphs of 40 to 60 words" gave 165 to 269;
   "three paragraphs of three sentences" gave 157 to 290; "the headline and at most six sentences" gave 130 to 340;
   "under 100 words" gave 121 to 277. Every one landed at 0.4 to 0.8 of the Response, about 45 to 100 seconds of
   speech, and the spread is by Response, not by wording: the checklist compresses to 120 words, the dense status
   report of findings stays near 280 because the writer treats every finding as essential. The capped 930-word
   Response briefed to 194 to 243 words in every revision, so the cap keeps its four-minute promise. What the spec
   can honestly say: brief is the headline plus what was decided, done, or found and what to act on, typically one
   to two minutes, asked for as "under 100 words" (rev6, the tightest). A Response under 100 words is spoken whole in
   either mode.
5. **The cap notice is the harness's, not the writer's.** Deciding brief-by-cap is a word count the caller already
   knows, so the notice is a fixed sentence spoken at t=0, before the writer's first token (which arrives 1.7 to
   2.9 s later). The writer never sees a flag, so it cannot ignore one, which was the `--show` failure in the say
   prototype. Wording to settle by ear (checklist item 6).
6. **Rules that had to be spelled out with examples**, each after a real run broke them. Code: rev4 read a shell
   snippet as "while read line semicolon do count equals count plus one semicolon done" and "less than less than open
   paren cat data close paren"; a rule with three worked examples and a list of words never to say fixed it in rev5
   ("a pipeline where one stage counts lines", "the exit status", "set dash e"). Tables: rev4 walked the retry-delay
   table row by row and invented a sixth attempt; "at most two sentences, never walk the rows" plus an example gave
   "the delays double from 250 milliseconds to 4 seconds, just under five seconds in total". Also needed explicitly:
   "slash read-aloud" for slash commands (seven times in one Script), "MAX underscore THINKING underscore TOKENS",
   "results slash interactive", a bare ISO date, "we" rewritten as "you" or "the team", backticks kept around `say`.
   After rev5 the lint finds no markdown residue and no "slash" or "underscore" in any Script.
7. **One writer call in 106 returned nothing.** The same Response rewrote cleanly on retry (45 words, 2.3 s). The
   daemon needs a retry-or-say-so path; that is the failure-handling fog item, now with a concrete case.
8. **Timing, for the Auto mode ticket.** Bare haiku, thinking off, on this machine, over the final three revisions:
   first token 1.5 to 3.3 s after launch, first chunk (the first sentence) 1.7 to 3.6 s, a 350-word full Script done
   in 4 to 8 s, $0.005 to $0.011 per Script (list price, Bedrock). With the chunker the first spoken unit is one sentence, so first audio is
   bounded by first-sentence time plus Engine synthesis of one sentence, not by the writer's first paragraph.
9. **Kokoro on this machine (M4 Max, mlx-audio 0.5.4, Kokoro-82M, voice af_heart), for the Engine ticket.** Rendering
   the fifteen rev6 Scripts one paragraph per call: model load 0.4 s from the local cache; the first `generate` call in
   a process costs 2.3 to 2.7 s (pipeline creation, a one-time warm-up the daemon pays once); after that a 20-word
   chunk synthesises in about 0.25 s and a 60 to 80 word chunk in 0.6 to 0.9 s, about 35 times faster than real
   time, at about 173 words a minute of speech. So a warm daemon adds well under half a second to first audio and
   the writer's first token (1.5 to 3.3 s) is the whole latency budget. Two gotchas for the install ticket: mlx-audio
   does not depend on `misaki`, Kokoro's text processor, so it must be installed explicitly (`misaki[en]`), and
   misaki's bundled `espeakng-loader` 0.2.4 library aborts inside `espeak_Initialize` on this Mac (macOS 26) with
   its compiled-in CI path, whatever data path it is given; pointing phonemizer at Homebrew's `espeak-ng` 1.52
   (`brew install espeak-ng`, see `bin/render.py`) fixes it. misaki also downloads spaCy's `en_core_web_sm` on first
   use. Alternative voices rendered for comparison: `results/audio/voice-am_michael.wav`, `voice-bf_emma.wav`.

Final revision (rev6, chunked), one row per run:

```
response                 mode    resp script ratio ~sec  1st paras                         t1st  done flags
01-mixed-layout          brief    531    270  0.51   95   28 [71, 43, 60, 68]              2.82  5.45 open=28w brief=270w
01-mixed-layout          full     531    409  0.77  144   28 [75, 68, 25, 48, 63, 20, 50, 32]  2.16  6.65 open=28w p4=25w p7=20w
02-prose-pronunciation   brief    218    178  0.82   63    6 [58, 79, 35]                  2.45  3.59 -
02-prose-pronunciation   full     218    214  0.98   76   25 [68, 56, 65]                  2.87  4.28 open=25w
03-structures            brief    346    221  0.64   78   30 [68, 31, 62, 30]              2.86  5.28 open=30w brief=221w
03-structures            full     346    343  0.99  121   11 [45, 53, 52, 60, 66, 56]      2.05  5.79 -
04-code-explanation      brief    367    231  0.63   82   16 [66, 21, 73, 55]              2.16  4.73 p3=21w brief=231w
04-code-explanation      full     367    344  0.94  121   25 [57, 48, 67, 68, 79]          2.66   4.9 open=25w
05-step-list             brief    331    121  0.37   43   26 [54, 41]                      3.13  4.35 open=26w
05-step-list             full     331    381  1.15  134   44 [50, 23, 39, 39, 31, 31, 38, 40, 32, 14]  3.09  6.52 open=44w p3=23w p11=14w
06-status-report         brief    367    277  0.75   98   15 [76, 56, 50, 56, 24]          2.36  4.31 p6=24w brief=277w
06-status-report         full     367    359  0.98  127   20 [76, 62, 50, 38, 61, 23, 29]  2.44  4.19 p7=23w p8=29w
07-short-confirmation    brief     41     55  1.34   19   21 [34]                          2.09  2.42 open=21w
07-short-confirmation    full      41     45   1.1   16   45 []                            2.21  2.21 open=45w
08-long-comparison       brief*   930    224  0.24   79   17 [79, 20, 60, 41]              2.49  5.35 open=24w p3=20w brief=224w
```

`open=` and `p<n>=` flags mark chunks outside the prompt's 8 to 15 and 40 to 70 word targets; `brief=` marks a brief
over 200 words. They are the prompt's targets, not the daemon's guarantee (finding 3).

## What this proposes for the spec

- The writer is bare headless haiku 4.5, effort low, thinking off, with `prompt/rules.md` plus one mode file as the
  system prompt and the Response wrapped per `prompt/user.md` as the user message. One job, no flags.
- The daemon chunks: first sentence alone, then sentences up to 80 words, closing at the writer's blank lines once a
  chunk holds 20 words. Same code path as the Kokoro phoneme-cap split.
- Full is the default. Brief is asked for as "under 100 words" and described to users as the one-to-two-minute
  version. Over the cap (default 680 words) the daemon speaks the fixed notice at once and requests brief.
- A Response under 100 words is spoken as it is, in either mode.
- The rules in `prompt/rules.md` are the style guide, examples included; the residue list in finding 6 is the
  regression set for any future prompt change.

## Human checklist (the part only a listener can settle)

Everything is pre-rendered in Kokoro under `results/audio/`; `open results/audio` and double-click, or `afplay` a
file. Jot a line per item on the ticket.

1. `04-code-explanation.full.rev6.wav`. Does the code come across as "what it does" rather than syntax? Is the
   table's point clear without the cells? Do the three gotchas land as three things?
2. `01-mixed-layout.full.rev6.wav`. Same for the retry code, the delay table, the four cautions, the four steps.
   Does "p ninety-nine" sound right, or should it be "p 99"?
3. `05-step-list.full.rev6.wav`. Nine steps as spoken instructions: can you follow them by ear? Do the chunks feel
   like natural pauses or like run-ons?
4. `02-prose-pronunciation.full.rev6.wav`. Dates, times, money, units, "e.g." and "i.e.", "req/s". Anything the
   voice mangles that the rules should have rewritten?
5. `06-status-report.brief.rev6.wav`, then `06-status-report.full.rev6.wav`. Brief came out near 280 words here
   (finding 4): is that still worth having as "brief", or should brief be dropped in favour of full plus stop?
6. `08-long-comparison.brief.rev6.wav` (the capped one; the notice sentence is the first thing you hear). Does the
   notice work? Alternatives to try by editing `CAP_NOTICE` in `bin/write-script`: "Long answer. Here's the short
   version." / "This one's long, so I'll give you the brief." Then: does the brief carry the recommendation and why?
7. `07-short-confirmation.full.rev6.wav`. A one-sentence Response spoken as one sentence: right, or trim further?
8. `03-structures.full.rev6.wav`. Blockquote, nested list, ASCII diagram, and the sizing formula. Is the formula
   spoken usably?
9. `04-code-explanation.full.rev6-nochunk.wav` against item 1's file: the writer's own paragraphs versus the
   chunker's cuts. Any audible difference? (If not, the chunker is free.)
10. Voice: `voice-am_michael.wav` and `voice-bf_emma.wav` are item 1's Script in two other Kokoro voices. Which
    default? (This feeds the Engine ticket, not this one, but you will have an opinion by now.)
11. Gut verdict on the Script itself: does it sound like a person explaining, or like a document read out?

Record the verdict on ticket #5.

## Verdict

Pending the listening session.
