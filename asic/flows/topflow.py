import siliconcompiler

def make_docs():
    '''An RTL2GDS flow for the eFabless MPW shuttle. This flow is based off the
    basic serial asicflow, with the addition of fixdef and addvias steps for
    doing MPW-specific fixes to the post-routing DEF and gate-level netlist,
    respectively.'''
    chip = siliconcompiler.Chip('<design>')
    setup(chip)
    chip.set('option', 'flow', 'topflow')
    return chip

def setup(chip):
    flow = 'topflow'

    flowpipe = [
        ('import', 'surelog'),
        ('syn', 'yosys'),
        ('floorplan', 'openroad'),
        ('cts', 'openroad'),
        ('route', 'openroad'),
        ('fixdef', 'fixdef'),
        ('dfm', 'openroad'),
        ('export', 'klayout')
    ]

    step, tool = flowpipe[0]
    chip.node(flow, step, tool)

    prevstep = step
    for step, tool in flowpipe[1:]:
        chip.node(flow, step, tool)
        chip.edge(flow, prevstep, step)
        prevstep = step

    chip.node(flow, 'addvias', 'addvias')
    chip.edge(flow, 'dfm', 'addvias')

if __name__ == '__main__':
    chip = make_docs()
    chip.write_flowgraph('topflow.png')
