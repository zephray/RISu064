from siliconcompiler.core import Chip
from siliconcompiler.floorplan import Floorplan
from importpins import import_pins_from_lef, load_lef

import math

# Fixed user wrapper size 2.92mm x 3.52mm
TOP_W = 2920
TOP_H = 3520
MARGIN_W = 15
MARGIN_H = 15

ANALOG_Y = 2900

RAM_8_1024 = "sky130_sram_1kbyte_1rw1r_8x1024_8"
RAM_24_128 = "sky130_sram_1r1w_24x128"
RAM_32_256 = "sky130_sram_1kbyte_1rw1r_32x256_8"
RAM_32_512 = "sky130_sram_2kbyte_1rw1r_32x512_8"
RAM_46_128 = "sky130_sram_1r1w_46x128"
RAM_64_512 = "sky130_sram_4kbyte_1r1w_64x512"

def configure_chip(design):
    chip = Chip(design)
    chip.load_target("skywater130_demo")

    chip.set("option", "showtool", "def", "klayout")
    chip.set("option", "showtool", "gds", "klayout")

    return chip

def load_lib(chip):
    chip.load_lib("sky130sram_8_1024")
    chip.load_lib("sky130sram_32_256")
    chip.load_lib("sky130sram_32_512")
    chip.load_lib("analog_area")
    chip.add("asic", "macrolib", "sky130sram_8_1024")
    chip.add("asic", "macrolib", "sky130sram_32_256")
    chip.add("asic", "macrolib", "sky130sram_32_512")
    chip.add("asic", "macrolib", "analog_area")

def define_dimensions(fp):
    margin_left = snap_x(fp, MARGIN_W, 1)
    margin_bottom = snap_y(fp, MARGIN_H, 1)
    #margin_left = 0
    #margin_bottom = 0
    core_w = TOP_W
    core_h = TOP_H
    place_w = snap_x(fp, core_w - MARGIN_W * 2, 0)
    place_h = snap_y(fp, core_h - MARGIN_H * 2, 0)
    #place_w = TOP_W
    #place_h = TOP_H

    return (core_w, core_h), (place_w, place_h), (margin_left, margin_bottom)

def core_setup_area(fp, chip):
    dims = define_dimensions(fp)
    (core_w, core_h), (place_w, place_h), (margin_left, margin_bottom) = dims
    chip.set("asic", "diearea", (0, 0))
    chip.add("asic", "diearea", (core_w, core_h))
    chip.set("asic", "corearea", (margin_left, margin_bottom))
    chip.add("asic", "corearea", (place_w + margin_left, place_h + margin_bottom))

def snap_x(fp, val, adj):
    return (round(val / fp.stdcell_width) + adj) * fp.stdcell_width

def snap_y(fp, val, adj):
    return (round(val / fp.stdcell_height) + adj) * fp.stdcell_height

