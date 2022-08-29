# Copyright 2020 Silicon Compiler Authors. All Rights Reserved.
import os
import shutil

from siliconcompiler.core import Chip
from siliconcompiler.floorplan import Floorplan

from floorplan import core_floorplan, generate_core_floorplan

###
# Example Skywater130 / "Caravel" macro hardening with SiliconCompiler
#
# This script builds a minimal 'heartbeat' example into the Caravel harness provided by
# eFabless for their MPW runs, connecting the 3 I/O signals to the wrapper's I/O pins.
# Other Caravel signals such as the Wishbone bus, IRQ, etc. are ignored.
#
# These settings have not been tested with one of eFabless' MPW runs yet, but
# it demonstrates how to run a 'caravel_user_project' build process using SiliconCompiler.
# The basic idea is to harden the core design as a macro with half of a power delivery grid and
# a blockage on the top metal layer. The top-level design's I/O signals are then routed to the
# macro pins, and the top-level PDN is connected by running its top-layer straps over the macro
# and connecting the straps with 'define_pdn_grid -existing'.
#
# The 'pdngen' and 'macroplace' parameters used here and in 'tools/openroad/sc_floorplan.tcl'
# can demonstrate one way to insert custom TCL commands into a tool flow.
###

# User project wrapper area is 2.92mm x 3.52mm
TOP_W = 2920
TOP_H = 3520
# Margins are set to ~10um, snapped to placement site dimensions (0.46um x 2.72um in sky130hd)
MARGIN_W = 9.66
#MARGIN_W = 9.52
MARGIN_H = 8.16
#MARGIN_H = 6.256

# Path to 'caravel' repository root.
CARAVEL_ROOT = '/home/wenting/caravel'

def configure_chip(design):
    # Minimal Chip object construction.
    chip = Chip(design)
    chip.load_target('skywater130_demo')

    # Customize tapcell script
    stackup = chip.get('asic', 'stackup')
    libtype = 'unithd'
    chip.set('pdk', 'skywater130', 'aprtech','openroad', stackup, libtype,'tapcells', 'tapcell_custom.tcl')

    # Layer resources adjustments
    chip.set('pdk', 'skywater130', 'grid', stackup, 'met1', 'adj', 0.2)
    chip.set('pdk', 'skywater130', 'grid', stackup, 'met2', 'adj', 0.2)
    chip.set('pdk', 'skywater130', 'grid', stackup, 'met3', 'adj', 0.1)
    chip.set('pdk', 'skywater130', 'grid', stackup, 'met4', 'adj', 0.1)
    chip.set('pdk', 'skywater130', 'grid', stackup, 'met5', 'adj', 0.1)

    chip.set('option', 'relax', True)
    return chip

