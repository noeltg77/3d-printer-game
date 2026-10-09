"""Printed item generator for the outdoor categories of the Spare room tier,
Travel and camping, Garden and outdoor, Sports and fitness, and Summer.

Same rules as prints.py: tint material, origin at the centre of the base, a
little larger than life so items read at the game's camera distance.

blender --background --factory-startup --python tools/generators/prints_outdoor.py -- \
    --variant collapsible_cup --out assets/models/prints/collapsible_cup.glb
"""

import math
import sys
from pathlib import Path

sys.path.append(str(Path(__file__).resolve().parent))
import common
import print_shapes
from common import MeshBuilder
from print_shapes import COLOUR


def add_arguments(parser):
    parser.add_argument("--variant", choices=tuple(VARIANTS), required=True)


def build(args, rng):
    builder = MeshBuilder(material=common.TINT_MATERIAL_NAME)
    VARIANTS[args.variant](builder)
    builder.finish(args.out.stem)


def _scaled(points, x_scale, y_scale=None):
    y_scale = x_scale if y_scale is None else y_scale
    return [(x * x_scale, y * y_scale) for x, y in points]


# Travel and camping

def _tent_peg_set_x8(builder):
    """Eight flat tent pegs side by side: a long shank with a point one end and a hook the other."""
    peg = [(0, -0.085), (0.006, -0.068), (0.006, 0.058), (0.017, 0.058), (0.017, 0.075), (-0.006, 0.075), (-0.006, -0.068)]
    for x, _ in print_shapes.grid(8, 1, 0.031, 0):
        builder.plate(peg, 0.008, COLOUR, centre=(x - 0.005, 0, 0))


def _guy_line_tensioners_x8(builder):
    """Eight little slider bars in two rows, each with a ridge across the middle."""
    for x, y in print_shapes.grid(4, 2, 0.04, 0.03):
        builder.box((0.032, 0.014, 0.004), (x, y, 0.002), COLOUR)
        builder.box((0.006, 0.014, 0.004), (x, y, 0.006), COLOUR)


def _collapsible_cup(builder):
    """Cup made of three rings that widen towards the rim, each sitting in the one above."""
    builder.shell(0.03, 0.028, 0.004, COLOUR, segments=8, radius_top=0.035)
    builder.shell(0.036, 0.028, 0.004, COLOUR, segments=8, centre=(0, 0, 0.022), radius_top=0.041, open_base=True)
    builder.shell(0.042, 0.028, 0.004, COLOUR, segments=8, centre=(0, 0, 0.044), radius_top=0.047, open_base=True)


def _camping_cutlery_set(builder):
    """Knife, fork and spoon lying flat, side by side."""
    builder.plate([(-0.008, -0.07), (0.006, -0.07), (0.006, 0.07), (-0.002, 0.07), (-0.01, 0.01)], 0.005, COLOUR, centre=(-0.04, 0, 0))
    builder.box((0.012, 0.085, 0.005), (0, -0.0275, 0.0025), COLOUR)
    builder.box((0.024, 0.02, 0.005), (0, 0.022, 0.0025), COLOUR)
    for x in (-0.009, 0.0, 0.009):
        builder.box((0.005, 0.04, 0.005), (x, 0.05, 0.0025), COLOUR)
    builder.box((0.012, 0.09, 0.005), (0.04, -0.025, 0.0025), COLOUR)
    builder.cylinder(0.017, 0.006, (0.04, 0.04, 0.003), COLOUR, segments=8)


def _gas_canister_stand(builder):
    """Ring that clips round the canister with three legs splayed out flat."""
    builder.shell(0.042, 0.014, 0.007, COLOUR, segments=8, open_base=True)
    for index in range(3):
        angle = math.pi / 2 + math.tau * index / 3
        reach = (math.cos(angle), math.sin(angle))
        builder.box((0.07, 0.016, 0.008), (0.072 * reach[0], 0.072 * reach[1], 0.004), COLOUR, rotation=(0, 0, angle))
        builder.box((0.016, 0.026, 0.012), (0.105 * reach[0], 0.105 * reach[1], 0.006), COLOUR, rotation=(0, 0, angle))