def place_ram(fp, inst_name, macro_name, x, y, orientation, cut_left = False, cut_right = False):
    dims = define_dimensions(fp)
    _, _, (margin_left, margin_bottom) = dims

    ## Place RAM macro ##
    ram_w = fp.available_cells[macro_name].width
    ram_h = fp.available_cells[macro_name].height
    print("Macro", macro_name, "W", ram_w, "H", ram_h)
    ram_x = x * fp.stdcell_width + margin_left
    # Add hand-calculated fudge factor to align left-side pins with routing tracks.
    ram_y = y * fp.stdcell_height + margin_bottom + 0.53

    fp.place_macros([(inst_name, macro_name)], ram_x, ram_y, 0, 0, orientation, snap=False)

    ram_halo_w = 40
    ram_halo_h = 20
    halo_x = snap_x(fp, ram_x - ram_halo_w, -1)
    halo_y = snap_y(fp, ram_y - ram_halo_h, -1)
    halo_w = snap_x(fp, ram_x + ram_w + ram_halo_w, 0) - halo_x
    halo_h = snap_y(fp, ram_y + ram_h + ram_halo_h, 0) - halo_y
    fp.place_blockage(halo_x, halo_y, halo_w, halo_h, layer="li1")

    ram_margin_x = 100 * fp.stdcell_width
    ram_margin_y = 20 * fp.stdcell_height
    blockage_x = ram_x - ram_margin_x
    blockage_y = ram_y - ram_margin_y
    blockage_w = ram_w + ram_margin_x * 2
    blockage_h = ram_h + ram_margin_y * 2

    fp.place_blockage(blockage_x, blockage_y, blockage_w, blockage_h)

    if cut_right or cut_left:
        for row in fp.rows:
            if (row["y"] > (halo_y - 0.001)) and (row["y"] < (halo_y + halo_h + 0.001)):
                if cut_right:
                    row["numx"] = round(halo_x / row["stepx"])
                if cut_left:
                    oldx = row["x"]
                    row["x"] = halo_x + halo_w
                    diffx = row["x"] - oldx
                    row["numx"] = row["numx"] - round(diffx / row["stepx"])
def place_pin(fp, name, x, y, w, h, layer, use = "SIGNAL", fixed = False, drawing = False):
    fp.place_pins([name], x, y, 0, 0, w, h, layer,
            use = use,
            fixed = fixed,
            add_port = False)
    if drawing:
        fp.add_net(name, [name], use)
        fp.place_wires([name], x, y, 0, 0, w, h, layer)

def place_blockage_all_layers(fp, x, y, w, h):
    fp.place_blockage(x, y, w, h, layer="li1")
    fp.place_blockage(x, y, w, h, layer="met1")
    fp.place_blockage(x, y, w, h, layer="met2")
    fp.place_blockage(x, y, w, h, layer="met3")
    fp.place_blockage(x, y, w, h, layer="met4")
    fp.place_blockage(x, y, w, h, layer="met5")

def pin_fitler(pin):
    return (not "vcc" in pin) and (not "vdd" in pin) and (not "vss" in pin) and (not pin.startswith("io_analog"))

