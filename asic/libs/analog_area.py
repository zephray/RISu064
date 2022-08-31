import siliconcompiler

def setup(chip):
    libname = 'analog_area'
    lib = siliconcompiler.Chip(libname)

    stackup = '5M1LI' # TODO: this should this be extracted from something
    version = 'v0_0_2'

    lib.set('package', 'version', version)

    lib.set('asic', 'pdk', 'skywater130')
    lib.set('asic', 'stackup', stackup)

    lib.add('model', 'layout', 'lef', stackup, 'analog_area/analog_area.lef')
    lib.add('model', 'layout', 'def', stackup, 'analog_area/analog_area.def')
    lib.add('model', 'layout', 'gds', stackup, 'analog_area/analog_area.gds')

    chip.import_library(lib)
