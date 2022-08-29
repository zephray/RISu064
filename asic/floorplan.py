from calendar import c
from siliconcompiler.core import Chip
from siliconcompiler.floorplan import Floorplan

import math

RAM_8_1024 = 'sky130_sram_1kbyte_1rw1r_8x1024_8'
RAM_24_128 = 'sky130_sram_1r1w_24x128'
RAM_32_256 = 'sky130_sram_1kbyte_1rw1r_32x256_8'
RAM_32_512 = 'sky130_sram_2kbyte_1rw1r_32x512_8'
RAM_46_128 = 'sky130_sram_1r1w_46x128'
RAM_64_512 = 'sky130_sram_4kbyte_1r1w_64x512'

def configure_chip(design):
    chip = Chip(design)
    chip.load_target('skywater130_demo')

    chip.load_lib('sky130sram_8_1024')
    chip.load_lib('sky130sram_24_128')
    chip.load_lib('sky130sram_32_256')
    chip.load_lib('sky130sram_32_512')
    chip.load_lib('sky130sram_46_128')
    chip.load_lib('sky130sram_64_512')
    chip.add('asic', 'macrolib', 'sky130sram_8_1024')
    chip.add('asic', 'macrolib', 'sky130sram_24_128')
    chip.add('asic', 'macrolib', 'sky130sram_32_256')
    chip.add('asic', 'macrolib', 'sky130sram_32_512')
    chip.add('asic', 'macrolib', 'sky130sram_46_128')
    chip.add('asic', 'macrolib', 'sky130sram_64_512')

    chip.set('option', 'showtool', 'def', 'klayout')
    chip.set('option', 'showtool', 'gds', 'klayout')

    return chip

def define_dimensions(fp):
    # 6000 900
    place_w = 6000 * fp.stdcell_width # 0.46
    place_h = 930 * fp.stdcell_height # 2.72
    margin_left = 25 * fp.stdcell_width
    margin_bottom = 4 * fp.stdcell_height

    core_w = place_w + 2 * margin_left
    core_h = place_h + 2 * margin_bottom

    return (core_w, core_h), (place_w, place_h), (margin_left, margin_bottom)

def core_setup_area(fp, chip):
    dims = define_dimensions(fp)
    (core_w, core_h), (place_w, place_h), (margin_left, margin_bottom) = dims
    chip.set('asic', 'diearea', (0, 0))
    chip.add('asic', 'diearea', (core_w, core_h))
    chip.set('asic', 'corearea', (margin_left, margin_bottom))
    chip.add('asic', 'corearea', (place_w + margin_left, place_h + margin_bottom))

def snap_x(fp, val, adj):
    return (round(val / fp.stdcell_width) + adj) * fp.stdcell_width

def snap_y(fp, val, adj):
    return (round(val / fp.stdcell_height) + adj) * fp.stdcell_height

def place_ram(fp, inst_name, macro_name, x, y, orientation):
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
    fp.place_blockage(halo_x, halo_y, halo_w, halo_h, layer='li1')

    ram_margin_x = 100 * fp.stdcell_width
    ram_margin_y = 20 * fp.stdcell_height
    blockage_x = ram_x - ram_margin_x
    blockage_y = ram_y - ram_margin_y
    blockage_w = ram_w + ram_margin_x * 2
    blockage_h = ram_h + ram_margin_y * 2

    fp.place_blockage(blockage_x, blockage_y, blockage_w, blockage_h)

