#!/usr/bin/env python3
"""Generate human-like Telugu voice clips for GYM AI corrections.

Honest note: this is NOT a real human recording. No automated voice is.
It uses Microsoft Edge neural Telugu voice te-IN-ShrutiNeural — a voice
trained on human speech, far more natural than iOS AVSpeechSynthesizer —
the same voice family used for the Masai Telugu videos.

Usage (on a PC or any machine where speech.platform.bing.com is reachable;
this sandbox historically blocks that endpoint with an SSL error, so if
generation fails here, run this script on your PC):
    python3 scripts/generate_telugu_voice.py
Output: Resources/TeluguVoice/<key>.mp3, bundled with the app and played
offline by VoiceCoach when the trainer language is Telugu or Mixed.
If a clip is missing, VoiceCoach falls back to AVSpeech te-IN.
"""
import asyncio
import pathlib
import sys

try:
    import edge_tts
except ImportError:
    print("Install first: pip install edge-tts")
    sys.exit(1)

VOICE = "te-IN-ShrutiNeural"
OUT = pathlib.Path(__file__).resolve().parent.parent / "Resources" / "TeluguVoice"

# key -> Telugu text (Telugu script, so Shruti pronounces it naturally)
PHRASES = {
    "good_rep": "బాగుంది! మంచి రెప్!",
    "elbows_close": "మీ మోచేతులు శరీరానికి దగ్గరగా ఉంచండి.",
    "sides_even": "రెండు వైపులా సమానంగా ఉంచండి.",
    "shoulder_height": "భుజం ఎత్తు వరకు మాత్రమే పైకి ఎత్తండి, పైన కాదు.",
    "hips_level": "మీ తుంటిని సమానంగా ఉంచండి, కిందికి వంగకండి, పైకి లేపకండి.",
    "lower_slowly": "నెమ్మదిగా కిందికి దించండి, పడిపోనివ్వకండి.",
    "chest_stable": "మీ ఛాతీని స్థిరంగా ఉంచండి.",
    "control_descent": "నెమ్మదిగా కిందికి వెళ్ళండి, నియంత్రణ కోల్పోకండి.",
    "press_smoothly": "మెల్లగా, సమానంగా పైకి నొక్కండి.",
    "good_depth": "బాగుంది, మంచి లోతు. ఇప్పుడు మెల్లగా పైకి లేవండి.",
    "rest_90": "తొంభై సెకన్లు విశ్రాంతి తీసుకోండి. నేను చెప్పినప్పుడు మొదలుపెట్టండి.",
    "set_complete": "అద్భుతం! మీ సెట్ పూర్తయింది.",
    "start_workout": "వర్కౌట్ ప్రారంభిద్దాం. మీరు చేయగలరు!",
    "unable_assess": "కెమెరాకు మీ శరీరం సరిగా కనిపించడం లేదు. దయచేసి స్థానం మార్చండి.",
    "pain_stop": "నొప్పి వస్తే వెంటనే ఆపండి. నొప్పిని బలవంతంగా కొనసాగించకండి.",
    "keep_back_flat": "మీ వీపును నిటారుగా ఉంచండి, వంగకండి.",
}

async def main():
    OUT.mkdir(parents=True, exist_ok=True)
    for key, text in PHRASES.items():
        path = OUT / f"{key}.mp3"
        if path.exists() and path.stat().st_size > 1000:
            print(f"skip (exists): {key}")
            continue
        communicate = edge_tts.Communicate(text, VOICE)
        await communicate.save(str(path))
        print(f"wrote {key}: {path.stat().st_size} bytes")

if __name__ == "__main__":
    asyncio.run(main())
