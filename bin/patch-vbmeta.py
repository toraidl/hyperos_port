#!/usr/bin/env python

import os
import sys

if __name__ == "__main__":

    # if a correct argument is not provided
    if len(sys.argv) != 2:
        sys.exit(f"Usage: {sys.argv[0]} <vbmeta-image>")

    try:
        fd = os.open(sys.argv[1], os.O_RDWR)
    except OSError:
        sys.exit(f"Error reading file: {sys.argv[1]}\nFile not modified. Exiting...")

    if os.read(fd, 4) != b"AVB0":
        sys.exit("Error: The provided image is not a valid vbmeta image.\nFile not modified. Exiting...")

    # set the disable-verity and disable-verification flags at offset 123
    try:
        os.lseek(fd, 123, os.SEEK_SET)
        os.write(fd, b'\x03')
    except OSError:
        sys.exit("Error: Failed when patching the vbmeta image.\nExiting...")

    os.close(fd)
    print("Patching successful.")
