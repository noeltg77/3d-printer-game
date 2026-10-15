"""The trailer's soundtrack: the menu theme's chords and tune (from
tools/generators/audio.py) arranged to the edit in timeline.py, at 100 beats
a minute: a quiet intro over a printer at work, the drums at the groove, a
lift, a riser, and one big chord for the logo. The game's own UI and printer
sounds are mixed in where the timeline says. Synthesised like the rest of the
game's sound, seeded, so it comes out the same every time.

blender --background --factory-startup --python tools/trailer/music.py
(or any Python with numpy). Writes tools/trailer/out/soundtrack.wav.
"""

import sys
import wave
from pathlib import Path

import numpy as np

HERE = Path(__file__).resolve().parent
sys.path.append(str(HERE))
import timeline as T  # noqa: E402

ROOT = HERE.parents[1]
OUT = HERE / "out" / "soundtrack.wav"
RATE = 48000
TAU = 2.0 * np.pi
BEAT_S = 60.0 / T.BPM
BAR_S = BEAT_S * 4

# The menu theme (tools/generators/audio.py MENU_THEME): bass, chord.
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
ARPEGGIO = (0, 2, 1, 3, 2, 3, 1, 2)


def midi(note):
    return 440.0 * 2.0 ** ((note - 69) / 12.0)


def times(seconds):
    return np.arange(int(seconds * RATE)) / RATE


def shape(signal, response):
    spectrum = np.fft.rfft(signal, axis=0)
    gains = response(np.fft.rfftfreq(len(signal), 1.0 / RATE))
    return np.fft.irfft(spectrum * (gains if signal.ndim == 1 else gains[:, None]), len(signal), axis=0)


def lowpass(cutoff, steep=2.0):
    return lambda f: 1.0 / np.sqrt(1.0 + (f / cutoff) ** (2.0 * steep))


def highpass(cutoff, steep=2.0):
    return lambda f: 1.0 - 1.0 / np.sqrt(1.0 + (f / cutoff) ** (2.0 * steep))


def bandpass(low, high):
    return lambda f: highpass(low)(f) * lowpass(high)(f)


def pluck(freq, seconds, decay=0.25, bright=0.4):
    t = times(seconds)
    tone = np.sin(TAU * freq * t)
    tone += bright * np.sin(TAU * freq * 2.0 * t) * np.exp(-t / (decay * 0.35))
    tone += bright * 0.4 * np.sin(TAU * freq * 3.0 * t) * np.exp(-t / (decay * 0.2))
    return tone * np.minimum(t / 0.004, 1.0) * np.exp(-t / decay)


def bell(freq, seconds, decay=0.9):
    """A glassy bell: inharmonic partials that ring."""
    t = times(seconds)
    tone = np.zeros_like(t)
    for ratio, gain, d in ((1.0, 1.0, 1.0), (2.76, 0.4, 0.45), (5.4, 0.2, 0.25), (8.93, 0.08, 0.12)):
        tone += gain * np.sin(TAU * freq * ratio * t) * np.exp(-t / (decay * d))
    return tone * np.minimum(t / 0.002, 1.0)


def end_fade(signal, seconds=0.01):
    n = min(int(seconds * RATE), len(signal))
    signal[-n:] *= np.linspace(1.0, 0.0, n)
    return signal


class Mix:
    def __init__(self, seconds):
        self.n = int(seconds * RATE)
        self.left = np.zeros(self.n)
        self.right = np.zeros(self.n)
        self.duck = np.ones(self.n)

    def add(self, signal, at_seconds, pan=0.0, gain=1.0, bus="main"):
        start = int(round(at_seconds * RATE))
        if start >= self.n:
            return
        signal = signal[: self.n - start]
        if signal.ndim == 2:
            l, r = signal[:, 0], signal[:, 1]
        else:
            l = r = signal
        target = self.pad_left if bus == "pad" else self.left
        target_r = self.pad_right if bus == "pad" else self.right
        target[start:start + len(l)] += l * gain * np.sqrt(0.5 * (1.0 - pan))
        target_r[start:start + len(r)] += r * gain * np.sqrt(0.5 * (1.0 + pan))


def beats(b):
    return b * BEAT_S