def _lantern_diffuser(builder):
    """Faceted dome on a collar that pushes over a torch or lantern."""
    builder.cylinder(0.05, 0.03, (0, 0, 0.015), COLOUR, segments=10, radius_top=0.046)
    builder.ball(0.062, (0, 0, 0.082), COLOUR, scale=(1.0, 1.0, 1.1))


def _luggage_tag(builder):
    """Flat tag with clipped corners, a raised frame for the address card and a loop for the strap."""
    builder.plate([(-0.03, -0.055), (0.03, -0.055), (0.03, 0.04), (0.016, 0.058), (-0.016, 0.058), (-0.03, 0.04)], 0.005, COLOUR)
    builder.outline([(-0.023, -0.047), (0.023, -0.047), (0.023, 0.022), (-0.023, 0.022)], 0.008, 0.004, COLOUR)
    builder.shell(0.011, 0.008, 0.004, COLOUR, segments=6, centre=(0, 0.044, 0), open_base=True)


def _passport_cover(builder):
    """Passport wallet lying slightly open: two covers hinged along a spine."""
    tilt = math.radians(14)
    for side in (-1, 1):
        builder.box(
            (0.095, 0.135, 0.006), (side * 0.047 * math.cos(tilt), 0, 0.005 + 0.047 * math.sin(tilt)), COLOUR,
            rotation=(0, -side * tilt, 0))
    builder.box((0.012, 0.135, 0.008), (0, 0, 0.004), COLOUR)


def _toiletry_travel_bottles_x3(builder):
    """Three small bottles of different heights, each with a narrower cap."""
    for (x, _), height in zip(print_shapes.grid(3, 1, 0.048, 0), (0.07, 0.055, 0.045)):
        builder.cylinder(0.019, height, (x, 0, height / 2), COLOUR, segments=8, radius_top=0.016)
        builder.cylinder(0.011, 0.014, (x, 0, height + 0.007), COLOUR, segments=6)


def _travel_soap_box(builder):
    """Closed soap box with a lid that overhangs all round and a thumb catch at the front."""
    builder.box((0.11, 0.075, 0.028), (0, 0, 0.014), COLOUR, bevel=0.007, bevel_segments=2)
    builder.box((0.116, 0.081, 0.014), (0, 0, 0.033), COLOUR, bevel=0.005)
    builder.box((0.03, 0.008, 0.012), (0, -0.041, 0.026), COLOUR)


def _hiking_pole_tip_protectors_x2(builder):
    """Two rubber feet for walking poles: a flared sole under a tapering sleeve."""
    for side in (-1, 1):
        builder.cylinder(0.022, 0.01, (side * 0.03, 0, 0.005), COLOUR, segments=8, radius_top=0.018)
        builder.cylinder(0.016, 0.04, (side * 0.03, 0, 0.03), COLOUR, segments=8, radius_top=0.011)
    builder.enlarge(1.3)


def _fishing_lure_set_x5(builder):
    """Five flat fish-shaped lures in three sizes."""
    fish = [(-0.03, 0), (-0.012, -0.01), (0.012, -0.005), (0.03, -0.012), (0.03, 0.012), (0.012, 0.005), (-0.012, 0.01)]
    for x, y, size in ((-0.045, 0.03, 1.0), (0.035, 0.03, 1.2), (-0.055, -0.01, 0.8), (0.02, -0.008, 1.0), (-0.02, -0.04, 1.2)):
        builder.plate(_scaled(fish, size), 0.006, COLOUR, centre=(x, y, 0))


def _fishing_reel_spool_holder(builder):
    """Base with two uprights and an axle carrying a spool of line."""
    builder.box((0.13, 0.1, 0.012), (0, 0, 0.006), COLOUR, bevel=0.004)
    for side in (-1, 1):
        builder.box((0.01, 0.05, 0.085), (side * 0.055, 0, 0.052), COLOUR, taper=(1.0, 0.45))
        builder.cylinder(0.038, 0.008, (side * 0.03, 0, 0.075), COLOUR, segments=8, axis="X")
    builder.cylinder(0.008, 0.125, (0, 0, 0.075), COLOUR, segments=6, axis="X")
    builder.cylinder(0.02, 0.055, (0, 0, 0.075), COLOUR, segments=6, axis="X")


