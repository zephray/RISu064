from siliconcompiler.core import Chip
from siliconcompiler.floorplan import Floorplan

def load_def(fn):
    pins = []
    with open(fn) as f:
        in_pins = False
        pin_name = ""
        pin_net = ""
        pin_dir = ""
        pin_use = ""
        pin_layer = ""
        pin_ori = ""
        pin_fixed = False
        pin_x = 0
        pin_y = 0
        pin_w = 0
        pin_h = 0
        for l in f:
            if not in_pins:
                if l.strip().startswith("PINS"):
                    in_pins = True
            else:
                la = l.strip().split()
                if l.strip().startswith("END PINS"):
                    in_pins = False
                elif l.strip().startswith("-"):
                    pin_name = la[1]
                    pin_net = la[4]
                    pin_dir = la[7]
                    pin_use = la[10]
                elif ("LAYER" in l):
                    pin_layer = la[2]
                    pin_w = abs(int(la[8]) - int(la[4]))
                    pin_h = abs(int(la[9]) - int(la[5]))
                elif ("PLACED" in l) or ("FIXED" in l):
                    pin_x = int(la[3])
                    pin_y = int(la[4])
                    pin_x = pin_x - pin_w / 2
                    pin_y = pin_y - pin_h / 2
                    pin_ori = la[6]
                    pin_fixed = la[1] == "FIXED"
                    pin = {
                            "name": pin_name,
                            "layer": pin_layer,
                            "net": pin_net,
                            "net": pin_name,
                            "dir": pin_dir,
                            "use": pin_use,
                            "ori": pin_ori,
                            "fixed": pin_fixed,
                            "x": pin_x,
                            "y": pin_y,
                            "w": pin_w,
                            "h": pin_h}
                    pins.append(pin)
    return pins

def load_lef(fn):
    pins = []
    with open(fn) as f:
        in_pin = False
        pin_name = ""
        pin_dir = ""
        pin_use = ""
        pin_layer = ""
        pin_x = 0
        pin_y = 0
        pin_w = 0
        pin_h = 0
        for l in f:
            la = l.strip().split()
            if not in_pin:
                if (len(la) != 0) and (la[0] == "PIN"):
                    in_pin = True
                    pin_name = la[1]
            else:
                if la[0] == "DIRECTION":
                    pin_dir = la[1]
                elif la[0] == "USE":
                    pin_use = la[1]
                elif la[0] == "LAYER":
                    pin_layer = la[1]
                elif la[0] == "RECT":
                    x1 = float(la[1])
                    y1 = float(la[2])
                    x2 = float(la[3])
                    y2 = float(la[4])
                    pin_x = round(x1 * 1000)
                    pin_y = round(y1 * 1000)
                    pin_w = round((x2 - x1) * 1000)
                    pin_h = round((y2 - y1) * 1000)
                elif la[0] == "END":
                    in_pin = False
                    pin = {
                            "name": pin_name,
                            "layer": pin_layer,
                            "net": pin_name,
                            "net": pin_name,
                            "dir": pin_dir,
                            "use": pin_use,
                            "ori": "N",
                            "fixed": False,
                            "x": pin_x,
                            "y": pin_y,
                            "w": pin_w,
                            "h": pin_h}
                    pins.append(pin)
    return pins

def place_pins(pins, fp):
    for pin in pins:
        # w = pin["w"]
        # h = pin["h"]
        # if ((pin["x"] < 2917000) and (pin["y"] < 2700000)):
        #     if (w < h):
        #         h = h + 5000
        #     else:
        #         w = w + 5000
        fp.place_pins(
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

def import_pins_from_def(fp, fn):
    pins = load_def(fn)
    place_pins(pins, fp)

def import_pins_from_lef(fp, fn):
    pins = load_lef(fn)
    place_pins(pins, fp)

def main():
    # Don't use user_analog_project_wrapper.def, it's broken as of MPW-7
    #pins = load_def("user_analog_project_wrapper.def")
    pins = load_lef("user_analog_project_wrapper_empty.lef")
    for pin in pins:
        print(pin)

if __name__ == "__main__":
    main()