def kick():
    t = times(0.45)
    sweep = 46.0 * t + (150.0 - 46.0) * 0.035 * (1.0 - np.exp(-t / 0.035))
    body = np.sin(TAU * sweep) * np.exp(-t / 0.16)
    click = np.random.default_rng(1).standard_normal(len(t)) * np.exp(-t / 0.003) * 0.25
    return end_fade(np.tanh((body + click) * 1.6))


def clap(rng):
    t = times(0.35)
    noise = rng.standard_normal(len(t))
    env = np.zeros_like(t)
    for delay in (0.0, 0.011, 0.022):
        env += np.where(t >= delay, np.exp(-(t - delay) / (0.008 if delay < 0.02 else 0.09)), 0.0)
    snap = shape(noise * env, bandpass(900.0, 5500.0))
    tone = np.sin(TAU * 190.0 * t) * np.exp(-t / 0.05) * 0.3
    return end_fade(snap + tone)


def hat(rng, open_=False):
    t = times(0.25 if open_ else 0.06)
    noise = shape(rng.standard_normal(len(t)), highpass(7000.0, 3.0))
    return end_fade(noise * np.exp(-t / (0.07 if open_ else 0.014)))


def crash(rng, seconds=3.5):
    t = times(seconds)
    noise = shape(rng.standard_normal(len(t)), highpass(4200.0, 2.0))
    shimmer = shape(rng.standard_normal(len(t)), bandpass(2500.0, 9000.0)) * 0.4
    return end_fade((noise + shimmer) * np.exp(-t / 0.9) * np.minimum(t / 0.002, 1.0))


def riser(rng, seconds):
    """Noise that opens up and a tone that climbs, into the hit."""
    t = times(seconds)
    k = t / seconds
    noise = rng.standard_normal(len(t))
    # Split into slices, each filtered a little brighter than the last.
    out = np.zeros_like(t)
    slices = 24
    edges = np.linspace(0, len(t), slices + 1).astype(int)
    for i in range(slices):
        a, b = edges[i], edges[i + 1]
        cut = 400.0 * (18.0 ** (i / slices))
        piece = noise[max(0, a - 2000):b]
        filtered = shape(piece, bandpass(cut * 0.5, cut * 2.5))[-(b - a):]
        out[a:b] = filtered
    tone = np.sin(TAU * np.cumsum(110.0 * 2.0 ** (k * 2.0)) / RATE) * 0.25
    return end_fade((out + tone) * k ** 2.2)


def boom():
    t = times(2.5)
    sweep = 38.0 * t + 70.0 * 0.12 * (1.0 - np.exp(-t / 0.12))
    return end_fade(np.tanh(np.sin(TAU * sweep) * np.exp(-t / 0.7) * 1.4))


def pad_chord(chord, seconds, bright=1.0):
    t = times(seconds + 1.8)
    swell = np.minimum(t / 0.5, 1.0) * np.minimum((t[-1] - t) / 1.6, 1.0)
    left = np.zeros_like(t)
    right = np.zeros_like(t)
    for note in chord:
        for detune, side in ((-0.08, 0), (0.08, 1), (0.0, 2)):
            freq = midi(note + detune)
            voice = np.sin(TAU * freq * t) + 0.25 * bright * np.sin(TAU * freq * 2.0 * t) + 0.1 * bright * np.sin(TAU * freq * 3.0 * t)
            if side == 0:
                left += voice
            elif side == 1:
                right += voice
            else:
                left += 0.5 * voice
                right += 0.5 * voice
    return np.stack([left, right], axis=1) * swell[:, None]


def read_wav(path):
    with wave.open(str(path)) as f:
        rate, channels, n = f.getframerate(), f.getnchannels(), f.getnframes()
        data = np.frombuffer(f.readframes(n), dtype="<i2").astype(float) / 32768.0
    data = data.reshape(-1, channels)
    if channels == 1:
        data = np.repeat(data, 2, axis=1)
    if rate != RATE:
        src = np.arange(len(data)) / rate
        dst = np.arange(int(len(data) * RATE / rate)) / RATE
        data = np.stack([np.interp(dst, src, data[:, c]) for c in range(2)], axis=1)
    return data


