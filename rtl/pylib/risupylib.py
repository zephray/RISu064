import math
from risuconsts import *
from risutypes import *
import copy

def reverse(type):
    reversed = copy.deepcopy(type)
    for entry in reversed:
        if entry[0] == "i":
            entry[0] = "o"
        elif entry[0] == "o":
            entry[0] = "i"
        # Don't touch io
    return reversed

def handshake(type):
    result = copy.deepcopy(type)
    result.append(["i", "valid"])
    result.append(["o", "ready"])
    return result

def _get_pin(entry):
    if len(entry) == 3:
        direction, name, size = entry
        width = f" [{size-1}:0] "
    else:
        direction, name = entry
        width = " "
    return direction, width, name

def gen_port(prefix, type, reg=True, last_comma=True, count=1):
    for i in range(count):
        postfix = "" if count == 1 else str(i)
        out = "" # Save into string so last comma could be easily stripped
        dir_map = {
            "i": "input",
            "o": "output",
            "io": "inout"
        }
        for entry in type:
            direction, width, name = _get_pin(entry)
            if reg and direction == "o":
                vartype = " reg"
            else:
                vartype = " wire"
            out += dir_map[direction] + vartype + width + prefix + "_" + name + postfix + ",\n"
        if i == count - 1:
            if not last_comma:
                out = out[:-2]
            else:
                out = out[:-1] # Remove trailing new line
        print(out, end="")

def gen_wire(prefix, type, count=1):
    for i in range(count):
        postfix = "" if count == 1 else str(i)
        for entry in type:
            _, width, name = _get_pin(entry)
            print("wire" + width + prefix + "_" + name + postfix + ";")

def gen_connect(port_prefix, type, wire_prefix="", last_comma=True, count=1):
    if wire_prefix == "":
        wire_prefix = port_prefix
    for i in range(count):
        postfix = "" if count == 1 else str(i)
        out = ""
        for entry in type:
            _, width, name = _get_pin(entry)
            out += "." + port_prefix + "_" + name + postfix + "(" + wire_prefix + "_" + name + postfix + "),\n"
        if i == count - 1:
            if not last_comma:
                out = out[:-2]
            else:
                out = out[:-1] # Remove trailing new line
        print(out, end="")

def gen_cat(type, prefix):
    out = "{"
    for entry in type:
        _, _, name = _get_pin(entry)
        out += prefix + "_" + name + ","
    out = out[:-1] + "}"
    print(out, end="")

def count_bits(type):
    bits = 0
    for entry in type:
        if len(entry) == 3:
            _, _, size = entry
        else:
            size = 1
        bits += size
    print(bits, end="")

# Test stuff
if __name__ == '__main__':
    gen_port(dec_common_t)