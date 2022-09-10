# Copyright 2020 Silicon Compiler Authors. All Rights Reserved.
import os
import shutil

from siliconcompiler.core import Chip
from siliconcompiler.floorplan import Floorplan

from floorplan import core_floorplan, generate_core_floorplan, load_lib

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

# Path to 'caravel' repository root.
CARAVEL_ROOT = '/home/wenting/caravel'

process = 'skywater130b'
libname = 'sky130bhd'

def configure_chip(design):
    # Minimal Chip object construction.
    chip = Chip(design)
    chip.load_target('skywater130b_demo')

    # Customize tapcell script
    stackup = chip.get('asic', 'stackup')
    libtype = 'unithd'
    chip.set('pdk', process, 'aprtech','openroad', stackup, libtype,'tapcells', 'tapcell_custom.tcl')

    # Layer resources adjustments
    chip.set('pdk', process, 'grid', stackup, 'met1', 'adj', 0.2)
    chip.set('pdk', process, 'grid', stackup, 'met2', 'adj', 0.2)
    chip.set('pdk', process, 'grid', stackup, 'met3', 'adj', 0.1)
    chip.set('pdk', process, 'grid', stackup, 'met4', 'adj', 0.1)
    chip.set('pdk', process, 'grid', stackup, 'met5', 'adj', 0.1)

    chip.set('option', 'relax', True)
    return chip

def build():
    core_chip = configure_chip('user_analog_project_wrapper')
    core_chip.load_flow('mpwflow')
    core_chip.set('option', 'flow', 'mpwflow')
    design = core_chip.get('design')

    core_chip.set('tool', 'openroad', 'var', 'floorplan', '0', 'pin_thickness_h', ['2'])
    core_chip.set('tool', 'openroad', 'var', 'floorplan', '0', 'pin_thickness_v', ['2'])
    #core_chip.set('tool', 'openroad', 'var', 'floorplan', '0', 'macro_place_halo', ['50'])
    core_chip.set('tool', 'openroad', 'var', 'place', '0', 'place_density', ['0.45'])
    #core_chip.set('tool', 'openroad', 'var', 'place', '0', 'pad_global_place', ['16'])
    #core_chip.set('tool', 'openroad', 'var', 'place', '0', 'pad_detail_place', ['12'])
    core_chip.set('tool', 'openroad', 'var', 'route', '0', 'grt_allow_congestion', ['true'])
    
    # Import macro libs
    load_lib(core_chip)

    # Add sources
    core_chip.clock('user_clock2', period=20)

    core_chip.set('input', 'verilog', 'caravel_defines.v')
    core_chip.add('input', 'verilog', 'user_analog_project_wrapper.v')
    core_chip.add('input', 'verilog', 'therm_out.v')
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
    core_chip.add('input', 'verilog', 'analog_area/analog_area.bb.v')

    # Optional: These configurations can add padding around cells during the placement steps,
    # which can help to reduce routing congestion at the expense of placement density.
    #core_chip.add('tool', 'openroad', 'var', 'place', '0', 'pad_global_place', ['2'])
    #core_chip.add('tool', 'openroad', 'var', 'place', '0', 'pad_detail_place', ['2'])

    generate_core_floorplan(core_chip)

    # No routing on met5.
    stackup = core_chip.get('asic', 'stackup')
    libtype = 'unithd'
    # Disallow met5 general routing
    core_chip.set('asic', 'minlayer', 'met1')
    core_chip.set('asic', 'maxlayer', 'met4')

    # Set filler cells in the top-level wrapper.
    core_chip.set('library', libname, 'asic', 'cells', 'filler', [
            'sky130_fd_sc_hd__fill_1',
            'sky130_fd_sc_hd__fill_2',
            'sky130_fd_sc_hd__decap_3',
            'sky130_fd_sc_hd__decap_4',
            'sky130_fd_sc_hd__decap_6',
            'sky130_fd_sc_hd__decap_8',
            'sky130_ef_sc_hd__decap_12'])

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
    # Add via definitions to the gate-level netlist.
    shutil.copy(core_chip.find_result('vg', step='addvias'), f'{design}.vg')

def main():
    build()

if __name__ == '__main__':
    main()
