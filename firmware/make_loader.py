#!/usr/bin/env python3

from pathlib import Path
import struct
import sys

INPUT_BIN = Path("firmware.bin")
OUTPUT_TCL = Path("load_firmware.tcl")

BASE_ADDRESS = 0x00000000
RESULT_ADDRESS = 0x00001000
RESULT_WORDS = 8
WORDS_PER_WRITE = 64

if not INPUT_BIN.exists():
    sys.exit("ERROR: firmware.bin does not exist. Compile first.")

image = INPUT_BIN.read_bytes()

# AXI/System Console writes 32-bit words. Pad the final word if needed.
padding = (-len(image)) % 4
image += b"\x00" * padding

words = struct.unpack("<{}I".format(len(image) // 4), image)

with OUTPUT_TCL.open("w", newline="\n") as f:
    f.write("# Auto-generated from firmware.bin. Do not edit manually.\n")
    f.write("# Run this from Intel System Console with SW0 UP.\n\n")

    f.write("if {[info exists m]} {\n")
    f.write("    catch {close_service master $m}\n")
    f.write("}\n\n")

    f.write("set masters [get_service_paths master]\n")
    f.write("if {[llength $masters] == 0} {\n")
    f.write('    error "No JTAG-to-Avalon master found. Check FPGA and Refresh Connections."\n')
    f.write("}\n\n")

    f.write('set m [claim_service master [lindex $masters 0] ""]\n')
    f.write('puts "JTAG master claimed: $m"\n\n')

    # Clear the JTAG-visible result table.
    zeros = " ".join(["0x00000000"] * RESULT_WORDS)
    f.write(
        "master_write_32 $m 0x{:08X} {{{}}}\n\n".format(
            RESULT_ADDRESS, zeros
        )
    )

    # Write firmware in 64-word blocks.
    for start in range(0, len(words), WORDS_PER_WRITE):
        chunk = words[start:start + WORDS_PER_WRITE]
        address = BASE_ADDRESS + start * 4
        data = " ".join("0x{:08X}".format(word) for word in chunk)

        f.write(
            "master_write_32 $m 0x{:08X} {{{}}}\n".format(
                address, data
            )
        )

    f.write("\nputs \"Firmware loaded successfully.\"\n")
    f.write(
        'puts "Bytes loaded: {}  |  32-bit words: {}"\n'.format(
            len(image), len(words)
        )
    )
    f.write('puts "First four firmware words:"\n')
    f.write("puts [master_read_32 $m 0x00000000 4]\n")
    f.write('puts "Result table cleared at 0x00001000."\n')
    f.write('puts "Keep this System Console open; $m is ready for reads."\n')

print("Created:", OUTPUT_TCL)
print("Firmware bytes:", len(image))
print("Words written:", len(words))