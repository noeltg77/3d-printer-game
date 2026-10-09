"""Printed item generator for the Mechanical and maker parts category (Spare room tier).

Same rules as prints.py: tint material, origin at the centre of the base, a
little larger than life so items read at the game's camera distance.

blender --background --factory-startup --python tools/generators/prints_mechanical.py -- \
    --variant rack_and_pinion --out assets/models/prints/rack_and_pinion.glb
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


def _spur_gear_set_x5(builder):
    """Five flat gears of different sizes, laid out as they come off the bed."""
    for x, y, radius, teeth in ((-0.045, 0.03, 0.032, 9), (0.03, 0.03, 0.027, 8), (-0.07, -0.04, 0.018, 6),
                                (-0.018, -0.04, 0.022, 7), (0.04, -0.04, 0.018, 6)):
        print_shapes.gear(builder, teeth, radius, 0.01, (x, y, 0))


def _herringbone_gear_pair(builder):
    """Two thick gears in mesh, a large and a small, each with a raised hub."""
    print_shapes.gear(builder, 10, 0.055, 0.03, (-0.035, 0, 0), boss=0.018)
    print_shapes.gear(builder, 7, 0.038, 0.03, (0.055, 0, 0), turn=math.pi / 7, boss=0.014)


def _planetary_gearbox(builder):
    """Round housing holding a sun gear in the middle and three planets round it."""
    builder.shell(0.1, 0.035, 0.012, COLOUR, segments=12)
    print_shapes.gear(builder, 8, 0.03, 0.03, (0, 0, 0.008))
    for index in range(3):
        angle = math.pi / 2 + math.tau * index / 3
        print_shapes.gear(builder, 5, 0.024, 0.03, (0.058 * math.cos(angle), 0.058 * math.sin(angle), 0.008))


def _worm_gear_and_wheel(builder):
    """Toothed wheel lying on a base, with a threaded worm running past it between two bearing blocks."""
    builder.box((0.17, 0.12, 0.01), (0, 0, 0.005), COLOUR)
    print_shapes.gear(builder, 10, 0.05, 0.022, (-0.01, -0.012, 0.008), boss=0.015)
    builder.cylinder(0.013, 0.15, (0, 0.045, 0.03), COLOUR, segments=8, axis="X")
    for x in (-0.035, 0.0, 0.035):
        builder.cylinder(0.02, 0.009, (x - 0.01, 0.045, 0.03), COLOUR, segments=6, axis="X")
    for side in (-1, 1):
        builder.box((0.012, 0.03, 0.04), (side * 0.074, 0.045, 0.028), COLOUR)


def _bevel_gear_pair(builder):
    """Two cone gears meeting at a right angle: one flat on the base, one on an upright plate."""
    builder.box((0.13, 0.11, 0.008), (0, 0, 0.004), COLOUR)
    print_shapes.gear(builder, 10, 0.052, 0.008, (0, -0.012, 0.006))
    builder.cylinder(0.046, 0.02, (0, -0.012, 0.024), COLOUR, segments=10, radius_top=0.03)
    builder.cylinder(0.014, 0.012, (0, -0.012, 0.04), COLOUR, segments=6)
    builder.box((0.07, 0.01, 0.1), (0, 0.05, 0.05), COLOUR)
    builder.cylinder(0.04, 0.02, (0, 0.036, 0.062), COLOUR, segments=10, axis="Y", radius_top=0.026)


def _rack_and_pinion(builder):
    """Straight toothed rack with a round pinion in mesh beside it."""
    teeth, pitch = 9, 0.22 / 9
    rack = [(-0.11, -0.012), (0.11, -0.012), (0.11, 0.0)]
    for index in range(teeth):
        right = 0.11 - index * pitch
        rack += [(right - pitch / 2, 0.012), (right - pitch, 0.0)]
    builder.plate(rack, 0.012, COLOUR, centre=(0, -0.03, 0))
    print_shapes.gear(builder, 8, 0.032, 0.012, (0, 0.008, 0), turn=math.pi / 8, boss=0.012)


def _pulley_gt2_x4(builder):
    """Four small belt pulleys: a toothed barrel between two flanges."""
    for x, y in print_shapes.grid(2, 2, 0.045, 0.045):
        builder.cylinder(0.016, 0.004, (x, y, 0.002), COLOUR, segments=6)
        builder.cylinder(0.011, 0.014, (x, y, 0.011), COLOUR, segments=6)
        builder.cylinder(0.016, 0.004, (x, y, 0.02), COLOUR, segments=6)


def _bearing_housing_608(builder):
    """Square flange with a raised ring that a bearing presses into and a bolt at each corner."""
    builder.box((0.08, 0.08, 0.008), (0, 0, 0.004), COLOUR)
    builder.shell(0.032, 0.024, 0.008, COLOUR, segments=8, centre=(0, 0, 0.006), open_base=True)
    for x, y in print_shapes.grid(2, 2, 0.058, 0.058):
        builder.box((0.01, 0.01, 0.006), (x, y, 0.011), COLOUR)


def _pillow_block_bearing_mount(builder):
    """Upright ring for a shaft on a bolted foot."""
    builder.box((0.11, 0.032, 0.012), (0, 0, 0.006), COLOUR)
    builder.box((0.04, 0.03, 0.02), (0, 0, 0.02), COLOUR)
    print_shapes.hoop(builder, 0.026, 0.012, 0.03, (0, 0, 0.056))
    for side in (-1, 1):
        builder.box((0.012, 0.012, 0.006), (side * 0.042, 0, 0.015), COLOUR)


def _shaft_coupler_x4(builder):
    """Four short couplers, each a round sleeve with a clamp screw boss on the side."""
    for x, y in print_shapes.grid(2, 2, 0.045, 0.04):
        builder.cylinder(0.013, 0.03, (x, y, 0.015), COLOUR, segments=8)
        builder.box((0.01, 0.01, 0.012), (x + 0.014, y, 0.015), COLOUR)


def _motor_mount_nema_17(builder):
    """L bracket: a base plate, an upright square frame for the motor face and two gussets."""
    builder.box((0.075, 0.07, 0.008), (0, 0, 0.004), COLOUR)
    for z in (0.014, 0.074):
        builder.box((0.075, 0.008, 0.012), (0, 0.03, z), COLOUR)
    for side in (-1, 1):
        builder.box((0.012, 0.008, 0.07), (side * 0.0315, 0.03, 0.043), COLOUR)
        print_shapes.strut(builder, (side * 0.0315, 0.026, 0.07), (side * 0.0315, -0.028, 0.01), 0.008)


def _servo_bracket_set(builder):
    """Three U brackets in a row, each a base with an ear front and back."""
    for x, _ in print_shapes.grid(3, 1, 0.045, 0):
        builder.box((0.034, 0.05, 0.006), (x, 0, 0.003), COLOUR)
        for side in (-1, 1):
            builder.box((0.034, 0.006, 0.03), (x, side * 0.022, 0.015), COLOUR)


def _linear_rail_end_stops_x4(builder):
    """Four small blocks, each with a round bumper on the front."""
    for x, y in print_shapes.grid(2, 2, 0.04, 0.045):
        builder.box((0.026, 0.02, 0.02), (x, y, 0.01), COLOUR)
        builder.cylinder(0.006, 0.008, (x, y - 0.013, 0.012), COLOUR, segments=6, axis="Y")


def _electronics_enclosure_small(builder):
    """Open project box with a screw post in each corner, and its lid lying in front."""
    builder.tray((0.12, 0.08, 0.05), 0.006, COLOUR, centre=(0, 0.047, 0), chamfer=0.004)
    for x, y in print_shapes.grid(2, 2, 0.096, 0.056):
        builder.box((0.01, 0.01, 0.044), (x, y + 0.047, 0.025), COLOUR)
    builder.tray((0.12, 0.08, 0.012), 0.006, COLOUR, centre=(0, -0.047, 0))


def _electronics_enclosure_large(builder):
    """Big closed box with an overhanging lid, a mounting ear at each corner and a cable gland."""
    builder.box((0.24, 0.16, 0.07), (0, 0, 0.035), COLOUR, bevel=0.006)
    builder.box((0.25, 0.17, 0.02), (0, 0, 0.078), COLOUR, bevel=0.005)
    for x, y in print_shapes.grid(2, 2, 0.266, 0.1):
        builder.box((0.03, 0.03, 0.008), (x, y, 0.004), COLOUR)
    builder.cylinder(0.014, 0.02, (0.06, -0.088, 0.035), COLOUR, segments=6, axis="Y")


def _din_rail_clips_x10(builder):
    """Ten rail clips in two rows, each a flat body with a hooked end."""
    for x, y in print_shapes.grid(5, 2, 0.03, 0.05):
        builder.box((0.02, 0.036, 0.012), (x, y, 0.006), COLOUR)
        builder.box((0.02, 0.008, 0.022), (x, y + 0.014, 0.011), COLOUR)


def _arduino_mounting_plate(builder):
    """Flat plate with four stand-offs for a board and a fixing tab at each end."""
    builder.box((0.11, 0.08, 0.006), (0, 0, 0.003), COLOUR)
    for x, y in print_shapes.grid(2, 2, 0.086, 0.056):
        builder.cylinder(0.006, 0.012, (x, y, 0.012), COLOUR, segments=6)
    for side in (-1, 1):
        builder.box((0.018, 0.018, 0.006), (side * 0.063, 0, 0.003), COLOUR)


def _cable_chain_links_x20(builder):
    """Twenty chain links joined in a run that goes out, round a bend and back."""
    spots = [(-0.07 + index * 0.017, -0.04, 0.0) for index in range(9)]
    for index in range(5):
        angle = -math.pi / 2 + (index + 0.5) * math.pi / 5
        spots.append((0.07 + 0.04 * math.cos(angle), 0.04 * math.sin(angle), angle + math.pi / 2))
    spots += [(0.066 - index * 0.017, 0.04, 0.0) for index in range(6)]
    for x, y, turn in spots:
        builder.box((0.015, 0.024, 0.014), (x, y, 0.007), COLOUR, rotation=(0, 0, turn))


def _hinge_set_print_in_place_x4(builder):
    """Four hinges lying open: two leaves joined along a round barrel."""
    for x, y in print_shapes.grid(2, 2, 0.075, 0.055):
        for side in (-1, 1):
            builder.box((0.028, 0.04, 0.005), (x + side * 0.016, y, 0.0025), COLOUR)
        builder.cylinder(0.006, 0.04, (x, y, 0.006), COLOUR, segments=6, axis="Y")


def _snap_fit_enclosure_clips(builder):
    """Eight little snap clips in two rows, each a tongue with a wedge-shaped catch."""
    for x, y in print_shapes.grid(4, 2, 0.03, 0.045):
        builder.box((0.018, 0.032, 0.006), (x, y, 0.003), COLOUR)
        builder.box((0.018, 0.008, 0.014), (x, y - 0.012, 0.007), COLOUR, taper=(1.0, 0.4))


def _spacers_and_standoffs_x50(builder):
    """A bed of stand-offs in three heights. Twenty-five are modelled to stand for the fifty."""
    for index, (x, y) in enumerate(print_shapes.grid(5, 5, 0.022, 0.022)):
        height = (0.01, 0.018, 0.026)[index % 3]
        builder.box((0.012, 0.012, height), (x, y, height / 2), COLOUR)


def _custom_bracket_b2b(builder):
    """Right-angle bracket: a base, an upright, two wedge gussets and bolt bosses."""
    builder.box((0.1, 0.055, 0.008), (0, -0.005, 0.004), COLOUR)
    builder.box((0.1, 0.008, 0.075), (0, 0.0235, 0.0375), COLOUR)
    for side in (-1, 1):
        builder.box((0.008, 0.045, 0.06), (side * 0.046, -0.002, 0.036), COLOUR, taper=(1.0, 0.12))
        builder.box((0.012, 0.012, 0.005), (side * 0.022, -0.012, 0.0105), COLOUR)


def _jig_and_fixture_plate(builder):
    """Large plate with a grid of locating pegs and a fence along two edges."""
    builder.box((0.28, 0.2, 0.012), (0, 0, 0.006), COLOUR, bevel=0.004)
    for x, y in print_shapes.grid(3, 3, 0.07, 0.05):
        builder.box((0.014, 0.014, 0.014), (x + 0.02, y - 0.01, 0.018), COLOUR)
    builder.box((0.27, 0.012, 0.022), (0, 0.089, 0.022), COLOUR)
    builder.box((0.012, 0.17, 0.022), (-0.129, -0.005, 0.022), COLOUR)


def _drill_guide_jig(builder):
    """Block with three upright guide bushes in a row and a lip to hook over the work."""
    builder.box((0.1, 0.045, 0.03), (0, 0, 0.015), COLOUR, bevel=0.004)
    for x, radius in ((-0.03, 0.009), (0.0, 0.011), (0.032, 0.013)):
        builder.shell(radius, 0.012, 0.004, COLOUR, segments=6, centre=(x, 0, 0.028), floor=0.002)
    builder.box((0.1, 0.008, 0.02), (0, -0.0265, 0.01), COLOUR)


def _fan_duct(builder):
    """Square flange with a duct that sweeps forward and narrows to a nozzle."""
    builder.box((0.055, 0.055, 0.008), (0, 0.02, 0.004), COLOUR)
    print_shapes.limb(builder, (0, 0.02, 0.019), (0, -0.005, 0.046), 0.024, 0.018)
    print_shapes.limb(builder, (0, -0.003, 0.044), (0, -0.045, 0.056), 0.018, 0.01)


def _fan_shroud_120mm(builder):
    """Upright square frame round a ring, with a hub held on three spokes."""
    for z in (0.006, 0.154):
        builder.box((0.16, 0.03, 0.012), (0, 0, z), COLOUR)
    for side in (-1, 1):
        builder.box((0.012, 0.03, 0.16), (side * 0.074, 0, 0.08), COLOUR)
    print_shapes.hoop(builder, 0.062, 0.008, 0.03, (0, 0, 0.08))
    builder.cylinder(0.018, 0.02, (0, 0, 0.08), COLOUR, segments=6, axis="Y")
    for index in range(3):
        angle = math.pi / 2 + math.tau * index / 3
        print_shapes.strut(builder, (0, 0, 0.08), (0.062 * math.cos(angle), 0, 0.08 + 0.062 * math.sin(angle)), 0.007)


def _hose_barb_adapters_x6(builder):
    """Six small hose adapters standing on end: a hex nut with a tapered barb."""
    for x, y in print_shapes.grid(3, 2, 0.04, 0.04):
        builder.cylinder(0.014, 0.008, (x, y, 0.004), COLOUR, segments=6)
        builder.cylinder(0.009, 0.03, (x, y, 0.023), COLOUR, segments=6, radius_top=0.006)


def _pipe_clamps_x6(builder):
    """Six saddle clamps in two rows: a hump for the pipe with a screw foot each side."""
    for x, y in print_shapes.grid(3, 2, 0.062, 0.045):
        builder.box((0.05, 0.02, 0.005), (x, y, 0.0025), COLOUR)
        builder.box((0.028, 0.02, 0.022), (x, y, 0.011), COLOUR, taper=(0.6, 1.0))


def _tube_connector_t_piece_x4(builder):
    """Four T-shaped tube connectors lying flat."""
    for x, y in print_shapes.grid(2, 2, 0.07, 0.055):
        builder.box((0.055, 0.016, 0.016), (x, y + 0.008, 0.008), COLOUR)
        builder.box((0.016, 0.03, 0.016), (x, y - 0.012, 0.008), COLOUR)


def _caster_wheel(builder):
    """Wheel in a fork under a swivel plate."""
    builder.cylinder(0.035, 0.024, (0, 0, 0.0333), COLOUR, segments=10, axis="X")
    for side in (-1, 1):
        builder.box((0.006, 0.03, 0.055), (side * 0.017, 0, 0.056), COLOUR)
    builder.box((0.046, 0.04, 0.008), (0, 0, 0.086), COLOUR)
    builder.cylinder(0.012, 0.012, (0, 0, 0.096), COLOUR, segments=6)
    builder.box((0.065, 0.065, 0.006), (0, 0, 0.105), COLOUR)


def _robot_chassis(builder):
    """Flat deck on four wheels with a smaller top deck raised on posts."""
    builder.box((0.2, 0.15, 0.012), (0, 0, 0.042), COLOUR, bevel=0.004)
    for x, y in print_shapes.grid(2, 2, 0.228, 0.1):
        builder.cylinder(0.035, 0.024, (x, y, 0.035), COLOUR, segments=8, axis="X")
    for x, y in print_shapes.grid(2, 2, 0.12, 0.09):
        builder.box((0.01, 0.01, 0.04), (x, y, 0.066), COLOUR)
    builder.box((0.15, 0.12, 0.008), (0, 0, 0.09), COLOUR)


def _robot_arm_kit(builder):
    """Jointed arm on a round turntable: shoulder, upper arm, elbow, forearm and a two-finger gripper."""
    builder.cylinder(0.075, 0.02, (0, 0, 0.01), COLOUR, segments=12, radius_top=0.065)
    builder.box((0.06, 0.06, 0.05), (0, 0, 0.045), COLOUR)
    print_shapes.strut(builder, (0, 0, 0.06), (0.05, 0, 0.19), 0.03)
    builder.cylinder(0.024, 0.045, (0.05, 0, 0.19), COLOUR, segments=6, axis="Y")
    print_shapes.strut(builder, (0.05, 0, 0.19), (0.15, 0, 0.23), 0.024)
    builder.box((0.02, 0.05, 0.03), (0.158, 0, 0.233), COLOUR)
    for side in (-1, 1):
        print_shapes.strut(builder, (0.16, side * 0.02, 0.233), (0.2, side * 0.012, 0.22), 0.01)


def _drone_frame(builder):
    """X frame lying flat: a centre plate, four arms and a round motor mount on each."""
    builder.box((0.075, 0.075, 0.01), (0, 0, 0.005), COLOUR)
    for index in range(4):
        angle = math.pi / 4 + index * math.pi / 2
        reach = (math.cos(angle), math.sin(angle))
        builder.box((0.11, 0.018, 0.008), (0.08 * reach[0], 0.08 * reach[1], 0.004), COLOUR, rotation=(0, 0, angle))
        builder.cylinder(0.022, 0.012, (0.135 * reach[0], 0.135 * reach[1], 0.006), COLOUR, segments=8)


def _wind_turbine_blades(builder):
    """Three tapering blades round a hub with a nose cone, lying flat."""
    blade = [(0.015, -0.014), (0.14, -0.006), (0.14, 0.004), (0.015, 0.022)]
    for index in range(3):
        angle = math.pi / 2 + math.tau * index / 3
        turned = [(x * math.cos(angle) - y * math.sin(angle), x * math.sin(angle) + y * math.cos(angle)) for x, y in blade]
        builder.plate(turned, 0.008, COLOUR)
    builder.cylinder(0.028, 0.016, (0, 0, 0.008), COLOUR, segments=8)
    builder.cylinder(0.022, 0.02, (0, 0, 0.026), COLOUR, segments=8, radius_top=0.004)


def _gear_reduction_box(builder):
    """Open-topped gear case with a large and a small gear in mesh, each on its own shaft."""
    builder.tray((0.22, 0.13, 0.06), 0.008, COLOUR, chamfer=0.004)
    print_shapes.gear(builder, 9, 0.048, 0.022, (-0.045, 0, 0.006))
    print_shapes.gear(builder, 6, 0.028, 0.022, (0.035, 0, 0.006), turn=math.pi / 6)
    builder.cylinder(0.012, 0.07, (-0.045, 0, 0.04), COLOUR, segments=6)
    builder.cylinder(0.009, 0.07, (0.035, 0, 0.04), COLOUR, segments=6)


def _hard_wearing_bushing_x10(builder):
    """Ten short bushes in two rows, each a stubby sleeve that is wider at the foot."""
    for x, y in print_shapes.grid(5, 2, 0.032, 0.034):
        builder.cylinder(0.014, 0.018, (x, y, 0.009), COLOUR, segments=6, radius_top=0.01)


def _carbon_tool_holder(builder):
    """Wall plate with a row of prongs sticking out, leaving five slots to hang tools in."""
    builder.box((0.2, 0.012, 0.09), (0, 0.03, 0.045), COLOUR, bevel=0.004)
    for x, _ in print_shapes.grid(6, 1, 0.037, 0):
        builder.box((0.012, 0.055, 0.012), (x, 0.0, 0.06), COLOUR)
        builder.box((0.012, 0.01, 0.022), (x, -0.0225, 0.065), COLOUR)


def _rigid_camera_rig_plate(builder):
    """Long flat plate with two rows of mounting bosses and a rod clamp block at each end."""
    builder.box((0.2, 0.09, 0.01), (0, 0, 0.005), COLOUR, bevel=0.003)
    for x, y in print_shapes.grid(5, 2, 0.03, 0.04):
        builder.box((0.012, 0.012, 0.004), (x, y, 0.012), COLOUR)
    for side in (-1, 1):
        builder.box((0.022, 0.09, 0.028), (side * 0.089, 0, 0.014), COLOUR)


def _small_run_injection_mould_insert(builder):
    """Thick mould block with a shallow cavity, a raised core in it and an alignment pin at each corner."""
    builder.tray((0.15, 0.11, 0.04), 0.022, COLOUR, floor=0.026, chamfer=0.004)
    builder.box((0.06, 0.035, 0.008), (0, 0, 0.03), COLOUR, taper=(0.8, 0.7))
    for x, y in print_shapes.grid(2, 2, 0.126, 0.086):
        builder.cylinder(0.007, 0.01, (x, y, 0.044), COLOUR, segments=6)


VARIANTS = {
    "spur_gear_set_x5": _spur_gear_set_x5,
    "herringbone_gear_pair": _herringbone_gear_pair,
    "planetary_gearbox": _planetary_gearbox,
    "worm_gear_and_wheel": _worm_gear_and_wheel,
    "bevel_gear_pair": _bevel_gear_pair,
    "rack_and_pinion": _rack_and_pinion,
    "pulley_gt2_x4": _pulley_gt2_x4,
    "bearing_housing_608": _bearing_housing_608,
    "pillow_block_bearing_mount": _pillow_block_bearing_mount,
    "shaft_coupler_x4": _shaft_coupler_x4,
    "motor_mount_nema_17": _motor_mount_nema_17,
    "servo_bracket_set": _servo_bracket_set,
    "linear_rail_end_stops_x4": _linear_rail_end_stops_x4,
    "electronics_enclosure_small": _electronics_enclosure_small,
    "electronics_enclosure_large": _electronics_enclosure_large,
    "din_rail_clips_x10": _din_rail_clips_x10,
    "arduino_mounting_plate": _arduino_mounting_plate,
    "cable_chain_links_x20": _cable_chain_links_x20,
    "hinge_set_print_in_place_x4": _hinge_set_print_in_place_x4,
    "snap_fit_enclosure_clips": _snap_fit_enclosure_clips,
    "spacers_and_standoffs_x50": _spacers_and_standoffs_x50,
    "custom_bracket_b2b": _custom_bracket_b2b,
    "jig_and_fixture_plate": _jig_and_fixture_plate,
    "drill_guide_jig": _drill_guide_jig,
    "fan_duct": _fan_duct,
    "fan_shroud_120mm": _fan_shroud_120mm,
    "hose_barb_adapters_x6": _hose_barb_adapters_x6,
    "pipe_clamps_x6": _pipe_clamps_x6,
    "tube_connector_t_piece_x4": _tube_connector_t_piece_x4,
    "caster_wheel": _caster_wheel,
    "robot_chassis": _robot_chassis,
    "robot_arm_kit": _robot_arm_kit,
    "drone_frame": _drone_frame,
    "wind_turbine_blades": _wind_turbine_blades,
    "gear_reduction_box": _gear_reduction_box,
    "hard_wearing_bushing_x10": _hard_wearing_bushing_x10,
    "carbon_tool_holder": _carbon_tool_holder,
    "rigid_camera_rig_plate": _rigid_camera_rig_plate,
    "small_run_injection_mould_insert": _small_run_injection_mould_insert,
}

if __name__ == "__main__":
    common.run(sys.modules[__name__])