def _carabiner_light_duty(builder):
    """Flat D-shaped clip with a sprung gate bar across the straight side."""
    builder.outline([(-0.012, -0.04), (0.016, -0.04), (0.028, -0.02), (0.028, 0.03), (0.016, 0.045), (-0.012, 0.045)], 0.008, 0.007, COLOUR)
    builder.box((0.005, 0.05, 0.006), (-0.004, 0.005, 0.004), COLOUR, rotation=(0, 0, math.radians(8)))
    builder.enlarge(1.5)


def _map_compass_housing(builder):
    """Clear-style base plate with a round capsule, a needle inside it and a lanyard lug."""
    builder.box((0.07, 0.11, 0.006), (0, 0, 0.003), COLOUR)
    builder.shell(0.03, 0.014, 0.005, COLOUR, segments=8, centre=(0, 0.012, 0.004))
    builder.box((0.006, 0.04, 0.004), (0, 0.012, 0.012), COLOUR, rotation=(0, 0, math.radians(35)))
    builder.box((0.02, 0.014, 0.006), (0, -0.06, 0.003), COLOUR)


# Garden and outdoor

def _seed_starter_pots_x12(builder):
    """Twelve small pots joined as a tray, four by three."""
    print_shapes.divided_tray(builder, (0.22, 0.165, 0.05), 0.005, across=3, along=2, divider_height=0.05, chamfer=0.003)


def _plant_labels_x20(builder):
    """Twenty flat plant labels in two rows, each tapering to a point to push into the soil."""
    label = [(-0.007, 0.032), (-0.002, -0.032), (0.002, -0.032), (0.007, 0.032)]
    for x, y in print_shapes.grid(10, 2, 0.019, 0.072):
        builder.plate(label, 0.004, COLOUR, centre=(x, y, 0))


def _hose_connector(builder):
    """Hose coupling standing on end: a hex collar, a barrel and a tapered barb."""
    builder.cylinder(0.022, 0.02, (0, 0, 0.01), COLOUR, segments=6)
    builder.cylinder(0.016, 0.035, (0, 0, 0.0375), COLOUR, segments=8)
    builder.cylinder(0.02, 0.008, (0, 0, 0.04), COLOUR, segments=8)
    builder.cylinder(0.012, 0.03, (0, 0, 0.07), COLOUR, segments=6, radius_top=0.008)
    builder.enlarge(1.5)


def _hose_guide_spike(builder):
    """Ground spike lying flat, with a forked head that carries a roller for the hose."""
    print_shapes.limb(builder, (0, 0.01, 0.012), (0, -0.11, 0.004), 0.012, 0.003)
    builder.cylinder(0.012, 0.012, (0, 0.016, 0.012), COLOUR, segments=6, axis="Y")
    for side in (-1, 1):
        builder.box((0.008, 0.05, 0.016), (side * 0.022, 0.045, 0.008), COLOUR)
    builder.box((0.052, 0.01, 0.016), (0, 0.024, 0.008), COLOUR)
    builder.cylinder(0.012, 0.036, (0, 0.058, 0.012), COLOUR, segments=6, axis="X")


def _bird_feeder(builder):
    """Seed tube under a wide cone roof, standing in a shallow tray with two perches."""
    builder.shell(0.085, 0.022, 0.007, COLOUR, segments=8)
    builder.cylinder(0.042, 0.13, (0, 0, 0.072), COLOUR, segments=8)
    builder.cylinder(0.09, 0.05, (0, 0, 0.16), COLOUR, segments=10, radius_top=0.012)
    builder.cylinder(0.01, 0.016, (0, 0, 0.19), COLOUR, segments=6)
    for side in (-1, 1):
        builder.box((0.05, 0.008, 0.008), (side * 0.1, 0, 0.018), COLOUR)


