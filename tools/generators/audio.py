"""Synthesises every sound in the game: the menu music, the UI's clicks and
chimes, and the noises a printer makes. Nothing is recorded or sampled: each
is built from sines and shaped noise, so the same seed gives the same files.

Run with Blender's Python, which has numpy (it needs nothing else of Blender):

blender --background --factory-startup --python tools/generators/audio.py
blender --background --factory-startup --python tools/generators/audio.py -- --only printer

Writes 16 bit WAVs into assets/audio/. Loops are made to join end to start
(anything that rings on past the end is folded back onto the beginning), and
the game sets them looping when it loads them (scripts/game/sound.gd).
"""

import argparse
import sys
import wave
from pathlib import Path

import numpy as np

OUT = Path(__file__).resolve().parents[2] / "assets" / "audio"
RATE = 44100
MUSIC_RATE = 32000
TAU = 2.0 * np.pi


def midi(note):
    """Frequency in Hz of a MIDI note number."""
    return 440.0 * 2.0 ** ((note - 69) / 12.0)


def write(name, signal, rate=RATE, peak=0.8):
    """Saves a mono (n,) or stereo (n, 2) signal, scaled so its loudest point is `peak`."""
    path = OUT / (name + ".wav")
    path.parent.mkdir(parents=True, exist_ok=True)
    loudest = np.max(np.abs(signal))
    data = signal * (peak / loudest if loudest > 0 else 1.0)
    frames = (np.clip(data, -1.0, 1.0) * 32767.0).astype("<i2")
    with wave.open(str(path), "wb") as out:
        out.setnchannels(1 if signal.ndim == 1 else 2)
        out.setsampwidth(2)
        out.setframerate(rate)
        out.writeframes(frames.tobytes())
    print("Wrote %s (%.1f s)" % (path.relative_to(OUT.parents[1]), len(signal) / rate))


def shape(signal, rate, response):
    """Filters a signal by a function of frequency (Hz -> gain). The filter
    wraps round, so a loop stays a loop."""
    spectrum = np.fft.rfft(signal, axis=0)
    gains = response(np.fft.rfftfreq(len(signal), 1.0 / rate))
    return np.fft.irfft(spectrum * (gains if signal.ndim == 1 else gains[:, None]), len(signal), axis=0)


def lowpass(cutoff, steep=2.0):
    return lambda freq: 1.0 / np.sqrt(1.0 + (freq / cutoff) ** (2.0 * steep))


def highpass(cutoff, steep=2.0):
    return lambda freq: 1.0 - 1.0 / np.sqrt(1.0 + (freq / cutoff) ** (2.0 * steep))


def times(seconds, rate=RATE):
    return np.arange(int(seconds * rate)) / rate


def pluck(freq, seconds, rate=RATE, decay=0.25, bright=0.4):
    """A soft struck tone, like a kalimba: a sine with overtones that die first."""
    t = times(seconds, rate)
    tone = np.sin(TAU * freq * t)
    tone += bright * np.sin(TAU * freq * 2.0 * t) * np.exp(-t / (decay * 0.35))
    tone += bright * 0.4 * np.sin(TAU * freq * 3.0 * t) * np.exp(-t / (decay * 0.2))
    attack = np.minimum(t / 0.004, 1.0)
    return tone * attack * np.exp(-t / decay)


def faded(signal, rate=RATE, seconds=0.004):
    """Takes the click off the end of a one-shot."""
    count = min(int(seconds * rate), len(signal))
    signal[-count:] *= np.linspace(1.0, 0.0, count)
    return signal


# --- UI ---------------------------------------------------------------------

