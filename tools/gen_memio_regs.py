#!/usr/bin/env python3
"""Generate the OSD firmware's memio_regs.h from rtl/common/zines_pkg.sv.

Copies the section between "// @c-export begin" and "// @c-export end":
    localparam logic [N:0] NAME = W'hXX;   // comment  ->  #define NAME 0xXX  // comment
Comment lines and blank lines are copied as they are. Anything else in the
section is an error, so the package and the C header cannot silently diverge.

Usage: gen_memio_regs.py <zines_pkg.sv> <memio_regs.h>
"""
import re
import sys

LOCALPARAM = re.compile(
    r"^\s*localparam\s+logic\s*\[(\d+):0\]\s+(\w+)\s*=\s*(\d+)'([hdb])([0-9a-fA-F_]+)\s*;\s*(//.*)?$")
COMMENT = re.compile(r"^\s*(//.*)$")


def convert(lines, source):
    out = []
    inside = False
    for number, line in enumerate(lines, 1):
        text = line.rstrip("\n")
        if "@c-export begin" in text:
            inside = True
            continue
        if "@c-export end" in text:
            return out
        if not inside:
            continue

        match = LOCALPARAM.match(text)
        if match:
            msb, name, _, base, digits, comment = match.groups()
            value = int(digits.replace("_", ""), {"h": 16, "d": 10, "b": 2}[base])
            hex_digits = (int(msb) + 4) // 4
            define = f"#define {name:<24} 0x{value:0{hex_digits}X}"
            out.append(f"{define:<40} {comment}" if comment else define)
        elif COMMENT.match(text):
            out.append(COMMENT.match(text).group(1))
        elif not text.strip():
            out.append("")
        else:
            sys.exit(f"{source}:{number}: unsupported line in @c-export section: {text.strip()}")
    sys.exit(f"{source}: missing '// @c-export begin' / '// @c-export end'")


def main():
    if len(sys.argv) != 3:
        sys.exit(__doc__)
    source, target = sys.argv[1], sys.argv[2]
    with open(source, encoding="utf-8") as f:
        body = convert(f.readlines(), source)
    while body and not body[-1]:
        body.pop()

    header = [
        "// memio_regs.h: generated from rtl/common/zines_pkg.sv by tools/gen_memio_regs.py.",
        "// Do not edit; change the package instead.",
        "#ifndef MEMIO_REGS_H",
        "#define MEMIO_REGS_H",
        *body,
        "",
        "#endif // MEMIO_REGS_H",
        "",
    ]
    with open(target, "w", encoding="utf-8") as f:
        f.write("\n".join(header))


if __name__ == "__main__":
    main()