def core_floorplan(fp):
    ## Set up die area ##
    dims = define_dimensions(fp)
    (core_w, core_h), (place_w, place_h), (margin_left, margin_bottom) = dims
    diearea = [(0, 0), (core_w, core_h)]
    corearea = [(margin_left, margin_bottom), (place_w + margin_left, place_h + margin_bottom)]
    fp.create_diearea(diearea, corearea=corearea)

    # Don"t use user_analog_project_wrapper.def, it"s broken as of MPW-7
    #import_pins_from_def(fp, "user_analog_project_wrapper.def")
    #import_pins_from_lef(fp, "user_analog_project_wrapper_empty.lef")
    pins = load_lef("user_analog_project_wrapper_empty.lef")
    for pin in pins:
        place_pin(fp, pin["name"], pin["x"] / 1000, pin["y"] / 1000,
                pin["w"] / 1000, pin["h"] / 1000, pin["layer"], pin["use"],
                fixed = False, drawing = not pin_fitler(pin["name"]))

    # not gonna to calculate, just going to place wherever I like
    place_ram(fp, "asictop.risu.l1d.cache_ram\[0\].cache_data.hi_mem", RAM_32_512, 4570, 220, "N", cut_right = True)
    place_ram(fp, "asictop.risu.l1d.cache_ram\[0\].cache_data.lo_mem", RAM_32_512, 4570, 440, "N", cut_right = True)
    place_ram(fp, "asictop.risu.l1d.cache_ram\[1\].cache_data.hi_mem", RAM_32_512, 4570, 660, "N", cut_right = True)
    place_ram(fp, "asictop.risu.l1d.cache_ram\[1\].cache_data.lo_mem", RAM_32_512, 4570, 880, "N", cut_right = True)

    place_ram(fp, "asictop.risu.l1i.cache_ram\[0\].cache_data.hi_mem", RAM_32_512, 2910, 220, "N")
    place_ram(fp, "asictop.risu.l1i.cache_ram\[0\].cache_data.lo_mem", RAM_32_512, 2910, 440, "N")
    place_ram(fp, "asictop.risu.l1i.cache_ram\[1\].cache_data.hi_mem", RAM_32_512, 2910, 660, "N")
    place_ram(fp, "asictop.risu.l1i.cache_ram\[1\].cache_data.lo_mem", RAM_32_512, 2910, 880, "N")

    place_ram(fp, "asictop.risu.l1d.cache_ram\[0\].cache_meta.mem", RAM_32_256, 3940, 20, "N")
    place_ram(fp, "asictop.risu.l1d.cache_ram\[1\].cache_meta.mem", RAM_32_256, 5150, 20, "N", cut_right = True)

    place_ram(fp, "asictop.risu.l1i.cache_ram\[0\].cache_meta.mem", RAM_32_256, 1520, 20, "N")
    place_ram(fp, "asictop.risu.l1i.cache_ram\[1\].cache_meta.mem", RAM_32_256, 2730, 20, "N")

    place_ram(fp, "asictop.risu.cpu.ifp.bp.bpu_ram.mem", RAM_8_1024, 260, 540, "N", cut_left = True)

    # Allow routing in right most 100 microns
    place_blockage_all_layers(fp, 0, ANALOG_Y, TOP_W - 100, TOP_H - ANALOG_Y)
    place_blockage_all_layers(fp, TOP_W - 100, 3000, 100, TOP_H - 3000)
    fp.place_blockage(TOP_W - 100, ANALOG_Y, 100, 3000 - ANALOG_Y, layer="met4")
    fp.place_blockage(TOP_W - 100, ANALOG_Y, 100, 3000 - ANALOG_Y, layer="met5")
    fp.place_blockage(TOP_W - 100, ANALOG_Y, 100, 100, layer="met3")

    # Place analog area as an macro
    #fp.place_macros([("analog_area", "analog_area")], 0, 0, 0, 0, "N", snap=False)
    fp.place_macros([("analog_area", "analog_area")], 0, ANALOG_Y, 0, 0, "N", snap=False)

    # Manually connect power supplies
    fp.add_net("vccd1", ["vccd1"], "power")
    fp.add_net("vssd1", ["vssd1"], "ground")
    fp.add_net("vccd2", ["vccd2"], "power")
    fp.add_net("vssd2", ["vssd2"], "ground")
    fp.add_net("vdda1", ["vdda1"], "power")
    fp.add_net("vssa1", ["vssa1"], "ground")
    fp.add_net("vdda2", ["vdda2"], "power")
    fp.add_net("vssa2", ["vssa2"], "ground")
    
    # VSSD1
    # VSSD1 pin
    fp.place_wires(["vssd1"], 2911.7, 981.15, 0, 0, 8.3, 24, layer="met3", snap=False)
    fp.place_wires(["vssd1"], 2911.7, 931.15, 0, 0, 8.3, 26, layer="met3", snap=False)
    fp.place_wires(["vssd1"], 2911.7, 883.15, 0, 0, 8.3, 24, layer="met3", snap=False)
    fp.place_wires(["vssd1"], 2913.52, 883.15, 0, 0, 3.1, 122, layer="met4", snap=False)
    # VCCD1
    fp.place_wires(["vccd1"], 2911.7, 3198.92, 0, 0, 8.3, 24, layer="met3", snap=False)
    fp.place_wires(["vccd1"], 2911.7, 3148.92, 0, 0, 8.3, 24, layer="met3", snap=False)
    fp.place_wires(["vccd1"], 2904.09, 2904, 0, 0, 15.91, 318.92, layer="met4", snap=False)
    fp.place_wires(["vccd1"], 2904.09, 2880, 0, 0, 7.73, 24, layer="met4", snap=False)
    # VSSA1
    fp.place_wires(["vssa1"], 2862.29, 684.15, 0, 0, 49.41, 24, layer="met3", snap=False)
    fp.place_wires(["vssa1"], 2862.29, 734.15, 0, 0, 49.41, 24, layer="met3", snap=False)
    fp.place_wires(["vssa1"], 2862.29, 684.15, 0, 0, 38.5, 2219.85, layer="met4", snap=False)
    # VDDA1
    fp.place_wires(["vdda1"], 2820.49, 1126.15, 0, 0, 91.21, 24, layer="met3", snap=False)
    fp.place_wires(["vdda1"], 2820.49, 1176.15, 0, 0, 91.21, 24, layer="met3", snap=False)
    fp.place_wires(["vdda1"], 2820.49, 2702.81, 0, 0, 91.21, 24, layer="met3", snap=False)
    fp.place_wires(["vdda1"], 2820.49, 2752.81, 0, 0, 91.21, 24, layer="met3", snap=False)
    fp.place_wires(["vdda1"], 2820.49, 1126.15, 0, 0, 38.5, 1777.85, layer="met4", snap=False)
    # VSSD2
    fp.place_wires(["vssd2"], 8.3, 814.44, 0, 0, 60.69, 24, layer="met3", snap=False)
    fp.place_wires(["vssd2"], 8.3, 864.44, 0, 0, 60.69, 24, layer="met3", snap=False)
    fp.place_wires(["vssd2"], 30.49, 814.44, 0, 0, 38.5, 2089.56, layer="met4", snap=False)
    # VDDA2
    fp.place_wires(["vdda2"], 8.3, 1024.44, 0, 0, 102.49, 24, layer="met3", snap=False)
    fp.place_wires(["vdda2"], 8.3, 1074.44, 0, 0, 102.49, 24, layer="met3", snap=False)
    fp.place_wires(["vdda2"], 72.29, 1024.44, 0, 0, 38.5, 1879.56, layer="met4", snap=False)
    # VSSA2
    fp.place_wires(["vssa2"], 8.3, 2747.21, 0, 0, 150.69, 24, layer="met3", snap=False)
    fp.place_wires(["vssa2"], 8.3, 2797.21, 0, 0, 150.69, 24, layer="met3", snap=False)
    fp.place_wires(["vssa2"], 120.49, 2747.21, 0, 0, 38.5, 156.79, layer="met4", snap=False)

    fp.insert_vias(nets=["vssd1", "vccd1", "vdda1", "vssa1", "vdda2", "vssa2", "vssd2"])

