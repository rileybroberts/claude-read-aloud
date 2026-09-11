# Local TTS runtimes for the first Engine

Research for issue #2 ("Which local TTS runtime should be the first Engine?"), 2026-09-11.
Vocabulary follows `CONTEXT.md`: an **Engine** turns a **Script** into a **Reading**.

## Question and constraints

Pick the first Engine for a macOS-only, Apple Silicon plugin. Standing decisions from the map (issue #1):
Python via `uv` is acceptable, a warm background daemon is acceptable, first audio must land under 5 s,
and the Script is streamed to the Engine paragraph by paragraph.

## Method

- Primary sources only: each project's GitHub repo, README, source, releases, PyPI JSON, Hugging Face
  model cards and the HF API, plus Apple's `man say` and developer docs. No Python packages were
  installed and no models were downloaded in this session; install lines below are transcribed, not run.
- `say` was measured locally. Machine: Apple M4 Max, 36 GiB RAM, 14 cores, macOS 26.6.2 (25G83)
  (`sysctl -n machdep.cpu.brand_string`, `sysctl -n hw.memsize`, `sw_vers`).
- Tooling present: `uv 0.9.11`, Homebrew, system `python3 3.9.6`; `espeak-ng` and `ffmpeg` absent.

## Findings

### "mlx-voice" does not exist

There is no PyPI package `mlx-voice` (https://pypi.org/pypi/mlx-voice/json returns 404) and no GitHub
repository of that exact name; `gh search repos mlx-voice` returns only unrelated or personal projects
(`bachittle/mlx-voice-agent`, `EndlessHoper/mlx-voice-cloning`, etc.). The things people most likely mean
are `Blaizzy/mlx-audio` (below), its Swift sibling https://github.com/Blaizzy/mlx-audio-swift, or
Kokoro-on-MLX ports such as https://github.com/mweinbach/kokoro-swift (MLX GPU + CoreML ANE backends).
Treat "mlx-voice" as a synonym for mlx-audio.

### mlx-audio (Kokoro-82M on MLX) — https://github.com/Blaizzy/mlx-audio

- License MIT (https://github.com/Blaizzy/mlx-audio/blob/main/LICENSE). Active: v0.5.3 released
  2026-09-07, last push 2026-09-11, 7.9k stars, 104 open issues (`gh api repos/Blaizzy/mlx-audio`).
- Requires Python >= 3.10, Apple Silicon, MLX; ffmpeg only for MP3/FLAC/OGG output, WAV needs nothing
  (https://github.com/Blaizzy/mlx-audio#requirements, `pyproject.toml` `requires-python`).
- Install per README: `pip install mlx-audio` or `uv tool install --force mlx-audio --prerelease=allow`
  (https://github.com/Blaizzy/mlx-audio#installation). Kokoro additionally needs `pip install misaki`
  (https://github.com/Blaizzy/mlx-audio#kokoro-tts); `misaki` is not declared anywhere in
  `pyproject.toml` (0 matches), and open issue #452 (2026-01-29) reports exactly this: `uv tool install`
  then Kokoro fails with `No module named 'misaki'`, and `blis` fails to build on Python 3.13, working
  on 3.12 (https://github.com/Blaizzy/mlx-audio/issues/452). Untested candidate line:
  `uv tool install --python 3.12 --prerelease=allow --with "misaki[en]" "mlx-audio[server]"`.
- `misaki[en]` pulls `phonemizer-fork` and `espeakng-loader`
  (https://github.com/hexgrad/misaki/blob/main/pyproject.toml); espeak-ng is GPL-3.0
  (https://github.com/espeak-ng/espeak-ng) and is used for English out-of-dictionary fallback
  (https://github.com/hexgrad/kokoro#usage).
- Models: Kokoro bf16/8bit/6bit/4bit plus many larger TTS models (Qwen3-TTS, CSM, Dia, Chatterbox,
  Voxtral, VoxCPM2, MeloTTS, ...) (https://github.com/Blaizzy/mlx-audio#tts-models). Kokoro weights:
  `mlx-community/Kokoro-82M-bf16` 327 MB safetensors, 389 MB repo total including 54 voices;
  `Kokoro-82M-8bit` 289 MB / 352 MB total (HF API `?blobs=true`,
  https://huggingface.co/mlx-community/Kokoro-82M-bf16). Weights are Apache-2.0 (HF `license` tag).
- Streaming: `Model.generate(text, voice, speed, lang_code, split_pattern=r"\n+")` is a generator that
  yields one `GenerationResult` per newline-separated segment as it finishes, and computes per-segment RTF
  (https://github.com/Blaizzy/mlx-audio/blob/main/mlx_audio/tts/models/kokoro/kokoro.py). The CLI has
  `--stream` (play while generating) and `--play`
  (https://github.com/Blaizzy/mlx-audio/blob/main/mlx_audio/tts/generate.py, `stream`, `streaming_interval=2.0`).
- Daemon: `mlx_audio.server --host 0.0.0.0 --port 8000` exposes OpenAI-compatible
  `POST /v1/audio/speech` with `stream` and `streaming_interval` fields; the handler always returns a
  `StreamingResponse`, and `ModelProvider.load_model` caches loaded models so warm requests skip loading
  (https://github.com/Blaizzy/mlx-audio/blob/main/mlx_audio/server.py). `POST /v1/models` pre-loads a model.
- Incremental text input: none; each `generate`/request is a complete text. Each call is independent.
- Latency and memory on Apple Silicon: no numbers in README, releases, or issues searched. Unverified;
  see "Open risks". Open issue #104 "how to release memory" (https://github.com/Blaizzy/mlx-audio/issues/104).

### Kokoro reference (PyTorch) — https://github.com/hexgrad/kokoro

- Apache-2.0 code and weights (https://github.com/hexgrad/kokoro/blob/main/LICENSE,
  https://huggingface.co/hexgrad/Kokoro-82M `license: apache-2.0`). 82M parameters, trained only on
  permissive/non-copyrighted audio (model card, Training Details). 8 languages, 54 voices, 24 kHz.
- Quality evidence: the model card's EVAL.md presents TTS Spaces Arena and TTS Arena leaderboard
  screenshots dated 2025-02-26 and links the Artificial Analysis arena
  (https://huggingface.co/hexgrad/Kokoro-82M/blob/main/EVAL.md); the live arena pages are JS-only and
  could not be re-read here. Voice grades in VOICES.md: `af_heart` A, `af_bella` A-, `af_nicole` B-,
  most male voices C+ to D (https://huggingface.co/hexgrad/Kokoro-82M/blob/main/VOICES.md). Samples:
  https://huggingface.co/hexgrad/Kokoro-82M/blob/main/SAMPLES.md.
- Install: `pip install kokoro>=0.9.4 soundfile` plus espeak-ng (README shows `apt-get install espeak-ng`;
  no macOS line). Requires Python >=3.10,<3.14 and `torch` (`pyproject.toml`); the torch 2.14.0
  macOS arm64 wheel is 127 MB (https://pypi.org/pypi/torch/json). Weights `kokoro-v1_0.pth` 327 MB
  plus 28 MB of voices (HF API). On Apple Silicon the README says to set `PYTORCH_ENABLE_MPS_FALLBACK=1`
  "to enable GPU acceleration", i.e. MPS needs CPU fallback (https://github.com/hexgrad/kokoro#usage).
- Streaming: `KPipeline.__call__(text, voice, speed, split_pattern=r'\n+')` is a generator yielding
  `Result(graphemes, phonemes, audio)` per segment; segments are capped at 510 phoneme tokens
  (https://github.com/hexgrad/kokoro/blob/main/kokoro/pipeline.py). No incremental input.
- Maintenance: last release 0.9.4 on 2025-04-05 (PyPI), last push 2025-08-06, 208 open issues; issue #211
  asks for MLX support and is open (https://github.com/hexgrad/kokoro/issues/211).

### kokoro-onnx — https://github.com/thewh1teagle/kokoro-onnx

- Code MIT, model Apache-2.0 (https://github.com/thewh1teagle/kokoro-onnx#license). v0.6.1 on
  2026-08-19 (PyPI), last push 2026-09-01, 2.7k stars, 80 open issues.
- README claims "Fast performance near real-time on macOS M1" and "Lightweight: ~300MB (quantized: ~80MB)"
  (https://github.com/thewh1teagle/kokoro-onnx#features). CPU only on macOS: `onnxruntime-gpu` is
  excluded for darwin in `pyproject.toml`; issue #16 "CoreML execution failed" is closed, #56 "mac m1 gpu
  support" and #178 "Speed enhance" are open (https://github.com/thewh1teagle/kokoro-onnx/issues).
- Install: `pip install -U kokoro-onnx` or `uv add kokoro-onnx soundfile`, then download
  `kokoro-v1.0.onnx` (325 MB; fp16 163 MB; int8 114 MB) and `voices-v1.0.bin` (28 MB) from release
  `model-files-v1.1` (https://github.com/thewh1teagle/kokoro-onnx/releases/tag/model-files-v1.1).
  Python >=3.10,<3.14; deps `onnxruntime>=1.20.1`, `espeakng-loader`, `phonemizer`, `numpy`.
- Streaming: `async def create_stream(text, voice, speed, lang, ..., sentence_pause=0.25)` yields
  chunks "as they are processed"; text is split into batches of at most 510 phonemes, preferring
  punctuation then word boundaries (`chunker.split_phonemes`, `MAX_PHONEME_LENGTH = 510`)
  (https://github.com/thewh1teagle/kokoro-onnx/blob/main/src/kokoro_onnx/__init__.py). No incremental input.

### Piper — https://github.com/rhasspy/piper and https://github.com/OHF-Voice/piper1-gpl

- `rhasspy/piper` (MIT) is archived; its README is one line: "Development has moved:
  https://github.com/OHF-Voice/piper1-gpl". The successor is GPL-3.0 because it "embeds espeak-ng for
  phonemization" (https://github.com/OHF-Voice/piper1-gpl#readme, PyPI `license = GPL-3.0-or-later`).
  Its README carries a "Looking for Maintainers" banner. v1.8.0 on 2026-09-04; wheels include
  `macosx_11_0_arm64` (https://pypi.org/pypi/piper-tts/json); Python >= 3.9.
- Install: `pip install piper-tts`, then `python3 -m piper.download_voices en_US-lessac-medium`
  (https://github.com/OHF-Voice/piper1-gpl/blob/main/docs/CLI.md). Voices: medium 63 MB at 22.05 kHz,
  high 114-121 MB (HF API on https://huggingface.co/rhasspy/piper-voices). Each voice has its own
  dataset license in `MODEL_CARD` (e.g. `en_US-ryan-high` CC BY-NC-SA 4.0, `en_GB-alba-medium` CC BY 4.0,
  lessac under the Blizzard 2013 license); VOICES.md warns "Some voices may have restrictive licenses"
  (https://github.com/OHF-Voice/piper1-gpl/blob/main/docs/VOICES.md).
- Streaming and incremental input: the CLI iterates `sys.stdin` line by line and, with `--output-raw`,
  writes int16 PCM per sentence to stdout and flushes, so one long-lived process accepts text
  incrementally, one utterance per line
  (https://github.com/OHF-Voice/piper1-gpl/blob/main/src/piper/__main__.py). Python
  `PiperVoice.synthesize(text) -> Iterable[AudioChunk]` yields one chunk per sentence
  (https://github.com/OHF-Voice/piper1-gpl/blob/main/src/piper/voice.py). HTTP server
  `python3 -m piper.http_server -m en_US-lessac-medium` on port 5000, `POST /synthesize` returns a WAV
  (https://github.com/OHF-Voice/piper1-gpl/blob/main/docs/API_HTTP.md). CLI.md notes the CLI "is slow
  since it needs to load the model each time".
- Acceleration: CPU onnxruntime; the only GPU switch is `--cuda`. No Apple Silicon numbers in primary
  sources. Open issue #272 (2026-08-15): "macOS arm64 wheel ignores espeak-ng data dir, uses baked CI
  runner path" (https://github.com/OHF-Voice/piper1-gpl/issues/272), an install bug on our exact platform.
- Quality evidence: VITS voices; samples at https://rhasspy.github.io/piper-samples. "medium"/"high"
  in the model cards are size tiers, not listening scores. No arena or comparative listening data.

### macOS `say` (baseline, measured here)

- Ships with macOS; man page: `say [-v voice] [-r rate] [-o outfile | -a device] [-f file | string]`
  (`man say`, dated 2020-08-13). Key line: "If the input is a TTY, text is spoken line by line ...
  Otherwise, text is spoken all at once."
- Verified: piped stdin is not incremental. A writer that printed a 5.1 s sentence, slept 6 s, then
  printed a 0.8 s sentence took 13.67 s wall through `say -f -`; an incremental reader would have taken
  about 8 s, an EOF-waiting one about 13 s. `say` waits for EOF.
- Latency: `say -o file` for one sentence (2.59 s of audio): 1.90 s cold, then 1.13-1.19 s warm (3 runs).
  Live playback to an audio device: "Hi." 1.55 s total, a 2.59 s sentence 3.61 s total, so about 1.0 s
  of fixed startup before first audio when warm, about 1.8 s cold.
- Throughput: 195 words (three paragraphs) became 61.4 s of audio in 0.87 s wall (Samantha) and 63.7 s
  in 0.73 s (Daniel): roughly 70x real time. Peak RSS of the `say` client 31-38 MB (`/usr/bin/time -l`);
  synthesis itself runs in a system daemon and was not measured.
- Voices: 184 installed, 25 English (`say -v '?'`); all are the built-in tier. Apple defines three
  quality tiers: `default` "available on the device by default", `enhanced` and `premium` "you must
  download to use" (https://developer.apple.com/documentation/avfaudio/avspeechsynthesisvoicequality).
  Voices are added under System Settings > Accessibility > Read & Speak > System voice
  (https://support.apple.com/guide/mac-help/change-the-voice-your-mac-uses-to-speak-text-mchlp2290/mac).
  No third-party listening data; the only evidence is Apple's own tiering, which puts every installed
  voice in the lowest tier. A Swift helper could use `AVSpeechSynthesizer.write(_:toBufferCallback:)`
  (macOS 10.15+) to get PCM buffers instead of the CLI
  (https://developer.apple.com/documentation/avfaudio/avspeechsynthesizer/write(_:tobuffercallback:)).
- License: proprietary macOS component; nothing to install or redistribute.

## Comparison

| Runtime | Quality evidence | First audio warm / cold | Streaming synthesis | Incremental text | Memory resident | Install path | Model download | License |
|---|---|---|---|---|---|---|---|---|
| Kokoro via mlx-audio | Arena screenshots in EVAL.md (2025-02); `af_heart` grade A | Not measured; no primary numbers (prototype must measure) | Yes, per `\n+` segment; HTTP `stream` | No (complete text per call; daemon keeps model warm) | Est. 0.6-1 GB (327 MB weights + MLX/Python; estimate) | `uv tool install` + `misaki[en]`, Python 3.12 (issue #452) | 389 MB (bf16 repo) | MIT code, Apache-2.0 weights, GPL espeak-ng fallback |
| Kokoro via kokoro-onnx | Same weights, same voices | Not measured; README "near real-time on macOS M1" (CPU) | Yes, `create_stream`, 510-phoneme batches | No | Est. 0.4-0.7 GB (325 MB fp32 or 114 MB int8 + ORT) | `uv add kokoro-onnx soundfile` + 2 files | 353 MB fp32 or 142 MB int8 | MIT code, Apache-2.0 weights |
| Kokoro via hexgrad/kokoro | Same | Not measured; MPS needs fallback env var | Yes, `KPipeline` generator per segment | No | Est. 1 GB+ (torch runtime) | `pip install kokoro soundfile` + espeak-ng | 355 MB weights + 127 MB torch wheel | Apache-2.0 |
| Piper (piper1-gpl) | Samples page only; no comparative data | Not measured; CLI reloads model per run, server avoids that | Yes, per sentence | Yes, line per utterance on stdin (`--output-raw`) | Est. 150-300 MB (63-121 MB voice + ORT) | `pip install piper-tts` + `download_voices`; macOS arm64 espeak bug #272 open | 63 MB medium, 114-121 MB high | GPL-3.0 code, per-voice dataset licenses |
| macOS `say` | Apple's lowest quality tier unless Enhanced/Premium downloaded | ~1.0 s / ~1.8 s (measured) | Plays as it synthesizes; ~70x real time | No (waits for EOF on pipes; verified) | 31-38 MB client, system daemon unmeasured | None | None (Enhanced/Premium via System Settings) | macOS |

## Recommendation

**First Engine: Kokoro-82M on MLX through `mlx-audio`, running as a warm daemon, default voice
`af_heart`.** It is the only candidate with top-tier quality evidence, Apache-licensed weights, an
Apple-Silicon-native GPU path, a maintained warm server that caches models and streams HTTP responses, and
a generator API that emits audio per newline-separated segment, which is exactly the paragraph-by-paragraph
shape the map already decided on. The 389 MB download is a one-time cost.

**Fallback Engine: macOS `say`.** Zero install, about 1 s to first audio warm, 70x real time, so it
comfortably meets the 5 s target on any Mac, including teammates without Python or `uv`. Its cost is
voice quality (built-in tier) and the fact that it cannot take incremental text, so the adapter must run
one `say` process per paragraph. This answers the map's open "Fallback Engine for teammates" question: ship `say`.

**Second choice for the primary, not a fallback:** `kokoro-onnx`. Same weights and voices as the MLX
path, MIT, smaller (114 MB int8), no misaki/spacy dependency chain, but CPU-only on macOS. Switch to it
if the mlx-audio install pain in issue #452 is not resolved by a pinned `uv` recipe in the prototype.

**Not recommended:** Piper (GPL-3.0, an open macOS arm64 install bug, no comparative quality evidence,
project seeking maintainers) and the PyTorch Kokoro path (127 MB torch wheel, MPS fallback flag, and
the reference repo has had no release since 2025-04).

## Implications for the Engine interface

1. **No runtime accepts text incrementally into an in-flight synthesis.** All Kokoro paths and `say` take a
   complete text per call; only Piper's CLI is line-incremental, and it is not recommended. So the Engine
   interface should be *one call per paragraph*, with the plugin (or its daemon) owning the ordered
   paragraph queue. Do not design the seam around a persistent text stream.
2. **The paragraph is the natural unit.** Kokoro's `split_pattern=r"\n+"` already segments on blank lines,
   and segments are capped at 510 phonemes (roughly a few sentences). The Script style guide should keep
   paragraphs short; the Engine adapter should split over-long paragraphs on sentence boundaries.
3. **Engines return audio; the daemon plays it.** Define the seam as `synthesize(paragraph, voice, speed)
   -> iterator of PCM chunks with a sample rate` (24 kHz Kokoro, 22.05 kHz Piper). The `say` adapter fits
   by writing a temp WAV per paragraph (`say -o out.wav --data-format=LEI16@24000 -f -`). One playback
   path gives one stop path and one place to swap Engines.
4. **Stop must cancel both the queue and the current chunk.** "A new Reading interrupts and replaces a
   playing one" means: flush queued paragraphs, abandon the Kokoro generator between segments (or kill the
   `say` child), and cut the audio output buffer.
5. **Warm daemon is part of the Engine contract, not an optimisation.** Cold model load is the one cost
   nobody has measured; the daemon must load the model at start (mlx-audio's `POST /v1/models` or a direct
   `load_model`) and report readiness so the Command can fall back to `say` if the daemon is down or the
   model is missing. Prefer a thin daemon that imports mlx-audio as a library over running
   `mlx_audio.server` verbatim, since the plugin needs its own queue, playback, and stop anyway.
6. **Voice and speed are Engine capabilities.** Expose `voices()` (Kokoro: 28 English voices with published
   grades; `say -v '?'`) and a speed parameter (Kokoro `speed` float; `say -r` words per minute).
7. **Python 3.12 pin.** Until issue #452 is fixed, the install recipe must pin Python 3.12 and add
   `misaki[en]` explicitly; the install ticket should encode this rather than trusting the README line.

## Open risks the prototype must measure

- Warm time to first audio and cold model load for Kokoro bf16 on this M4 Max (no primary numbers exist;
  `Model.generate` logs per-segment RTF, so a single run answers it).
- Resident memory of the warm daemon (estimated 0.6-1 GB above; unmeasured).
- Whether `misaki[en]`'s `espeakng-loader` removes the need for a Homebrew `espeak-ng` on macOS.
- Whether the GPL espeak-ng fallback in the Kokoro path matters for a plugin shared only with teammates
  (it is loaded as a runtime library, not redistributed).