def _bug_hotel(builder):
    """Little open-fronted house with a pitched roof, a shelf across the middle and tubes stacked inside."""
    builder.box((0.15, 0.012, 0.16), (0, 0.034, 0.08), COLOUR)
    builder.box((0.15, 0.08, 0.012), (0, 0, 0.006), COLOUR)
    builder.box((0.15, 0.08, 0.01), (0, 0, 0.085), COLOUR)
    for side in (-1, 1):
        builder.box((0.012, 0.08, 0.16), (side * 0.069, 0, 0.08), COLOUR)
        builder.box((0.115, 0.095, 0.012), (side * 0.045, 0, 0.186), COLOUR, rotation=(0, side * math.radians(30), 0))
    for x, z in ((-0.035, 0.03), (0.0, 0.03), (0.035, 0.03), (-0.018, 0.058), (0.018, 0.058), (0.0, 0.118)):
        builder.cylinder(0.016, 0.07, (x, -0.002, z), COLOUR, segments=6, axis="Y")


def _self_watering_planter(builder):
    """Wide reservoir pot with a taller plant pot sitting inside it and a filling spout at the side."""
    builder.shell(0.09, 0.06, 0.008, COLOUR, segments=8, radius_top=0.1, chamfer=0.004)
    builder.shell(0.065, 0.085, 0.007, COLOUR, segments=8, centre=(0, 0, 0.03), radius_top=0.082)
    builder.box((0.028, 0.03, 0.05), (0.098, 0, 0.045), COLOUR, taper=(1.3, 1.0))


def _tomato_cage_clips_x20(builder):
    """Twenty little clip blocks in four rows of five."""
    for x, y in print_shapes.grid(5, 4, 0.026, 0.03):
        builder.box((0.016, 0.02, 0.01), (x, y, 0.005), COLOUR, taper=(0.5, 1.0))


def _watering_spike_adapter_x4(builder):
    """Four watering spikes standing point up, each on a threaded collar that screws onto a bottle."""
    for x, y in print_shapes.grid(2, 2, 0.05, 0.05):
        builder.cylinder(0.019, 0.016, (x, y, 0.008), COLOUR, segments=8)
        builder.cylinder(0.014, 0.075, (x, y, 0.0535), COLOUR, segments=6, radius_top=0.003)


def _solar_light_stake_replacement(builder):
    """Garden light stake lying flat: a long tapering blade with a fin along it and a socket at the top."""
    builder.plate([(-0.012, 0.06), (-0.002, -0.09), (0.002, -0.09), (0.012, 0.06)], 0.005, COLOUR)
    builder.box((0.004, 0.13, 0.014), (0, -0.01, 0.007), COLOUR, taper=(1.0, 0.9))
    builder.cylinder(0.016, 0.03, (0, 0.075, 0.016), COLOUR, segments=6, axis="Y")


def _trellis_clips_x20(builder):
    """Twenty diamond-shaped clips in two rows of ten."""
    for x, y in print_shapes.grid(10, 2, 0.024, 0.03):
        builder.box((0.014, 0.014, 0.008), (x, y, 0.004), COLOUR, rotation=(0, 0, math.pi / 4))


def _rain_gauge(builder):
    """Tall measuring tube with a flared collecting funnel, raised marks down the side and a foot to stand on."""
    builder.box((0.08, 0.08, 0.01), (0, 0, 0.005), COLOUR)
    builder.shell(0.03, 0.16, 0.005, COLOUR, segments=8, centre=(0, 0, 0.008))
    builder.shell(0.03, 0.03, 0.005, COLOUR, segments=8, centre=(0, 0, 0.165), radius_top=0.05, open_base=True)
    for index in range(5):
        builder.box((0.016, 0.006, 0.004), (0, -0.03, 0.04 + index * 0.025), COLOUR)


def _garden_kneeler_handle(builder):
    """Tall U-shaped handle: two uprights with a clamp at each foot and a round grip across the top."""
    for side in (-1, 1):
        builder.box((0.02, 0.03, 0.19), (side * 0.11, 0, 0.095), COLOUR)
        builder.box((0.04, 0.05, 0.03), (side * 0.11, 0, 0.015), COLOUR)
    builder.cylinder(0.016, 0.24, (0, 0, 0.19), COLOUR, segments=8, axis="X")