def generate_core_floorplan(chip):
    fp = Floorplan(chip)
    core_floorplan(fp)
    fp.write_def("user_analog_project_wrapper_with_sram.def")
    fp.write_lef("user_analog_project_wrapper_with_sram.lef")
    chip.set("input", "floorplan.def", "user_analog_project_wrapper_with_sram.def")
    stackup = chip.get("asic", "stackup")
    chip.set("model", "layout", "lef", stackup, "user_analog_project_wrapper_with_sram.lef")
    #core_setup_area(fp, chip)

def analog_floorplan(fp, core):
    core_w = TOP_W
    core_h = TOP_H - ANALOG_Y

    if core:
        # Reduce size to pass OpenROAD GPL size check (macro width < core size)
        _, (place_w, _), _ = define_dimensions(fp)
        core_w = place_w

    diearea = [(0, 0), (core_w, core_h)]
    fp.create_diearea(diearea)

    pins = [
        # Net name, vector width (0=scalar)
        ("analog_la_out", 0, 9),
        ("analog_la_in", 4, 23),
        ("analog_la_out", 10, 29),
        ("analog_la_in", 0, 3),
        ("analog_la_in", 24, 29)
    ]
    pin_width = 0.56
    pin_depth = 2
    pin_layer = "met3"
    pin_y = 0
    pin_x = 100
    pin_x_end = 2560
    pin_count = 0
    for (_, bit_start, bit_end) in pins:
        bit_width = abs(bit_end - bit_start) + 1
        pin_count = pin_count + bit_width
    print(f"Found {pin_count} pins.")
    #pin_step = round((pin_x_end - pin_x) / (pin_count - 1))
    pin_step = 27
    for (pin_name, bit_start, bit_end) in pins:
        if bit_start == bit_end == 0:
            #fp.place_pins([pin_name], pin_x, pin_y, 0, 0, pin_width, pin_depth, pin_layer)
            place_pin(fp, pin_name, pin_x, pin_y, pin_width, pin_depth, pin_layer, drawing = not core)
            pin_x = pin_x + pin_step
        else:
            for i in range(bit_start, bit_end + 1):
                name = f"{pin_name}[{i}]"
                #fp.place_pins([name], pin_x, pin_y, 0, 0, pin_width, pin_depth, pin_layer)
                place_pin(fp, name, pin_x, pin_y, pin_width, pin_depth, pin_layer, drawing = not core)
                pin_x = pin_x + pin_step

