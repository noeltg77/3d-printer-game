"""The trailer's edit, in bars of its music: when each shot, title and sound
falls. build_trailer.py cuts the picture to it and music.py scores to it,
so the two stay in step. Plain Python, no Blender.

At 100 beats a minute and 60 frames a second a beat is 36 frames and a bar
(four beats) is 144, so every cut lands exactly on a frame.
"""

FPS = 60
BPM = 100
BEAT = FPS * 60 // BPM          # 36 frames
BAR = BEAT * 4                  # 144 frames
WIDTH, HEIGHT = 1920, 1080

INTRO_BARS = 4                  # pad and printer, no beat
GROOVE_BAR = 8                  # the drums come in
LIFT_BAR = 16                   # bigger, the tune an octave up
MONTAGE_BAR = 20                # a premises a bar, garage to factory
RISE_BAR = 24                   # everything pulls back for the logo
LOGO_BAR = 25                   # the hit
END_BAR = 29


def bar(b):
    return int(round(b * BAR))


# name, first bar, last bar (exclusive). Each is a function in build_trailer.py.
SHOTS = [
    ("first_print", 0, 2.75),
    ("garage_reveal", 2.75, 4),
    ("catalogue", 4, 6),
    ("pack_and_post", 6, 8),
    ("spaghetti", 8, 10),
    ("multicolour", 10, 12),
    ("hire_a_team", 12, 14),
    ("design_desk", 14, 16),
    ("automation", 16, 18),
    ("round_the_clock", 18, 20),
    ("montage_garage", 20, 21),
    ("montage_unit", 21, 22),
    ("montage_workshop", 22, 23),
    ("montage_factory", 23, 25),
    ("logo", 25, END_BAR + 0.5),
]

# heading, line(s) under it, from bar, to bar
CARDS = [
    ("Print 660+ designs", "Phone stands, dice towers, dragons\nand everything in between", 4.25, 5.9),
    ("Sell, pack and post", "List on three marketplaces and ship\nevery order before the courier calls", 6.25, 7.9),
    ("Spaghetti happens", "Tune your settings, swap worn parts\nand fit upgrades", 8.25, 9.9),
    ("Go multicolour", "12 filaments, from silk and glow\nin the dark to wood, carbon and resin", 10.25, 11.9),
    ("Hire a team", "Operators and packers on the\nshifts you set", 12.25, 13.9),
    ("Make it your own", "Study new skills, design your own products\nand license them to other makers", 14.25, 15.9),
    ("Automate the lot", "Auto-eject plates, conveyors\nand injection moulding", 16.25, 17.9),
    ("Never close", "Win business contracts and keep\nthe printers running through the night", 18.25, 19.9),
]

# label, from bar, to bar
CHIPS = [
    ("Garage", 20.1, 20.95),
    ("Small unit", 21.1, 21.95),
    ("Workshop", 22.1, 22.95),
    ("Factory", 23.1, 24.6),
]

# words, from bar, to bar, height in pixels from the middle
STATEMENTS = [
    ("It all starts with one printer", 0.75, 2.6, 0),
    ("in your garage", 2.9, 3.95, 0),
    ("From one printer in the garage", 20.1, 21.95, 300),
    ("to a factory floor of them", 22.1, 24.6, 300),
]

# sound, at bar, gain (assets/audio/<sound>.wav)
SFX = [
    ("printer/motion_a", 0.0, 0.35, 2.75),   # (sound, bar, gain, bars long) for loops
    ("printer/done", 2.55, 0.6),
    ("ui/open", 4.25, 0.5),
    ("ui/open", 6.25, 0.5),
    ("ui/open", 8.25, 0.5),
    ("ui/open", 10.25, 0.5),
    ("ui/open", 12.25, 0.5),
    ("ui/open", 14.25, 0.5),
    ("ui/open", 16.25, 0.5),
    ("ui/open", 18.25, 0.5),
    ("ui/click", 20.1, 0.45),
    ("ui/click", 21.1, 0.45),
    ("ui/click", 22.1, 0.45),
    ("ui/click", 23.1, 0.45),
    ("ui/chime", 25.0, 0.55),
    ("ui/click", 26.5, 0.5),
]

LOGO_BUTTON_BAR = 26.5
END_FRAME = bar(END_BAR) + FPS  # a second of ring out after the last bar