def _pond_fish_feeder_ring(builder):
    """Floating ring that keeps fish food in one place, with three float lugs round the outside."""
    builder.shell(0.065, 0.022, 0.012, COLOUR, segments=10, open_base=True)
    for index in range(3):
        angle = math.pi / 2 + math.tau * index / 3
        builder.box((0.03, 0.024, 0.016), (0.07 * math.cos(angle), 0.07 * math.sin(angle), 0.008), COLOUR, rotation=(0, 0, angle))


# Sports and fitness

def _tennis_ball_holder(builder):
    """Springy ring that grips a tennis ball, on a flat clip plate."""
    builder.box((0.06, 0.008, 0.07), (0, 0.05, 0.035), COLOUR)
    builder.shell(0.044, 0.022, 0.007, COLOUR, segments=8, centre=(0, 0.004, 0.03), turn=math.pi / 8, open_base=True)


def _bike_helmet_hook(builder):
    """Round wall plate with a short arm that ends in a wide mushroom cap."""
    builder.cylinder(0.04, 0.012, (0, 0.05, 0.04), COLOUR, segments=8, axis="Y")
    print_shapes.limb(builder, (0, 0.05, 0.04), (0, -0.03, 0.04), 0.014, 0.012)
    builder.ball(0.03, (0, -0.036, 0.04), COLOUR, subdivisions=1, scale=(1.0, 0.5, 1.0))


def _dumbbell_rack_clips_x4(builder):
    """Four cradles, each a base with a tapering ear either side for the handle to rest between."""
    for x, y in print_shapes.grid(2, 2, 0.1, 0.07):
        builder.box((0.08, 0.045, 0.012), (x, y, 0.006), COLOUR)
        for side in (-1, 1):
            builder.box((0.018, 0.045, 0.04), (x + side * 0.031, y, 0.03), COLOUR, taper=(0.5, 1.0))


def _yoga_mat_holder(builder):
    """Wall rail with two big upturned hooks that a rolled mat lies across."""
    builder.box((0.2, 0.012, 0.045), (0, 0.045, 0.0725), COLOUR, bevel=0.004)
    for side in (-1, 1):
        builder.box((0.02, 0.09, 0.016), (side * 0.07, 0.0, 0.058), COLOUR)
        builder.box((0.02, 0.016, 0.05), (side * 0.07, -0.037, 0.075), COLOUR)
        builder.box((0.02, 0.016, 0.05), (side * 0.07, 0.031, 0.025), COLOUR)


def _water_bottle_cap_sports(builder):
    """Screw cap with a shoulder, a spout and a pull-up nozzle on top."""
    builder.cylinder(0.03, 0.022, (0, 0, 0.011), COLOUR, segments=10)
    builder.cylinder(0.03, 0.014, (0, 0, 0.029), COLOUR, segments=10, radius_top=0.014)
    builder.cylinder(0.011, 0.016, (0, 0, 0.044), COLOUR, segments=6)
    builder.cylinder(0.015, 0.008, (0, 0, 0.056), COLOUR, segments=6, radius_top=0.012)
    builder.enlarge(1.4)


def _shin_guard_straps(builder):
    """Two flat straps side by side, each with a buckle frame at one end."""
    for side in (-1, 1):
        y = side * 0.03
        builder.box((0.15, 0.024, 0.004), (0.01, y, 0.002), COLOUR)
        builder.outline([(-0.095, y - 0.018), (-0.06, y - 0.018), (-0.06, y + 0.018), (-0.095, y + 0.018)], 0.006, 0.006, COLOUR)


def _football_boot_tree_pair(builder):
    """Two boot trees: a rounded toe piece and a heel block joined by a bowed bar."""
    for side in (-1, 1):
        x = side * 0.045
        builder.ball(0.03, (x, -0.06, 0.022), COLOUR, subdivisions=1, scale=(1.0, 1.4, 0.75))
        builder.box((0.04, 0.03, 0.04), (x, 0.085, 0.02), COLOUR, taper=(0.7, 0.8))
        print_shapes.limb(builder, (x, -0.04, 0.03), (x, 0.02, 0.06), 0.008)
        print_shapes.limb(builder, (x, 0.02, 0.06), (x, 0.08, 0.03), 0.008)