def generate_analog_floorplan():
    analog_chip = configure_chip("analog_area")
    fp = Floorplan(analog_chip)
    analog_floorplan(fp, True)
    fp.write_def("analog_area/analog_area.def")
    fp.write_lef("analog_area/analog_area.lef")

    # Import additional pins from analog user wrapper
    fp_ep = Floorplan(analog_chip)
    analog_floorplan(fp_ep, False)
    # fp_ep.place_blockage(TOP_W - 100, 0, 100, 300, layer="met1")
    # fp_ep.place_blockage(TOP_W - 100, 0, 100, 300, layer="met2")
    # fp_ep.place_blockage(TOP_W - 100, 100, 100, 200, layer="met3")
    # fp_ep.place_blockage(TOP_W - 15, 0, 15, 330, layer="met4")
    pins = load_lef("user_analog_project_wrapper_empty.lef")
    for pin in pins:
        if (pin["y"] > ANALOG_Y * 1000):
            pin["y"] = pin["y"] - ANALOG_Y * 1000
            # place_pin(fp_ep, pin["name"], pin["x"] / 1000, pin["y"] / 1000,
            #         pin["w"] / 1000, pin["h"] / 1000, pin["layer"], pin["use"],
            #         False)
            fp_ep.place_pins(
                    pins = [pin["name"]],
                    x = pin["x"] / 1000,
                    y = pin["y"] / 1000,
                    xpitch = 0,
                    ypitch = 0,
                    width = pin["w"] / 1000,
                    height = pin["h"] / 1000,
                    layer = pin["layer"],
                    direction = pin["dir"],
                    netname = pin["net"],
                    use = pin["use"],
                    fixed = pin["fixed"],
                    add_port = False)
    fp_ep.place_pins(["vdda2"], 30.49, 0, 0, 0, 38.5, 4, "met4")
    fp_ep.place_pins(["vssd2"], 72.29, 0, 0, 0, 38.5, 4, "met4")
    fp_ep.place_pins(["vssa2"], 120.49, 0, 0, 0, 38.5, 4, "met4")
    fp_ep.place_pins(["vdda1"], 2820.49, 0, 0, 0, 38.5, 4, "met4")
    fp_ep.place_pins(["vssa1"], 2862.29, 0, 0, 0, 38.5, 4, "met4")
    fp_ep.write_def("analog_area/analog_area_with_external_pins.def")
    fp_ep.write_lef("analog_area/analog_area_with_external_pins.lef")

def main():
    # Generate analog floorplan
    generate_analog_floorplan()

    # Generate wrapper floorplan
    chip = configure_chip("user_analog_project_wrapper")
    load_lib(chip)
    generate_core_floorplan(chip)
    chip.write_manifest("sc_manifest.json")

if __name__ == "__main__":
    main()