def build_core():
    core_chip = configure_chip('asic_macro')
    core_chip.load_flow('mpwflow')
    core_chip.set('option', 'flow', 'mpwflow')
    design = core_chip.get('design')

    core_chip.set('tool', 'openroad', 'var', 'floorplan', '0', 'pin_thickness_h', ['2'])
    core_chip.set('tool', 'openroad', 'var', 'floorplan', '0', 'pin_thickness_v', ['2'])
    #core_chip.set('tool', 'openroad', 'var', 'floorplan', '0', 'macro_place_halo', ['50'])
    core_chip.set('tool', 'openroad', 'var', 'place', '0', 'place_density', ['0.52'])
    #core_chip.set('tool', 'openroad', 'var', 'place', '0', 'pad_global_place', ['16'])
    #core_chip.set('tool', 'openroad', 'var', 'place', '0', 'pad_detail_place', ['12'])
    core_chip.set('tool', 'openroad', 'var', 'route', '0', 'grt_allow_congestion', ['true'])
    
    core_chip.load_lib('sky130sram_8_1024')
    core_chip.load_lib('sky130sram_32_256')
    core_chip.load_lib('sky130sram_32_512')
    core_chip.add('asic', 'macrolib', 'sky130sram_8_1024')
    core_chip.add('asic', 'macrolib', 'sky130sram_32_256')
    core_chip.add('asic', 'macrolib', 'sky130sram_32_512')

    # Set DRC exclusion?

    # Add sources
    core_chip.clock('clk', period=20)

    core_chip.set('input', 'verilog', 'asic_macro.v')
    core_chip.add('input', 'verilog', '../rtl/asictop.v')
    core_chip.add('input', 'verilog', '../rtl/risu.v')
    core_chip.add('input', 'verilog', '../rtl/basic/fifo_1d_22to64.v')
    core_chip.add('input', 'verilog', '../rtl/basic/fifo_1d_64to22.v')
    core_chip.add('input', 'verilog', '../rtl/basic/fifo_1d_fwft.v')
    core_chip.add('input', 'verilog', '../rtl/basic/fifo_2d_fwft.v')
    core_chip.add('input', 'verilog', '../rtl/basic/fifo_2d.v')
    core_chip.add('input', 'verilog', '../rtl/basic/fifo_2w2r.v')
    core_chip.add('input', 'verilog', '../rtl/basic/fifo_nd.v')
    core_chip.add('input', 'verilog', '../rtl/basic/ram_32_56.v')
    core_chip.add('input', 'verilog', '../rtl/basic/ram_128_23.v')
    #core_chip.add('input', 'verilog', '../rtl/basic/ram_128_46.v')
    core_chip.add('input', 'verilog', '../rtl/basic/ram_512_64.v')
    core_chip.add('input', 'verilog', '../rtl/basic/ram_1024_8.v')
    core_chip.add('input', 'verilog', '../rtl/bus/kl_arbiter_2by1.v')
    core_chip.add('input', 'verilog', '../rtl/bus/kl_decoupler.v')
    core_chip.add('input', 'verilog', '../rtl/bus/kl2ml_bridge.v')
    core_chip.add('input', 'verilog', '../rtl/bus/ml_xcvr.v')
    core_chip.add('input', 'verilog', '../rtl/bus/ml2kl_bridge.v')
    core_chip.add('input', 'verilog', '../rtl/system/l1cache.v')
    core_chip.add('input', 'verilog', '../rtl/core/alu.v')
    core_chip.add('input', 'verilog', '../rtl/core/bp_base.v')
    core_chip.add('input', 'verilog', '../rtl/core/cpu.v')
    core_chip.add('input', 'verilog', '../rtl/core/dec_bundled.v')
    core_chip.add('input', 'verilog', '../rtl/core/dec.v')
    core_chip.add('input', 'verilog', '../rtl/core/div.v')
    core_chip.add('input', 'verilog', '../rtl/core/du.v')
    core_chip.add('input', 'verilog', '../rtl/core/ifp.v')
    core_chip.add('input', 'verilog', '../rtl/core/ip.v')
    core_chip.add('input', 'verilog', '../rtl/core/ix.v')
    core_chip.add('input', 'verilog', '../rtl/core/lsp.v')
    core_chip.add('input', 'verilog', '../rtl/core/md.v')
    core_chip.add('input', 'verilog', '../rtl/core/mmu.v')
    core_chip.add('input', 'verilog', '../rtl/core/mul.v')
    core_chip.add('input', 'verilog', '../rtl/core/ptw.v')
    core_chip.add('input', 'verilog', '../rtl/core/rf.v')
    core_chip.add('input', 'verilog', '../rtl/core/tlb.v')
    core_chip.add('input', 'verilog', '../rtl/core/trap.v')
    core_chip.add('input', 'verilog', '../rtl/core/wb.v')
    core_chip.add('input', 'verilog', '../rtl/third_party/priority_arbiter.v')
    core_chip.add('input', 'verilog', '../rtl/third_party/round_robin_arbiter.v')

    core_chip.set('option', 'idir', '../rtl/bus')
    core_chip.add('option', 'idir', '../rtl/core')
    core_chip.add('option', 'idir', '../asic') # Cannot use . as it would be directed to build folder

    core_chip.add('input', 'verilog', 'sky130/ram/sky130_sram_1kbyte_1rw1r_8x1024_8.bb.v')
    core_chip.add('input', 'verilog', 'sky130/ram/sky130_sram_1kbyte_1rw1r_32x256_8.bb.v')
    core_chip.add('input', 'verilog', 'sky130/ram/sky130_sram_2kbyte_1rw1r_32x512_8.bb.v')

    # Optional: These configurations can add padding around cells during the placement steps,
    # which can help to reduce routing congestion at the expense of placement density.
    #core_chip.add('tool', 'openroad', 'var', 'place', '0', 'pad_global_place', ['2'])
    #core_chip.add('tool', 'openroad', 'var', 'place', '0', 'pad_detail_place', ['2'])

    generate_core_floorplan(core_chip)

    # No routing on met4-met5.
    stackup = core_chip.get('asic', 'stackup')
    libtype = 'unithd'
    # Disallow met5 general routing
    core_chip.set('asic', 'minlayer', 'met1')
    core_chip.set('asic', 'maxlayer', 'met4')

    # Configure core-level PDN script.
    pdk = core_chip.get('option', 'pdk')
    with open('pdngen.tcl', 'w') as pdnf:
        pdnf.write('''
# Add PDN connections for each voltage domain.
add_global_connection -net vccd1 -pin_pattern "^VPWR$" -power
add_global_connection -net vssd1 -pin_pattern "^VGND$" -ground
add_global_connection -net vccd1 -pin_pattern "^POWER$" -power
add_global_connection -net vssd1 -pin_pattern "^GROUND$" -ground
add_global_connection -net vccd1 -inst_pattern ".+mem" -pin_pattern vccd1
add_global_connection -net vssd1 -inst_pattern ".+mem" -pin_pattern vssd1
global_connect

set_voltage_domain -name Core -power vccd1 -ground vssd1
#define_pdn_grid -name core_grid -voltage_domain Core -starts_with POWER -pins met4
#add_pdn_stripe -grid core_grid -layer met1 -width 0.48 -pitch 5.44 -offset 0 -starts_with POWER
#add_pdn_stripe -grid core_grid -layer met1 -width 0.48 -starts_with POWER -followpins
#add_pdn_stripe -grid core_grid -layer met4 -width 5 -pitch 50 -offset 2 -starts_with POWER
#add_pdn_connect -grid core_grid -layers {met1 met4}

define_pdn_grid -name core_grid -voltage_domain Core -starts_with POWER -pins {met4 met5}
#add_pdn_stripe -grid core_grid -layer met1 -width 0.48 -starts_with POWER -followpins
add_pdn_stripe -grid core_grid -layer met1 -width 0.48 -pitch 5.44 -offset 0 -starts_with POWER
add_pdn_stripe -grid core_grid -layer met4 -width 3.1 -pitch 180 -offset 10 -starts_with POWER -extend_to_core_ring
add_pdn_stripe -grid core_grid -layer met5 -width 3.1 -pitch 90 -offset 2 -starts_with POWER -extend_to_core_ring
add_pdn_connect -grid core_grid -layers {met1 met4}
add_pdn_connect -grid core_grid -layers {met4 met5}
add_pdn_ring -grid core_grid -layers {met4 met5} -widths 3.1 -spacings 1.7 -core_offset 2.9

define_pdn_grid -macro -default -name macro -voltage_domain Core -halo 3.0 -starts_with POWER -grid_over_pg_pins
add_pdn_connect -grid macro -layers {met4 met5}

# Done defining commands; generate PDN.
pdngen''')
    core_chip.set('pdk', pdk, 'aprtech', 'openroad', stackup, libtype, 'pdngen', 'pdngen.tcl')

    # Build the core design.
    core_chip.run()

    core_chip.summary()

    # Copy GDS/DEF/LEF files for use in the top-level build.
    shutil.copy(core_chip.find_result('gds', step='export'), f'{design}.gds')
    shutil.copy(core_chip.find_result('vg', step='dfm'), f'{design}.vg')
    shutil.copy(core_chip.find_result('def', step='dfm'), f'{design}.def')
    shutil.copy(core_chip.find_result('lef', step='dfm'), f'{design}.lef')