def _climbing_chalk_bowl(builder):
    """Wide, deep bowl on a heavy foot so it doesn't tip when a hand goes in."""
    builder.cylinder(0.075, 0.014, (0, 0, 0.007), COLOUR, segments=8)
    builder.shell(0.065, 0.075, 0.009, COLOUR, segments=8, centre=(0, 0, 0.01), radius_top=0.092, chamfer=0.004)


def _swim_goggles_case(builder):
    """Peanut-shaped case: two round lobes with a lid that overhangs and a hinge at the back."""
    for side in (-1, 1):
        builder.cylinder(0.04, 0.03, (side * 0.032, 0, 0.015), COLOUR, segments=10)
        builder.cylinder(0.043, 0.014, (side * 0.032, 0, 0.035), COLOUR, segments=10, radius_top=0.036)
    builder.box((0.04, 0.012, 0.014), (0, 0.042, 0.028), COLOUR)


def _darts_flight_protectors_x9(builder):
    """Nine tiny cross-shaped caps in three rows."""
    for x, y in print_shapes.grid(3, 3, 0.03, 0.03):
        builder.box((0.02, 0.005, 0.008), (x, y, 0.004), COLOUR)
        builder.box((0.005, 0.02, 0.008), (x, y, 0.004), COLOUR)
    builder.enlarge(1.3)


def _snooker_cue_holder(builder):
    """Long wall rail standing on edge with four pairs of prongs that cues clip between."""
    builder.box((0.28, 0.014, 0.055), (0, 0.022, 0.0275), COLOUR, bevel=0.004)
    for x, _ in print_shapes.grid(4, 1, 0.066, 0):
        for side in (-1, 1):
            builder.box((0.01, 0.036, 0.022), (x + side * 0.014, -0.002, 0.032), COLOUR)


def _table_tennis_net_post(builder):
    """C clamp with a screw underneath and a tall post that the net slots into."""
    builder.box((0.03, 0.06, 0.012), (0, 0, 0.066), COLOUR)
    builder.box((0.03, 0.012, 0.06), (0, 0.024, 0.036), COLOUR)
    builder.box((0.03, 0.06, 0.012), (0, 0, 0.006), COLOUR)
    builder.cylinder(0.006, 0.03, (0, -0.012, 0.027), COLOUR, segments=6)
    builder.cylinder(0.014, 0.008, (0, -0.012, 0.04), COLOUR, segments=6)
    builder.box((0.014, 0.014, 0.13), (0, 0.024, 0.13), COLOUR)
    for side in (-1, 1):
        builder.box((0.004, 0.02, 0.05), (side * 0.007, 0.012, 0.16), COLOUR)


# Summer

def _fan_blade_replacement(builder):
    """Three broad fan blades round a hub, lying flat."""
    blade = [(0.02, -0.02), (0.1, -0.045), (0.135, -0.01), (0.12, 0.03), (0.02, 0.02)]
    for index in range(3):
        angle = math.pi / 2 + math.tau * index / 3
        turned = [(x * math.cos(angle) - y * math.sin(angle), x * math.sin(angle) + y * math.cos(angle)) for x, y in blade]
        builder.plate(turned, 0.008, COLOUR)
    builder.cylinder(0.032, 0.02, (0, 0, 0.01), COLOUR, segments=8)
    builder.cylinder(0.014, 0.012, (0, 0, 0.026), COLOUR, segments=6)


def _sun_visor_clip(builder):
    """Clip for the car's sun visor with a slot on the front for tickets and cards."""
    builder.box((0.07, 0.05, 0.006), (0, 0, 0.003), COLOUR)
    builder.box((0.07, 0.006, 0.022), (0, 0.022, 0.011), COLOUR)
    builder.box((0.07, 0.05, 0.006), (0, 0, 0.022), COLOUR)
    builder.box((0.05, 0.03, 0.004), (0, -0.006, 0.032), COLOUR)
    builder.box((0.05, 0.006, 0.01), (0, 0.012, 0.03), COLOUR)
    builder.enlarge(1.4)


