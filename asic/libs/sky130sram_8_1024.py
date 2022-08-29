import siliconcompiler

def setup(chip):
    libname = 'sky130sram_8_1024'
    lib = siliconcompiler.Chip(libname)

    stackup = '5M1LI' # TODO: this should this be extracted from something
    version = 'v0_0_2'

    lib.set('package', 'version', version)

    lib.set('asic', 'pdk', 'skywater130')
    lib.set('asic', 'stackup', stackup)

    lib.add('model', 'timing', 'nldm', 'typical', 'sky130/ram/sky130_sram_1kbyte_1rw1r_8x1024_8_TT_1p8V_25C.lib')
    lib.add('model', 'layout', 'lef', stackup, 'sky130/ram/sky130_sram_1kbyte_1rw1r_8x1024_8.lef')
    lib.add('model', 'layout', 'gds', stackup, 'sky130/ram/sky130_sram_1kbyte_1rw1r_8x1024_8.gds')

    chip.import_library(lib)