def build_top():
    # The 'hearbeat' RTL goes in a modified 'user_project_wrapper' object, see sources.
    design = 'user_project_wrapper'
    chip = configure_chip(design)
    chip.load_flow('mpwflow')
    chip.set('option', 'flow', 'mpwflow')
    chip.set('tool', 'openroad', 'var', 'place', '0', 'place_density', ['0.15'])
    #chip.add('tool', 'openroad', 'var', 'place', '0', 'pad_global_place', ['2'])
    #chip.add('tool', 'openroad', 'var', 'place', '0', 'pad_detail_place', ['2'])
    chip.set('tool', 'openroad', 'var', 'route', '0', 'grt_allow_congestion', ['true'])
    chip.clock('user_clock2', period=20)

    # Set top-level source files.
    chip.set('input', 'verilog', f'{CARAVEL_ROOT}/verilog/rtl/defines.v')
    chip.add('input', 'verilog', 'asic_macro.bb.v')
    chip.add('input', 'verilog', 'user_project_wrapper.v')

    # Set top-level die/core area.
    chip.set('asic', 'diearea', (0, 0))
    chip.add('asic', 'diearea', (TOP_W, TOP_H))
    chip.set('asic', 'corearea', (MARGIN_W, MARGIN_H))
    chip.add('asic', 'corearea', (TOP_W - MARGIN_W, TOP_H - MARGIN_H))

    # Add core design macro as a library.
    libname = 'asic_macro'
    stackup = chip.get('asic', 'stackup')
    chip.add('asic', 'macrolib', libname)
    asic_macro_lib = Chip('asic_macro')
    asic_macro_lib.add('model', 'layout', 'lef', stackup, 'asic_macro.lef')
    asic_macro_lib.add('model', 'layout', 'def', stackup, 'asic_macro.def')
    asic_macro_lib.add('model', 'layout', 'gds', stackup, 'asic_macro.gds')
    asic_macro_lib.add('model', 'layout', 'vg', stackup, 'asic_macro.vg')
    asic_macro_lib.set('asic', 'pdk', 'skywater130')
    asic_macro_lib.set('option', 'pdk', 'skywater130')
    asic_macro_lib.set('asic', 'stackup', stackup)
    chip.import_library(asic_macro_lib)

    # Use pre-defined floorplan for the wrapper..
    #chip.set('input', 'floorplan.def', f'{CARAVEL_ROOT}/def/user_project_wrapper.def')
    chip.set('input', 'floorplan.def', 'user_project_wrapper_nogrid.def')

    # (No?) filler cells in the top-level wrapper.
    chip.set('library', 'sky130hd', 'asic', 'cells', 'filler', [])
    chip.add('library', 'sky130hd', 'asic', 'cells', 'ignore', 'sky130_fd_sc_hd__conb_1')

    # (No?) tapcells in the top-level wrapper.
    pdk = chip.get('option', 'pdk')
    libtype = 'unithd'
    chip.cfg['pdk'][pdk]['aprtech']['openroad'][stackup][libtype].pop('tapcells')

    # No I/O buffers in the top-level wrapper, but keep tie-hi/lo cells.
    chip.set('library', 'sky130hd', 'asic', 'cells', 'tie', [])
    chip.set('library', 'sky130hd', 'asic', 'cells', 'buf', [])
    #chip.set('asic', 'cells', 'buf', [])

    # Create PDN-generation script.
    pdk = chip.get('option', 'pdk')
    with open('pdngen_top.tcl', 'w') as pdnf:
        # TODO: Jinja template?
        pdnf.write('''
# Add PDN connections for each voltage domain.
add_global_connection -net vccd1 -pin_pattern "^VPWR$" -power
add_global_connection -net vssd1 -pin_pattern "^VGND$" -ground
add_global_connection -net vccd1 -pin_pattern "^POWER$" -power
add_global_connection -net vssd1 -pin_pattern "^GROUND$" -ground
add_global_connection -net vccd1 -pin_pattern vccd1
add_global_connection -net vssd1 -pin_pattern vssd1
global_connect

set_voltage_domain -name Core -power vccd1 -ground vssd1 -secondary_power {vccd2 vssd2 vdda1 vssa1 vdda2 vssa2}
#set_voltage_domain -name Core -power vccd1 -ground vssd1
define_pdn_grid -name top_grid -voltage_domain Core -starts_with POWER -pins {met4 met5}

add_pdn_stripe -grid top_grid -layer met4 -width 3.1 -pitch 90 -spacing 41.9 -offset 5 -starts_with POWER -extend_to_core_ring -nets {vccd1 vssd1}
add_pdn_stripe -grid top_grid -layer met5 -width 3.1 -pitch 90 -spacing 41.9 -offset 5 -starts_with POWER -extend_to_core_ring -nets {vccd1 vssd1}
add_pdn_connect -grid top_grid -layers {met4 met5}

add_pdn_ring -grid top_grid -layers {met4 met5} -widths {3.1 3.1} -spacings {1.7 1.7} -core_offset {12.45 12.45}
#add_pdn_ring -grid top_grid -layers {met4 met5} -widths {3.1 3.1} -spacings {1.7 1.7} -core_offset {14 14}

define_pdn_grid -macro -default -name macro -voltage_domain Core -halo {-9.3 -7.98} -starts_with POWER -grid_over_boundary
add_pdn_connect -grid macro -layers {met4 met5}

# Done defining commands; generate PDN.
pdngen''')
    chip.set('pdk', pdk, 'aprtech', 'openroad', stackup, libtype, 'pdngen', 'pdngen_top.tcl')

    # Generate macro-placement script.
    with open('macroplace_top.tcl', 'w') as mf:
        mf.write('''
# 'mprj' user-defined project macro
place_cell -inst_name mprj -origin {70.08 70.72} -orient R0 -status FIRM
''')
    chip.set('pdk', pdk, 'aprtech', 'openroad', stackup, libtype, 'macroplace', 'macroplace_top.tcl')

    # Run the top-level build.
    chip.run()

    # Add via definitions to the gate-level netlist.
    shutil.copy(chip.find_result('vg', step='addvias'), f'{design}.vg')

def main():
    #build_core()
    build_top()

if __name__ == '__main__':
    main()