def build():
    total = T.END_FRAME / T.FPS + 0.5
    mix = Mix(total)
    mix.pad_left = np.zeros(mix.n)
    mix.pad_right = np.zeros(mix.n)
    rng = np.random.default_rng(77)
    bars = T.END_BAR

    for b in range(T.RISE_BAR):
        bass_note, chord = CHORDS[b % 8]
        start = b * BAR_S
        intro = b < T.INTRO_BARS
        groove = b >= T.GROOVE_BAR
        lift = b >= T.LIFT_BAR

        # Pad, quieter in the intro until it swells in.
        level = 0.05 if intro else (0.07 if not lift else 0.085)
        if b == 0:
            level = 0.035
        mix.add(pad_chord(chord, BAR_S, 0.8 if not lift else 1.1), start, gain=level, bus="pad")

        # Bass from bar 4: the root on one and the and of two, busier in the groove.
        if not intro:
            pattern = ((0.0, 1.4, 1.0), (1.5, 0.9, 0.7), (2.5, 1.4, 0.85)) if groove else ((0.0, 2.3, 1.0), (2.5, 1.4, 0.7))
            for beat, length, g in pattern:
                t = times(length * BEAT_S)
                f = midi(bass_note)
                tone = (np.sin(TAU * f * t) + 0.4 * np.sin(TAU * f * 2 * t) + 0.12 * np.sin(TAU * f * 3 * t))
                tone *= np.minimum(t / 0.008, 1.0) * np.exp(-t / 0.8)
                mix.add(end_fade(tone, 0.03), start + beats(beat), gain=0.32 * g)

        # The chord picked out: quarter notes in the intro, eighths after,
        # and sixteenth sparkle in the lift.
        for step, index in enumerate(ARPEGGIO):
            if intro and step % 2 == 1:
                continue
            tone = pluck(midi(chord[index] + 12), 1.2, decay=0.3, bright=0.4)
            mix.add(tone, start + step * 0.5 * BEAT_S, pan=(-0.5, 0.5)[step % 2], gain=0.11 * rng.uniform(0.8, 1.0))
        if lift:
            for step in range(16):
                note = chord[(step * 3) % 4] + 24
                mix.add(bell(midi(note), 0.6, 0.25), start + step * 0.25 * BEAT_S, pan=np.sin(step) * 0.7, gain=0.025)

        # The menu theme's tune over the groove, doubled an octave up in the lift.
        if groove:
            for beat, note, length in TUNE[(b - T.GROOVE_BAR) % 8]:
                tone = pluck(midi(note), length * BEAT_S + 1.0, decay=0.45 + 0.15 * length, bright=0.6)
                mix.add(tone, start + beats(beat), pan=0.1, gain=0.2)
                if lift:
                    mix.add(bell(midi(note + 12), length * BEAT_S + 1.2, 0.6), start + beats(beat), pan=-0.2, gain=0.06)

        # Drums.
        if b >= T.INTRO_BARS:
            for step in range(8 if not groove else 16):
                at = start + step * (0.5 if not groove else 0.25) * BEAT_S
                accent = 1.0 if step % 2 == 0 else 0.6
                mix.add(hat(rng), at, pan=0.35, gain=(0.05 if not groove else 0.07) * accent)
        if groove:
            kicks = (0, 1, 2, 3) if lift else (0, 2, 2.75)
            for beat in kicks:
                at = start + beats(beat)
                mix.add(kick(), at, gain=0.75)
                # Pump the pad under the kick.
                i = int(at * RATE)
                n = int(0.32 * RATE)
                if i < mix.n:
                    curve = 1.0 - 0.55 * np.exp(-np.arange(n) / RATE / 0.12)
                    mix.duck[i:i + n] = np.minimum(mix.duck[i:i + n], curve[: max(0, min(n, mix.n - i))])
            for beat in (1, 3):
                mix.add(clap(rng), start + beats(beat), pan=-0.1, gain=0.32)
            if b % 2 == 1:
                mix.add(hat(rng, True), start + beats(3.5), pan=0.4, gain=0.08)
        if b in (T.GROOVE_BAR, T.LIFT_BAR, T.MONTAGE_BAR):
            mix.add(crash(rng), start, pan=0.2, gain=0.22)
        if b == T.GROOVE_BAR - 1:
            mix.add(riser(rng, BAR_S), start, gain=0.12)

    # The rise into the logo: the pad held on the last chord, a riser, a
    # roll of claps tightening, then silence for a beat.
    rise = T.RISE_BAR * BAR_S
    mix.add(pad_chord(CHORDS[7][1], BAR_S * 0.75, 1.2), rise, gain=0.08, bus="pad")
    mix.add(riser(rng, BAR_S * 0.9), rise, gain=0.3)
    for i in range(12):
        at = rise + beats(i * 0.25)
        mix.add(clap(rng), at, gain=0.1 + 0.02 * i)

    # The hit: D major 9 with everything, ringing out under the logo.
    hit = T.LOGO_BAR * BAR_S
    mix.add(boom(), hit, gain=0.9)
    mix.add(kick(), hit, gain=0.9)
    mix.add(crash(rng, 5.0), hit, gain=0.35)
    ring = (bars - T.LOGO_BAR) * BAR_S + 1.0
    mix.add(pad_chord((50, 54, 57, 61, 64, 69), ring, 1.3), hit, gain=0.075, bus="pad")
    for i, note in enumerate((62, 66, 69, 73, 76, 81)):
        mix.add(bell(midi(note), 4.0, 1.6), hit + i * 0.09, pan=(-0.6 + 0.24 * i), gain=0.09)
    t = times(ring)
    bass = (np.sin(TAU * midi(38) * t) + 0.35 * np.sin(TAU * midi(50) * t)) * np.exp(-t / 3.0) * np.minimum(t / 0.01, 1.0)
    mix.add(end_fade(bass, 1.0), hit, gain=0.3)
    # The theme's opening phrase once more, softly, over the logo.
    for beat, note, length in TUNE[0]:
        mix.add(pluck(midi(note), length * BEAT_S + 1.5, decay=0.7, bright=0.5), hit + BAR_S + beats(beat), gain=0.16)
    for beat, note, length in TUNE[7]:
        mix.add(pluck(midi(note), length * BEAT_S + 2.0, decay=0.9, bright=0.5), hit + 2 * BAR_S + beats(beat), gain=0.14)

    # Sound effects from the game.
    for entry in T.SFX:
        name, at_bar, gain = entry[:3]
        sound = read_wav(ROOT / "assets" / "audio" / (name + ".wav"))
        if len(entry) > 3:
            # A loop, played for so many bars, faded at each end.
            want = int(entry[3] * BAR_S * RATE)
            sound = np.tile(sound, (want // len(sound) + 1, 1))[:want]
            fade = np.minimum(np.minimum(np.arange(want) / (0.6 * RATE), 1.0), np.minimum((want - np.arange(want)) / (0.25 * RATE), 1.0))
            sound = sound * fade[:, None]
        mix.add(sound, at_bar * BAR_S, gain=gain)

    pad = np.stack([mix.pad_left, mix.pad_right], axis=1) * mix.duck[:, None]
    main = np.stack([mix.left, mix.right], axis=1)
    out = main + pad
    # Echo a dotted eighth behind, opposite side, darker.
    echo = int(round(0.75 * BEAT_S * RATE))
    wet = shape(out, lowpass(2600.0))
    delayed = np.zeros_like(out)
    delayed[echo:] = wet[:-echo, ::-1]
    out = out + 0.18 * delayed
    out = shape(out, lambda f: lowpass(12000.0)(f) * highpass(28.0)(f))
    # Fade the tail, then a gentle limiter.
    tail = int(1.2 * RATE)
    out[-tail:] *= np.linspace(1.0, 0.0, tail)[:, None]
    out = out / np.max(np.abs(out)) * 1.4
    out = np.tanh(out) / np.tanh(1.4) * 0.89
    OUT.parent.mkdir(parents=True, exist_ok=True)
    with wave.open(str(OUT), "wb") as f:
        f.setnchannels(2)
        f.setsampwidth(2)
        f.setframerate(RATE)
        f.writeframes((np.clip(out, -1, 1) * 32767).astype("<i2").tobytes())
    print("Wrote %s (%.1f s)" % (OUT.relative_to(ROOT), len(out) / RATE))


build()