def _sandcastle_mould_set(builder):
    """Three moulds: a round turret and a square tower, both with battlements, and a small cone."""
    builder.shell(0.05, 0.08, 0.006, COLOUR, segments=8, centre=(-0.08, 0.01, 0), radius_top=0.06)
    for index in range(4):
        angle = math.pi / 4 + index * math.pi / 2
        builder.box((0.022, 0.012, 0.016), (-0.08 + 0.054 * math.cos(angle), 0.01 + 0.054 * math.sin(angle), 0.087), COLOUR, rotation=(0, 0, angle + math.pi / 2))
    builder.tray((0.09, 0.09, 0.07), 0.006, COLOUR, centre=(0.05, 0.02, 0), taper=0.008)
    for x, y in print_shapes.grid(2, 2, 0.078, 0.078):
        builder.box((0.016, 0.016, 0.016), (0.05 + x, 0.02 + y, 0.077), COLOUR)
    builder.shell(0.012, 0.06, 0.005, COLOUR, segments=6, centre=(-0.005, -0.07, 0), radius_top=0.035)


def _drink_can_holder_tpu(builder):
    """Soft sleeve that a drinks can drops into."""
    builder.shell(0.042, 0.1, 0.006, COLOUR, segments=10, radius_top=0.045)


def _pool_float_valve_cover(builder):
    """Push-in valve plug with a wide cap, a tether strap and a ring at the end of it."""
    builder.cylinder(0.014, 0.004, (0, 0, 0.002), COLOUR, segments=8)
    builder.cylinder(0.007, 0.012, (0, 0, 0.01), COLOUR, segments=6)
    builder.box((0.005, 0.03, 0.003), (0, 0.026, 0.0015), COLOUR)
    builder.shell(0.01, 0.003, 0.004, COLOUR, segments=6, centre=(0, 0.048, 0), open_base=True)
    builder.enlarge(1.8)


def _picnic_cutlery_set(builder):
    """Stubby knife, fork and spoon side by side, joined by a band that keeps them together."""
    builder.plate([(-0.008, -0.05), (0.007, -0.05), (0.007, 0.05), (-0.002, 0.05), (-0.01, 0.0)], 0.005, COLOUR, centre=(-0.035, 0, 0))
    builder.box((0.014, 0.06, 0.005), (0, -0.02, 0.0025), COLOUR)
    builder.box((0.026, 0.016, 0.005), (0, 0.016, 0.0025), COLOUR)
    for x in (-0.01, 0.0, 0.01):
        builder.box((0.005, 0.03, 0.005), (x, 0.037, 0.0025), COLOUR)
    builder.box((0.014, 0.065, 0.005), (0.035, -0.018, 0.0025), COLOUR)
    builder.cylinder(0.018, 0.006, (0.035, 0.03, 0.003), COLOUR, segments=8)
    builder.box((0.095, 0.016, 0.01), (0, -0.03, 0.005), COLOUR)


def _garden_drink_holder_stake(builder):
    """Lawn stake lying flat: a ring that holds a glass at the head of a long tapering spike."""
    builder.shell(0.045, 0.014, 0.007, COLOUR, segments=8, centre=(0, 0.07, 0), turn=math.pi / 8, open_base=True)
    builder.plate([(-0.012, 0.032), (-0.002, -0.11), (0.002, -0.11), (0.012, 0.032)], 0.008, COLOUR)


def _frisbee(builder):
    """Flying disc lying rim up: a wide flat plate with a turned-up edge."""
    builder.shell(0.115, 0.022, 0.008, COLOUR, segments=12, radius_top=0.125, floor=0.006, chamfer=0.003)


def _paddling_pool_toy_boats_x3(builder):
    """Three chunky toy boats, each with a pointed bow, a cabin and a funnel."""
    hull = [(-0.022, -0.05), (0.022, -0.05), (0.026, 0.015), (0.0, 0.055), (-0.026, 0.015)]
    for x, _ in print_shapes.grid(3, 1, 0.07, 0):
        builder.plate(hull, 0.022, COLOUR, centre=(x, 0, 0))
        builder.box((0.03, 0.032, 0.02), (x, -0.012, 0.032), COLOUR)
        builder.cylinder(0.008, 0.02, (x, -0.02, 0.05), COLOUR, segments=6)


