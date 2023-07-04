#!/usr/bin/env python3
#
# RISu64
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
import argparse
from weakref import ref

# Global configurations
converge_limit = 20

def main():
    parser = argparse.ArgumentParser(
            description="Compare trace generated by RISu and Spike")
    parser.add_argument("--risu", "-r", required=True,
            help="Trace log generated by RISu simulator")
    parser.add_argument("--spike", "-s", required=True,
            help="Trace log generated by Spike")
    args = parser.parse_args()

    reg_trace_ref = []
    reg_trace = []
    for i in range(0, 32):
        reg_trace_ref.append([])
        reg_trace.append([])

    # Parse reference trace
    slog = open(args.spike, "r")
    count = 0
    foundstart = False
    lineno = 0
    for line in slog:
        lineno = lineno + 1
        if (len(line) < 66):
            continue
        if (line[0] != "c"):
            continue
        if (line[10] != "3"):
            continue
        line = line[10:-1]
        token = line.split()
        #print(token)
        pc = token[1][2:]
        if (not foundstart):
            pcint = int(pc, base=16)
            if (pcint != 0x80000000):
                continue
            else:
                foundstart = True

        #instr = token[2]
        mw = 0
        rw = 0
        mr = 0
        rt = 0
        if len(token) >= 4:
            if token[3] == "mem":
                mwaddr = token[4][2:]
                mwdata = token[5][2:]
                mw = 1
            else:
                rdst = int(token[3][1:])
                if rdst != 0:
                    value = token[4][2:]
                    rw = 1
                else:
                    rt = 1
                if len(token) == 7:
                    mraddr = token[6][2:]
                    mr = 1
        else:
            rt = 1
        if rw:
            event = (lineno, pc, value)
            reg_trace_ref[rdst].append(event)
            count = count + 1
        if rt:
            event = (lineno, pc)
            reg_trace_ref[0].append(event)
            count = count + 1
    print(count, "reference writeback entry read.")

    slog.close()
    #print(reg_trace_ref)

    # Parse risu trace
    rlog = open(args.risu, "r")
    count = 0
    foundstart = False
    lineno = 0
    for line in rlog:
        lineno = lineno + 1
        if (line[0:2] != "PC"):
            continue
        line = line[3:-1]
        token = line.split()
        if token[2] == "[":
            token.pop(2)
            token[2] = token[2][0]
        else:
            token[2] = token[2][1:3]
        pc = token[0]
        #print(token)
        rw = 0
        rt = 0
        if (token[1] == "WB"):
            rw = 1
            rdst = int(token[2])
            value = token[4]
        elif (token[1] == "RETIRE"):
            rt = 1
        if rw:
            event = (lineno, pc, value)
            reg_trace[rdst].append(event)
            count = count + 1
        if rt:
            event = (lineno, pc)
            reg_trace[0].append(event)
            count = count + 1
    print(count, "actual writeback entry read.")
    
    rlog.close()
    #print(reg_trace)

    totalcmp = 0
    # Compare register writeback
    for r in range(1,32):
        # Compare up to the maximum recorded length
        #print("Comparing register ", r)
        cmplen = min(len(reg_trace_ref[r]), len(reg_trace[r]))
        for i in range(cmplen):
            ref_event = reg_trace_ref[r][i]
            act_event = reg_trace[r][i]
            ref_lineno, ref_pc, ref_result = ref_event
            act_lineno, act_pc, act_result = act_event
            if (ref_pc != act_pc):
                print("Line", ref_lineno, "(REF)", act_lineno, "(ACTUAL)",
                        "PC mismatch")
            elif (ref_result != act_result):
                print("Line", ref_lineno, "(REF)", act_lineno, "(ACTUAL)",
                        "Result mismatch:", i,
                        "<-", ref_result, "(REF)", act_result, "(ACTUAL)")
            #print(ref_event)
            #print(act_event)
        totalcmp = totalcmp + cmplen

    print("Done,", totalcmp, "writeback entry compared.")


if __name__ == "__main__":
    main()