def core_floorplan(fp):
    ## Set up die area ##
    dims = define_dimensions(fp)
    (core_w, core_h), (place_w, place_h), (margin_left, margin_bottom) = dims
    diearea = [(0, 0), (core_w, core_h)]
    corearea = [(margin_left, margin_bottom), (place_w + margin_left, place_h + margin_bottom)]
    fp.create_diearea(diearea, corearea=corearea)

    # not gonna to calculate, just going to place wherever I like
    place_ram(fp, "asictop.risu.l1d.cache_ram\[0\].cache_data.hi_mem", RAM_32_512, 4450, 10, 'N')
    place_ram(fp, "asictop.risu.l1d.cache_ram\[0\].cache_data.lo_mem", RAM_32_512, 4450, 200, 'N')
    place_ram(fp, "asictop.risu.l1d.cache_ram\[1\].cache_data.hi_mem", RAM_32_512, 4450, 390, 'N')
    place_ram(fp, "asictop.risu.l1d.cache_ram\[1\].cache_data.lo_mem", RAM_32_512, 4450, 580, 'N')

    place_ram(fp, "asictop.risu.l1i.cache_ram\[0\].cache_data.hi_mem", RAM_32_512, 2880, 10, 'N')
    place_ram(fp, "asictop.risu.l1i.cache_ram\[0\].cache_data.lo_mem", RAM_32_512, 2880, 200, 'N')
    place_ram(fp, "asictop.risu.l1i.cache_ram\[1\].cache_data.hi_mem", RAM_32_512, 2880, 390, 'N')
    place_ram(fp, "asictop.risu.l1i.cache_ram\[1\].cache_data.lo_mem", RAM_32_512, 2880, 580, 'N')

    place_ram(fp, "asictop.risu.l1d.cache_ram\[0\].cache_meta.mem", RAM_32_256, 3670, 770, 'N')
    place_ram(fp, "asictop.risu.l1d.cache_ram\[1\].cache_meta.mem", RAM_32_256, 4880, 770, 'N')

    place_ram(fp, "asictop.risu.l1i.cache_ram\[0\].cache_meta.mem", RAM_32_256, 1250, 770, 'N')
    place_ram(fp, "asictop.risu.l1i.cache_ram\[1\].cache_meta.mem", RAM_32_256, 2460, 770, 'N')

    place_ram(fp, "asictop.risu.cpu.ifp.bp.bpu_ram.mem", RAM_8_1024, 85, 750, 'N')

    #place_ram(fp, "asictop.risu.l1d.cache_ram\[0\].cache_data.mem", RAM_64_512, 4210, 60)
    #place_ram(fp, "asictop.risu.l1d.cache_ram\[1\].cache_data.mem", RAM_64_512, 4210, 410)

    #place_ram(fp, "asictop.risu.l1d.cache_ram\[0\].cache_data.mem", RAM_64_512, 4210, 60)
    #place_ram(fp, "asictop.risu.l1d.cache_ram\[1\].cache_data.mem", RAM_64_512, 4210, 410)
    
    #place_ram(fp, "asictop.risu.l1i.cache_ram\[0\].cache_data.mem", RAM_64_512, 140, 60)
    #place_ram(fp, "asictop.risu.l1i.cache_ram\[1\].cache_data.mem", RAM_64_512, 140, 410)

    #place_ram(fp, "asictop.risu.l1d.cache_ram\[0\].cache_meta.mem", RAM_24_128, 3790, 790)
    #place_ram(fp, "asictop.risu.l1d.cache_ram\[1\].cache_meta.mem", RAM_24_128, 4980, 790)

    #place_ram(fp, "asictop.risu.l1i.cache_ram\[0\].cache_meta.mem", RAM_24_128, 140, 790)
    #place_ram(fp, "asictop.risu.l1i.cache_ram\[1\].cache_meta.mem", RAM_24_128, 1330, 790)

    # place_ram(fp, "asictop.risu.l1d.cache_ram\[0\].cache_data.mem", RAM_64_512, 2340, 630, 'S')
    # place_ram(fp, "asictop.risu.l1d.cache_ram\[1\].cache_data.mem", RAM_64_512, 4210, 630, 'S')

    # place_ram(fp, "asictop.risu.l1d.cache_ram\[0\].cache_meta.mem", RAM_24_128, 3790, 480, 'N')
    # place_ram(fp, "asictop.risu.l1d.cache_ram\[1\].cache_meta.mem", RAM_24_128, 4980, 480, 'N')

    # place_ram(fp, "asictop.risu.l1i.cache_ram\[0\].cache_data.mem", RAM_64_512, 2340, 40, 'N')
    # place_ram(fp, "asictop.risu.l1i.cache_ram\[1\].cache_data.mem", RAM_64_512, 4210, 40, 'N')

    # place_ram(fp, "asictop.risu.l1i.cache_ram\[0\].cache_meta.mem", RAM_24_128, 3790, 330, 'S')
    # place_ram(fp, "asictop.risu.l1i.cache_ram\[1\].cache_meta.mem", RAM_24_128, 4980, 330, 'S')

    # place_ram(fp, "asictop.risu.l1d.cache_ram\[0\].cache_data.mem", RAM_64_512, 100, 630, 'S')
    # place_ram(fp, "asictop.risu.l1d.cache_ram\[1\].cache_data.mem", RAM_64_512, 1970, 630, 'S')

    # place_ram(fp, "asictop.risu.l1d.cache_ram\[0\].cache_meta.mem", RAM_24_128, 100, 480, 'S')
    # place_ram(fp, "asictop.risu.l1d.cache_ram\[1\].cache_meta.mem", RAM_24_128, 1290, 480, 'S')

    # place_ram(fp, "asictop.risu.l1i.cache_ram\[0\].cache_data.mem", RAM_64_512, 2340, 40, 'N')
    # place_ram(fp, "asictop.risu.l1i.cache_ram\[1\].cache_data.mem", RAM_64_512, 4210, 40, 'N')

    # place_ram(fp, "asictop.risu.l1i.cache_ram\[0\].cache_meta.mem", RAM_24_128, 3790, 330, 'N')
    # place_ram(fp, "asictop.risu.l1i.cache_ram\[1\].cache_meta.mem", RAM_24_128, 4980, 330, 'N')

    # place_ram(fp, "asictop.risu.l1d.cache_ram\[0\].cache_data.mem", RAM_64_512, 2340, 630, 'S')
    # place_ram(fp, "asictop.risu.l1d.cache_ram\[1\].cache_data.mem", RAM_64_512, 4210, 630, 'S')

    # place_ram(fp, "asictop.risu.l1d.cache_meta.mem", RAM_46_128, 2350, 330, 'S')

    # place_ram(fp, "asictop.risu.l1i.cache_ram\[0\].cache_data.mem", RAM_64_512, 2340, 40, 'N')
    # place_ram(fp, "asictop.risu.l1i.cache_ram\[1\].cache_data.mem", RAM_64_512, 4210, 40, 'N')

    # place_ram(fp, "asictop.risu.l1i.cache_meta.mem", RAM_46_128, 3600, 330, 'N')

    # place_ram(fp, "asictop.risu.cpu.ifp.bp.bpu_ram.mem", RAM_8_1024, 4850, 320, 'N')

    pins = [
        # Net name, vector width (0=scalar)
        ('clk', 0),
        ('rst', 0),
        ('clko', 0),
        ('io_in', 27),
        ('io_out', 27),
        ('io_oeb', 27)
    ]
    pin_width = 0.28
    pin_depth = 2
    pin_layer = "met2"
    pin_y = 0
    pin_x = 10 - pin_depth + margin_left
    pin_x_end = 1000 + margin_left
    pin_count = 0
    for (_, bit_width) in pins:
        if bit_width == 0:
            pin_count = pin_count + 1
        else:
            pin_count = pin_count + bit_width
    pin_step = round((pin_x_end - pin_x) / (pin_count - 1))
    for (pin_name, bit_width) in pins:
        if bit_width == 0:
            fp.place_pins([pin_name], pin_x, pin_y, 0, 0, pin_width, pin_depth, pin_layer)
            pin_x = pin_x + pin_step
        else:
            for i in range(bit_width):
                name = f'{pin_name}[{i}]'
                fp.place_pins([name], pin_x, pin_y, 0, 0, pin_width, pin_depth, pin_layer)
                pin_x = pin_x + pin_step

    # pin_width = 0.28
    # pin_depth = 2
    # pin_layer = "met3"
    # pin_y = 200 - pin_width + margin_bottom
    # pin_y_end = 2300 + margin_bottom
    # pin_x = 0
    # pin_count = 0
    # for (_, bit_width) in pins:
    #     if bit_width == 0:
    #         pin_count = pin_count + 1
    #     else:
    #         pin_count = pin_count + bit_width
    # pin_step = round((pin_y_end - pin_y) / (pin_count - 1))
    # for (pin_name, bit_width) in pins:
    #     if bit_width == 0:
    #         fp.place_pins([pin_name], pin_x, pin_y, 0, 0, pin_depth, pin_width, pin_layer)
    #         pin_y = pin_y + pin_step
    #     else:
    #         for i in range(bit_width):
    #             name = f'{pin_name}[{i}]'
    #             fp.place_pins([name], pin_x, pin_y, 0, 0, pin_depth, pin_width, pin_layer)
    #             pin_y = pin_y + pin_step

def generate_core_floorplan(chip):
    fp = Floorplan(chip)
    core_floorplan(fp)
    fp.write_def('asic_macro.def')
    fp.write_lef('asic_macro.lef')
    chip.set('input', 'floorplan.def', 'asic_macro.def')
    stackup = chip.get('asic', 'stackup')
    chip.set('model', 'layout', 'lef', stackup, 'asic_macro.lef')
    #core_setup_area(fp, chip)

def main():
    core_chip = configure_chip('asic_macro')
    core_chip.write_manifest('sc_manifest.json')
    generate_core_floorplan(core_chip)

if __name__ == '__main__':
    main()