def ui_sounds():
    # Hover: a small tick.
    t = times(0.05)
    write("ui/hover", faded(np.sin(TAU * 1320.0 * t) * np.exp(-t / 0.009)), peak=0.22)

    # Click: a wooden tok.
    t = times(0.12)
    rng = np.random.default_rng(11)
    tok = np.sin(TAU * 540.0 * t) * np.exp(-t / 0.028) + 0.5 * np.sin(TAU * 1090.0 * t) * np.exp(-t / 0.012)
    tok += 0.25 * rng.standard_normal(len(t)) * np.exp(-t / 0.003)
    write("ui/click", faded(tok), peak=0.5)

    # Open and back: two plucks, going up and coming down.
    for name, notes in (("open", (76, 81)), ("back", (81, 74))):
        mix = np.zeros(int(0.5 * RATE))
        for index, note in enumerate(notes):
            tone = pluck(midi(note), 0.4, decay=0.11)
            start = int(index * 0.07 * RATE)
            mix[start:start + len(tone)] += tone
        write("ui/" + name, faded(mix), peak=0.4)

    # Start: a run up the chord, for setting off into a game.
    mix = np.zeros(int(1.5 * RATE))
    for index, note in enumerate((74, 78, 81, 86)):
        tone = pluck(midi(note), 1.1, decay=0.42, bright=0.5)
        start = int(index * 0.075 * RATE)
        mix[start:start + len(tone)] += tone * (0.8 + 0.07 * index)
    write("ui/start", faded(mix, seconds=0.05), peak=0.5)

    # Chime: the name has finished printing.
    mix = np.zeros(int(2.0 * RATE))
    for note, gain, late in ((81, 1.0, 0.0), (86, 0.8, 0.09), (90, 0.5, 0.18)):
        tone = pluck(midi(note), 1.8, decay=0.7, bright=0.6)
        start = int(late * RATE)
        mix[start:start + len(tone)] += tone * gain
    write("ui/chime", faded(mix, seconds=0.1), peak=0.5)


# --- Printers ---------------------------------------------------------------

def fan_loop():
    """The steady rush of a part cooling fan, with a little blade hum in it."""
    seconds = 4.0
    rng = np.random.default_rng(21)
    count = int(seconds * RATE)
    # Noise made in the frequency domain repeats exactly, so it loops by itself.
    freq = np.fft.rfftfreq(count, 1.0 / RATE)
    gains = np.zeros_like(freq)
    audible = freq > 20.0
    gains[audible] = 1.0 / np.sqrt(freq[audible])
    gains *= highpass(220.0)(freq) * lowpass(3200.0, 1.5)(freq)
    gains *= 1.0 + 1.6 * np.exp(-((freq - 900.0) / 500.0) ** 2)
    spectrum = gains * np.exp(1j * rng.uniform(0.0, TAU, len(freq)))
    rush = np.fft.irfft(spectrum, count)
    rush /= np.max(np.abs(rush))
    t = times(seconds)
    hum = 0.05 * np.sin(TAU * 238.0 * t) + 0.03 * np.sin(TAU * 476.0 * t)
    # A slow wobble, as a fan never quite holds its speed. Whole cycles in the loop.
    write("printer/fan_loop", (rush + hum) * (1.0 + 0.06 * np.sin(TAU * 0.5 * t)), peak=0.4)


def stepper_track(rng, seconds, low, high, busy):
    """How fast one motor turns over the loop, as a pitch in Hz: runs of
    outlines, quick travel moves and to and fro infill, with stops between."""
    count = int(seconds * RATE)
    pitch = np.zeros(count)
    at = 0
    while at < count:
        kind = rng.choice(["outline", "travel", "infill", "rest"], p=[0.38, 0.14, 0.33, 0.15])
        if kind == "outline":
            # A few sides of a shape: steady tones, each at its own speed.
            for side in range(rng.integers(2, 6)):
                length = int(rng.uniform(0.18, 0.7) / busy * RATE)
                pitch[at:at + length] = rng.uniform(low, low + (high - low) * 0.55)
                at += length + int(0.012 * RATE)
        elif kind == "travel":
            length = int(rng.uniform(0.12, 0.3) * RATE)
            pitch[at:at + length] = rng.uniform(high * 0.8, high * 1.25)
            at += length + int(0.03 * RATE)
        elif kind == "infill":
            # To and fro: the same short line over and over, turning at each end.
            tone = rng.uniform(low * 1.2, high * 0.8)
            stroke = int(rng.uniform(0.07, 0.16) / busy * RATE)
            for line in range(rng.integers(5, 14)):
                pitch[at:at + stroke] = tone
                at += stroke + int(0.018 * RATE)
        else:
            at += int(rng.uniform(0.1, 0.45) * RATE)
    # Motors speed up and slow down rather than jump: smoothing the pitch
    # gives each move its little swoop in and out.
    return np.maximum(shape(pitch[:count], RATE, lowpass(38.0, 1.0)), 0.0)


