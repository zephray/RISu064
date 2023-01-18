#
# RISu164
# Copyright 2022 Wenting Zhang
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.
#

PYTHON = python3
PYHP = ../tool/pyhp.py
FORMATTER = verible-verilog-format \
	--column_limit 132 --indentation_spaces 4 \
	--assignment_statement_alignment flush-left \
	--case_items_alignment flush-left \
	--class_member_variable_alignment flush-left \
	--distribution_items_alignment flush-left \
	--enum_assignment_statement_alignment flush-left \
	--formal_parameters_alignment flush-left \
	--module_net_variable_alignment flush-left \
	--named_parameter_alignment flush-left \
	--named_port_alignment flush-left \
	--port_declarations_alignment flush-left \
	--struct_union_members_alignment flush-left \
	--try_wrap_long_lines=true \
	--failsafe_success=true \
	--inplace=true

# Process PYV files into V files
PYV_FILES = $(shell find . -type f -name '*.pyv')
PYV_V_FILES = $(patsubst %.pyv, genrtl/%.v, $(PYV_FILES))
# Also copy V and VH files verbatim
COPY_V_FILES = $(shell find . -type f -name '*.v' -o -name '*.vh' -not -path "./genrtl/*")
COPY_DST_V_FILES := $(patsubst %.v, genrtl/%.v, $(COPY_V_FILES))
COPY_DST_V_FILES := $(patsubst %.vh, genrtl/%.vh, $(COPY_DST_V_FILES))

export PYTHONPATH := pylib

.PHONY: all
all: $(PYV_V_FILES) $(COPY_DST_V_FILES)
	@echo "Done. Generated RTL sources are in genrtl folder."

# Preprocess
genrtl/%.v: %.pyv
	@mkdir -p $(@D)
	$(PYTHON) $(PYHP) $< > $@
	@$(FORMATTER) $@

# Copy
genrtl/%.v: %.v
	@mkdir -p $(@D)
	@cp $< $@

genrtl/%.vh: %.vh
	@mkdir -p $(@D)
	@cp $< $@

.PHONY: clean
clean:
	rm -r genrtl