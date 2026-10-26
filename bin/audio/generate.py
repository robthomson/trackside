"""
Generate Trackside's spoken audio from bin/audio/phrases.json.

Writes 16 kHz mono 16-bit WAVs (what Ethos plays) with leading/trailing
silence trimmed, to src/trackside/audio/<lang>/<variant>/<file>.
A small cache (bin/audio/.cache, by text + voice) means only new or changed
phrases are sent to the speech engine.

Engines:
  google  Google Cloud Text-to-Speech (default). Uses application default
          credentials (gcloud auth application-default login).
  sapi    Windows built-in speech, offline. Good enough for drafts.

Usage:
  python bin/audio/generate.py                 # all voices in VOICES below
  python bin/audio/generate.py --engine sapi   # offline drafts
  python bin/audio/generate.py --only-missing

Requires: google-cloud-texttospeech (for the google engine)
"""

import argparse
import array
import hashlib
import io
import json
import subprocess
import sys
import tempfile
import wave
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
HERE = Path(__file__).resolve().parent
PHRASES = HERE / "phrases.json"
CACHE = HERE / ".cache"
OUT = REPO / "src" / "trackside" / "audio"

RATE = 16000

# Ethos voice folder -> Google voice. "en/default" is the fallback the Lua side uses.
VOICES = {
    "en/default": "en-US-Wavenet-F",
    "en/us": "en-US-Wavenet-F",
    "en/gb": "en-GB-Neural2-A",
}
SAPI_VOICES = {"en/default": "Microsoft Zira Desktop", "en/us": "Microsoft Zira Desktop",
               "en/gb": "Microsoft Hazel Desktop"}

SILENCE = 300      # samples below this amplitude count as silence
PAD = int(RATE * 0.04)


def synth_google(text, voice):
    from google.cloud import texttospeech as tts
    client = synth_google.client = getattr(synth_google, "client", None) or tts.TextToSpeechClient()
    resp = client.synthesize_speech(
        input=tts.SynthesisInput(text=text),
        voice=tts.VoiceSelectionParams(language_code=voice[:5], name=voice),
        audio_config=tts.AudioConfig(audio_encoding=tts.AudioEncoding.LINEAR16, sample_rate_hertz=RATE),
    )
    return resp.audio_content          # a complete WAV file


def synth_sapi(text, voice):
    with tempfile.TemporaryDirectory() as d:
        out = Path(d) / "s.wav"
        safe = text.replace("'", "''")
        ps = (
            "Add-Type -AssemblyName System.Speech;"
            "$s = New-Object System.Speech.Synthesis.SpeechSynthesizer;"
            f"$s.SelectVoice('{voice}');"
            f"$f = New-Object System.Speech.AudioFormat.SpeechAudioFormatInfo({RATE}, "
            "[System.Speech.AudioFormat.AudioBitsPerSample]::Sixteen, "
            "[System.Speech.AudioFormat.AudioChannel]::Mono);"
            f"$s.SetOutputToWaveFile('{out}', $f); $s.Speak('{safe}'); $s.Dispose()"
        )
        subprocess.run(["powershell", "-NoProfile", "-Command", ps], check=True)
        return out.read_bytes()


def trim(wav_bytes):
    """Return 16 kHz mono 16-bit WAV bytes with silence trimmed from both ends."""
    with wave.open(io.BytesIO(wav_bytes)) as w:
        if w.getnchannels() != 1 or w.getsampwidth() != 2 or w.getframerate() != RATE:
            raise ValueError("expected 16 kHz mono 16-bit audio")
        pcm = array.array("h", w.readframes(w.getnframes()))
    if sys.byteorder == "big":
        pcm.byteswap()
    loud = [i for i, s in enumerate(pcm) if abs(s) > SILENCE]
    if loud:
        pcm = pcm[max(0, loud[0] - PAD): min(len(pcm), loud[-1] + PAD)]
    buf = io.BytesIO()
    with wave.open(buf, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(pcm.tobytes())
    return buf.getvalue()


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--engine", choices=("google", "sapi"), default="google")
    ap.add_argument("--only-missing", action="store_true", help="skip files that already exist")
    args = ap.parse_args()

    phrases = json.loads(PHRASES.read_text(encoding="utf-8"))
    voices = VOICES if args.engine == "google" else SAPI_VOICES
    synth = synth_google if args.engine == "google" else synth_sapi
    CACHE.mkdir(exist_ok=True)
    made = 0
    for folder, voice in voices.items():
        for p in phrases:
            dest = OUT / folder / p["file"]
            if args.only_missing and dest.exists():
                continue
            key = hashlib.md5(f"{args.engine}|{voice}|{p['text']}".encode()).hexdigest()
            cached = CACHE / f"{key}.wav"
            if not cached.exists():
                print(f"  {folder}: {p['file']}  \"{p['text']}\"")
                cached.write_bytes(trim(synth(p["text"], voice)))
                made += 1
            dest.parent.mkdir(parents=True, exist_ok=True)
            dest.write_bytes(cached.read_bytes())
    print(f"Done: {made} new, {len(phrases) * len(voices)} files in {OUT}")


if __name__ == "__main__":
    sys.exit(main())