def motion_loop(name, seed, low, high, busy):
    """Two stepper motors singing as they drive the head about."""
    seconds = 8.0
    rng = np.random.default_rng(seed)
    t = times(seconds)
    mix = np.zeros(len(t))
    for motor in range(2):
        pitch = stepper_track(rng, seconds, low * (1.0 + 0.18 * motor), high * (1.0 + 0.12 * motor), busy)
        # A whole number of turns over the loop, so the wave meets itself at the join.
        turns = np.sum(pitch) / RATE
        pitch *= np.round(turns) / turns
        phase = TAU * np.cumsum(pitch) / RATE
        voice = np.zeros(len(t))
        for harmonic in range(1, 7):
            voice += np.sin(harmonic * phase) / harmonic ** 1.15
        # Silent when stopped, and the faster it turns the more it is heard.
        mix += voice * np.clip(pitch / 120.0, 0.0, 1.0) * (0.75 + 0.25 * np.clip(pitch / high, 0.0, 1.0))
    # The frame of the printer: it rings a little around a kilohertz and loses the top.
    body = lambda freq: lowpass(3600.0, 1.5)(freq) * highpass(110.0)(freq) * (1.0 + 0.9 * np.exp(-((freq - 1100.0) / 420.0) ** 2))
    write("printer/" + name, shape(mix, RATE, body), peak=0.42)


def done_beep():
    """The three beeps of a printer that has finished."""
    mix = np.zeros(int(0.6 * RATE))
    for index in range(3):
        t = times(0.085)
        beep = np.sin(TAU * 2093.0 * t) + 0.25 * np.sin(TAU * 6279.0 * t)
        beep *= np.minimum(t / 0.004, 1.0) * np.minimum((0.085 - t) / 0.01, 1.0)
        start = int(index * 0.15 * RATE)
        mix[start:start + len(beep)] += beep
    write("printer/done", mix, peak=0.3)


# --- Music ------------------------------------------------------------------

BPM = 80.0
BEAT = 60.0 / BPM
BARS = 16
# One bar each: the bass note, then the notes of the chord. Eight bars, played twice.
CHORDS = [
    (38, (54, 57, 61, 64)),   # D major 9
    (35, (54, 57, 59, 62)),   # B minor 7
    (43, (55, 59, 62, 66)),   # G major 7
    (45, (52, 57, 61, 64)),   # A
    (38, (54, 57, 61, 64)),   # D major 9
    (35, (54, 57, 59, 62)),   # B minor 7
    (40, (55, 59, 62, 66)),   # E minor 9
    (45, (52, 57, 59, 64)),   # A sus 2
]
# The tune over the second eight bars: (beat in the bar, note, beats long).
TUNE = [
    [(0, 69, 1), (1.5, 78, 0.5), (2, 76, 1), (3, 74, 1)],
    [(0, 71, 1.5), (2, 74, 1), (3, 78, 1)],
    [(0, 79, 1.5), (1.5, 78, 0.5), (2, 74, 1), (3, 71, 1)],
    [(0, 73, 1), (1, 76, 2), (3.5, 69, 0.5)],
    [(0, 78, 1), (1, 81, 1), (2, 78, 0.5), (2.5, 76, 0.5), (3, 74, 1)],
    [(0, 71, 1), (1, 74, 1), (2, 78, 2)],
    [(0, 79, 1), (1, 76, 1), (2, 71, 1), (3, 74, 1)],
    [(0, 76, 1.5), (1.5, 73, 0.5), (2, 69, 2)],
]
# The order the notes of a chord are picked out in, an eighth note each.
ARPEGGIO = (0, 2, 1, 3, 2, 3, 1, 2)


