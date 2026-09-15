#!/usr/bin/env python3
"""PROTOTYPE, throwaway. Render a Script to a wav with Kokoro-82M on MLX (mlx-audio), one paragraph per
generate call with a short silence between, the way the daemon would feed the Engine. Prints per-paragraph
synthesis time and time to first audio. Run with the venv from bin/kokoro-setup.sh:

    .venv/bin/python bin/render.py results/04-code-explanation.full.rev6.txt [--play]
    .venv/bin/python bin/render.py --text "One sentence." --out /tmp/x.wav --play
"""
import argparse, pathlib, subprocess, sys, time, wave

import numpy as np

HERE = pathlib.Path(__file__).resolve().parent.parent
MODEL = "prince-canuma/Kokoro-82M"

ap = argparse.ArgumentParser()
ap.add_argument("script", nargs="?", help="a saved Script (.txt); paragraphs are blank-line separated")
ap.add_argument("--text", help="render this text instead of a file")
ap.add_argument("--voice", default="af_heart")
ap.add_argument("--speed", type=float, default=1.0)
ap.add_argument("--gap", type=float, default=0.35, help="seconds of silence between paragraphs")
ap.add_argument("--out", help="wav path; default results/audio/<script name>.wav")
ap.add_argument("--play", action="store_true", help="afplay the result when done")
a = ap.parse_args()

if not a.text and not a.script:
    sys.exit("give a Script file or --text")
text = a.text or pathlib.Path(a.script).read_text()
paras = [p.strip() for p in text.split("\n\n") if p.strip()]
out = pathlib.Path(a.out) if a.out else HERE / "results" / "audio" / (pathlib.Path(a.script).stem + ".wav")
out.parent.mkdir(parents=True, exist_ok=True)

t0 = time.time()
# misaki's out-of-dictionary fallback is espeak-ng, loaded from the espeakng-loader wheel. On this Mac
# (macOS 26, espeakng-loader 0.2.4) that library aborts inside espeak_Initialize with its compiled-in
# CI-runner data path, whatever path or ESPEAK_DATA_PATH it is given. So: import misaki.espeak (which
# points phonemizer at the wheel), then repoint phonemizer at Homebrew's espeak-ng if it is installed.
BREW_ESPEAK = pathlib.Path("/opt/homebrew/lib/libespeak-ng.dylib")
if BREW_ESPEAK.exists():
    import misaki.espeak  # noqa: F401  runs misaki's set_library/set_data_path first
    from phonemizer.backend.espeak.wrapper import EspeakWrapper
    EspeakWrapper.set_library(str(BREW_ESPEAK))
    EspeakWrapper.set_data_path(None)  # Homebrew's build knows its own data directory
else:
    print("warning: Homebrew espeak-ng not found; the bundled one is known to abort here (brew install espeak-ng)")
from mlx_audio.tts.utils import load_model  # noqa: E402  (slow import, keep it after arg parsing)
model = load_model(MODEL)
t_load = time.time() - t0
print(f"model loaded in {t_load:.2f}s")

sr, pcm, t_first = 24000, [], None
for i, p in enumerate(paras, 1):
    t = time.time()
    n = 0
    for r in model.generate(text=p, voice=a.voice, speed=a.speed, lang_code="a", verbose=False):
        audio = np.asarray(r.audio, dtype=np.float32).reshape(-1)
        sr = getattr(r, "sample_rate", sr)
        if t_first is None:
            t_first = time.time() - t0
        pcm.append(audio)
        n += audio.size
    pcm.append(np.zeros(int(sr * a.gap), dtype=np.float32))
    print(f"  para {i}/{len(paras)}: {len(p.split()):3}w, {n / sr:5.1f}s of audio, synthesised in {time.time() - t:.2f}s")

signal = np.concatenate(pcm) if pcm else np.zeros(0, dtype=np.float32)
with wave.open(str(out), "wb") as w:
    w.setnchannels(1)
    w.setsampwidth(2)
    w.setframerate(sr)
    w.writeframes((np.clip(signal, -1, 1) * 32767).astype("<i2").tobytes())

total = time.time() - t0
print(f"first audio {t_first:.2f}s after start ({t_first - t_load:.2f}s after model load); "
      f"{len(paras)} paragraphs, {signal.size / sr:.0f}s of audio synthesised in {total - t_load:.1f}s -> {out}")
if a.play:
    subprocess.run(["afplay", str(out)])
