import struct
import sys
import os

formats = ([b'PK', "zip"], [b'OPPOENCRYPT!', "ozip"], [b'7z', "7z"], [b'\x53\xef', 'ext', 1080],
           [b'\x3a\xff\x26\xed', "sparse"], [b'\xe2\xe1\xf5\xe0', "erofs", 1024], [b"CrAU", "payload"],
           [b"AVB0", "vbmeta"], [b'\xd7\xb7\xab\x1e', "dtbo"],
           [b'\xd0\x0d\xfe\xed', "dtb"], [b"MZ", "exe"], [b".ELF", 'elf'],
           [b"ANDROID!", "boot"], [b"VNDRBOOT", "vendor_boot"],
           [b'AVBf', "avb_foot"], [b'BZh', "bzip2"],
           [b'CHROMEOS', 'chrome'], [b'\x1f\x8b', "gzip"],
           [b'\x1f\x9e', "gzip"], [b'\x02\x21\x4c\x18', "lz4_legacy"],
           [b'\x03\x21\x4c\x18', 'lz4'], [b'\x04\x22\x4d\x18', 'lz4'],
           [b'\x1f\x8b\x08\x00\x00\x00\x00\x00\x02\x03', "zopfli"], [b'\xfd7zXZ', 'xz'],
           [b']\x00\x00\x00\x04\xff\xff\xff\xff\xff\xff\xff\xff', 'lzma'], [b'\x02!L\x18', 'lz4_lg'],
           [b'\x89PNG', 'png'], [b"LOGO!!!!", 'logo', 4000], [b'\x28\xb5\x2f\xfd', 'zstd'])


def gettype(file) -> str:
    if not os.path.exists(file):
        return "fne"

    def compare(header: bytes, number: int = 0) -> int:
        with open(file, 'rb') as f:
            f.seek(number)
            return f.read(len(header)) == header

    def is_super(fil) -> any:
        with open(fil, 'rb') as file_:
            buf = bytearray(file_.read(4))
            if len(buf) < 4:
                return False
            file_.seek(0, 0)

            while buf[0] == 0x00:
                buf = bytearray(file_.read(1))
            try:
                file_.seek(-1, 1)
            except BaseException or Exception:
                return False
            buf += bytearray(file_.read(4))
        return buf[1:] == b'\x67\x44\x6c\x61'

    try:
        if is_super(file):
            return 'super'
    except IndexError:
        ...
    for f_ in formats:
        if len(f_) == 2:
            if compare(f_[0]):
                return f_[1]
        elif len(f_) == 3:
            if compare(f_[0], f_[2]):
                return f_[1]
    try:
        if LOGO_DUMPER(file, str(None)).check_img(file):
            return 'logo'
    except AssertionError:
        ...
    except struct.error:
        ...
    return "unknown"


class DUMPCFG:
    blksz = 0x1 << 0xc
    headoff = 0x4000
    magic = b"LOGO!!!!"
    imgnum = 0
    imgblkoffs = []
    imgblkszs = []


class BMPHEAD:
    def __init__(self, buf: bytes = None):  # Read bytes buf and use this struct to parse
        assert buf is not None, f"buf Should be bytes not {type(buf)}"
        # print(buf)
        self.structstr = "<H6I"
        (
            self.magic,
            self.fsize,
            self.reserved,
            self.hsize,
            self.dib,
            self.width,
            self.height,
        ) = struct.unpack(self.structstr, buf)


class XIAOMI_BLKSTRUCT:
    def __init__(self, buf: bytes):
        self.structstr = "2I"
        (
            self.img_offset,
            self.blksz,
        ) = struct.unpack(self.structstr, buf)


class LOGO_DUMPER:
    def __init__(self, img: str, out: str, dir__: str = "pic"):
        self.magic = None
        self.out = out
        self.img = img
        self.dir = dir__
        self.struct_str = "<8s"
        self.cfg = DUMPCFG()
        self.check_img(img)

    def check_img(self, img: str):
        assert os.access(img, os.F_OK), f"{img} does not found!"
        with open(img, 'rb') as f:
            f.seek(self.cfg.headoff, 0)
            self.magic = struct.unpack(
                self.struct_str, f.read(struct.calcsize(self.struct_str))
            )[0]
            while True:
                m = XIAOMI_BLKSTRUCT(f.read(8))
                if m.img_offset != 0:
                    self.cfg.imgblkszs.append(m.blksz << 0xc)
                    self.cfg.imgblkoffs.append(m.img_offset << 0xc)
                    self.cfg.imgnum += 1
                else:
                    break
        assert self.magic == b"LOGO!!!!", "File does not match xiaomi logo magic!"
        return True


if __name__ == '__main__':
    print(gettype(sys.argv[1]))