def menu_theme():
    """A slow, warm loop for the menu: a pad, a picked-out chord, a bass, and
    after eight bars a tune and some soft percussion."""
    rate = MUSIC_RATE
    count = int(round(BARS * 4 * BEAT * rate))
    left = np.zeros(count)
    right = np.zeros(count)
    rng = np.random.default_rng(31)

    def add(signal, beats, pan=0.0, gain=1.0):
        """Mixes a note in at a time given in beats. One that runs past the
        end carries on from the start, which is what makes the loop seamless."""
        where = (int(round(beats * BEAT * rate)) + np.arange(len(signal))) % count
        np.add.at(left, where, signal * gain * np.sqrt(0.5 * (1.0 - pan)))
        np.add.at(right, where, signal * gain * np.sqrt(0.5 * (1.0 + pan)))

    for bar in range(BARS):
        bass_note, chord = CHORDS[bar % len(CHORDS)]
        start = bar * 4.0
        second_half = bar >= 8

        # Pad: each note two slightly detuned voices, one to each side.
        t = times(4.0 * BEAT + 1.6, rate)
        swell = np.minimum(t / 0.7, 1.0) * np.minimum((t[-1] - t) / 1.5, 1.0)
        for note in chord:
            for detune, pan in ((-0.07, -0.7), (0.07, 0.7)):
                freq = midi(note + detune)
                voice = np.sin(TAU * freq * t) + 0.22 * np.sin(TAU * freq * 2.0 * t) + 0.08 * np.sin(TAU * freq * 3.0 * t)
                add(voice * swell, start, pan, 0.085)

        # Bass: the root on the first beat, and again just before the third.
        for beat, length, gain in ((0.0, 2.3, 1.0), (2.5, 1.4, 0.7)):
            t = times(length * BEAT, rate)
            freq = midi(bass_note)
            tone = (np.sin(TAU * freq * t) + 0.35 * np.sin(TAU * freq * 2.0 * t)) * np.minimum(t / 0.012, 1.0) * np.exp(-t / 0.9)
            add(faded(tone, rate, 0.03), start + beat, 0.0, 0.36 * gain)

        # The chord picked out an octave up, quieter the first time round.
        for step, index in enumerate(ARPEGGIO):
            if not second_half and step % 2 == 1 and bar < 4:
                continue
            tone = pluck(midi(chord[index] + 12), 1.3, rate, decay=0.34, bright=0.35)
            late = 0.03 if step % 2 == 1 else 0.0
            add(tone, start + step * 0.5 + late, (-0.45, 0.45)[step % 2], 0.15 * rng.uniform(0.75, 1.0))

        if second_half:
            for beat, note, length in TUNE[bar - 8]:
                tone = pluck(midi(note), length * BEAT + 1.2, rate, decay=0.5 + 0.15 * length, bright=0.55)
                add(tone, start + beat, 0.1, 0.3)

        if bar >= 4:
            # A shaker on the eighths, a soft thump on one and three, a tick on two and four.
            for step in range(8):
                t = times(0.07, rate)
                hiss = rng.standard_normal(len(t)) * np.exp(-t / (0.02 if step % 2 == 0 else 0.012))
                hiss = shape(hiss, rate, highpass(5200.0))
                add(hiss, start + step * 0.5, 0.3, 0.035 if step % 2 == 0 else 0.055)
            for beat in (0.0, 2.0):
                t = times(0.3, rate)
                thump = np.sin(TAU * (48.0 * t + 22.0 * 0.05 * (1.0 - np.exp(-t / 0.05)))) * np.exp(-t / 0.09)
                add(thump, start + beat, 0.0, 0.3)
            for beat in (1.0, 3.0):
                t = times(0.1, rate)
                tick = np.sin(TAU * 880.0 * t) * np.exp(-t / 0.014)
                add(tick, start + beat, -0.25, 0.08)

    mix = np.stack([left, right], axis=1)
    # An echo a dotted eighth behind, swapped to the other side each time.
    echo = int(round(0.75 * BEAT * rate))
    wet = shape(mix, rate, lowpass(2400.0))
    mix = mix + 0.24 * np.roll(wet[:, ::-1], echo, axis=0) + 0.1 * np.roll(wet, 2 * echo, axis=0)
    mix = shape(mix, rate, lambda freq: lowpass(7500.0)(freq) * highpass(32.0)(freq))
    write("music/menu_theme", mix, rate, peak=0.7)


FAMILIES = {
    "ui": [ui_sounds],
    "printer": [
        fan_loop,
        lambda: motion_loop("motion_a", 41, 170.0, 620.0, 1.0),
        lambda: motion_loop("motion_b", 42, 230.0, 840.0, 1.3),
        done_beep,
    ],
    "music": [menu_theme],
}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--only", default="", help="ui, printer or music")
    options = parser.parse_args(sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else [])
    for family, builders in FAMILIES.items():
        if options.only in ("", family):
            for build in builders:
                build()


main()