def _festival_phone_lanyard(builder):
    """Flat tab that sits inside a phone case, with a loop and the two ends of a neck strap leading away."""
    builder.plate([(-0.02, -0.03), (0.02, -0.03), (0.024, 0.0), (0.012, 0.014), (-0.012, 0.014), (-0.024, 0.0)], 0.003, COLOUR)
    builder.shell(0.01, 0.005, 0.004, COLOUR, segments=6, centre=(0, 0.02, 0), open_base=True)
    for side in (-1, 1):
        builder.box((0.006, 0.07, 0.003), (side * 0.016, 0.06, 0.0015), COLOUR, rotation=(0, 0, -side * 0.3))
    builder.enlarge(1.3)


VARIANTS = {
    "tent_peg_set_x8": _tent_peg_set_x8,
    "guy_line_tensioners_x8": _guy_line_tensioners_x8,
    "collapsible_cup": _collapsible_cup,
    "camping_cutlery_set": _camping_cutlery_set,
    "gas_canister_stand": _gas_canister_stand,
    "lantern_diffuser": _lantern_diffuser,
    "luggage_tag": _luggage_tag,
    "passport_cover": _passport_cover,
    "toiletry_travel_bottles_x3": _toiletry_travel_bottles_x3,
    "travel_soap_box": _travel_soap_box,
    "hiking_pole_tip_protectors_x2": _hiking_pole_tip_protectors_x2,
    "fishing_lure_set_x5": _fishing_lure_set_x5,
    "fishing_reel_spool_holder": _fishing_reel_spool_holder,
    "carabiner_light_duty": _carabiner_light_duty,
    "map_compass_housing": _map_compass_housing,
    "seed_starter_pots_x12": _seed_starter_pots_x12,
    "plant_labels_x20": _plant_labels_x20,
    "hose_connector": _hose_connector,
    "hose_guide_spike": _hose_guide_spike,
    "bird_feeder": _bird_feeder,
    "bug_hotel": _bug_hotel,
    "self_watering_planter": _self_watering_planter,
    "tomato_cage_clips_x20": _tomato_cage_clips_x20,
    "watering_spike_adapter_x4": _watering_spike_adapter_x4,
    "solar_light_stake_replacement": _solar_light_stake_replacement,
    "trellis_clips_x20": _trellis_clips_x20,
    "rain_gauge": _rain_gauge,
    "garden_kneeler_handle": _garden_kneeler_handle,
    "pond_fish_feeder_ring": _pond_fish_feeder_ring,
    "tennis_ball_holder": _tennis_ball_holder,
    "bike_helmet_hook": _bike_helmet_hook,
    "dumbbell_rack_clips_x4": _dumbbell_rack_clips_x4,
    "yoga_mat_holder": _yoga_mat_holder,
    "water_bottle_cap_sports": _water_bottle_cap_sports,
    "shin_guard_straps": _shin_guard_straps,
    "football_boot_tree_pair": _football_boot_tree_pair,
    "climbing_chalk_bowl": _climbing_chalk_bowl,
    "swim_goggles_case": _swim_goggles_case,
    "darts_flight_protectors_x9": _darts_flight_protectors_x9,
    "snooker_cue_holder": _snooker_cue_holder,
    "table_tennis_net_post": _table_tennis_net_post,
    "fan_blade_replacement": _fan_blade_replacement,
    "sun_visor_clip": _sun_visor_clip,
    "sandcastle_mould_set": _sandcastle_mould_set,
    "drink_can_holder_tpu": _drink_can_holder_tpu,
    "pool_float_valve_cover": _pool_float_valve_cover,
    "picnic_cutlery_set": _picnic_cutlery_set,
    "garden_drink_holder_stake": _garden_drink_holder_stake,
    "frisbee": _frisbee,
    "paddling_pool_toy_boats_x3": _paddling_pool_toy_boats_x3,
    "festival_phone_lanyard": _festival_phone_lanyard,
}

if __name__ == "__main__":
    common.run(sys.modules[__name__])
