import os
import re
import sys
from string import printable
import struct

import ext4

if os.name == 'nt':
    from ctypes.wintypes import LPCSTR, DWORD
    from stat import FILE_ATTRIBUTE_SYSTEM
    from ctypes import windll
from timeit import default_timer as dti

SPARSE_HEADER_MAGIC = 0xED26FF3A
SPARSE_HEADER_SIZE = 28
SPARSE_CHUNK_HEADER_SIZE = 12


class SparseHeader(object):
    def __init__(self, buffer):
        fmt = '<I4H4I'
        (
            self.magic,  # 0xed26ff3a
            self.major_version,  # (0x1) - reject images with higher major versions
            self.minor_version,  # (0x0) - allow images with higer minor versions
            self.file_hdr_sz,  # 28 bytes for first revision of the file format
            self.chunk_hdr_sz,  # 12 bytes for first revision of the file format
            self.blk_sz,  # block size in bytes, must be a multiple of 4 (4096)
            self.total_blks,  # total blocks in the non-sparse output image
            self.total_chunks,  # total chunks in the sparse input image
            self.image_checksum  # CRC32 checksum of the original data, counting "don't care"
        ) = struct.unpack(fmt, buffer[0:struct.calcsize(fmt)])


class SparseChunkHeader(object):
    """
        Following a Raw or Fill or CRC32 chunk is data.
        For a Raw chunk, it's the data in chunk_sz * blk_sz.
        For a Fill chunk, it's 4 bytes of the fill data.
        For a CRC32 chunk, it's 4 bytes of CRC32
     """

    def __init__(self, buffer):
        fmt = '<2H2I'
        (
            self.chunk_type,  # 0xCAC1 -> raw; 0xCAC2 -> fill; 0xCAC3 -> don't care */
            self.reserved,
            self.chunk_sz,  # in blocks in output image * /
            self.total_sz,  # in bytes of chunk input file including chunk header and data * /
        ) = struct.unpack(fmt, buffer[0:struct.calcsize(fmt)])


class SparseImage:
    def __init__(self, fd):
        self._fd = fd
        self.header = None

    def check(self):
        self._fd.seek(0)
        self.header = SparseHeader(self._fd.read(SPARSE_HEADER_SIZE))
        return False if self.header.magic != SPARSE_HEADER_MAGIC else True

    def _read_data(self, chunk_data_size: int):
        if self.header.chunk_hdr_sz > SPARSE_CHUNK_HEADER_SIZE:
            self._fd.seek(self.header.chunk_hdr_sz - SPARSE_CHUNK_HEADER_SIZE, 1)

        return self._fd.read(chunk_data_size)

    def unsparse(self):
        if not self.header:
            self._fd.seek(0)
            self.header = SparseHeader(self._fd.read(SPARSE_HEADER_SIZE))
        chunks = self.header.total_chunks
        self._fd.seek(self.header.file_hdr_sz - SPARSE_HEADER_SIZE, 1)
        unsparse_file_dir = os.path.dirname(self._fd.name)
        unsparse_file = os.path.join(unsparse_file_dir,
                                     "{}.unsparse.img".format(os.path.splitext(os.path.basename(self._fd.name))[0]))
        with open(str(unsparse_file), 'wb') as out:
            sector_base = 82528
            output_len = 0
            while chunks > 0:
                chunk_header = SparseChunkHeader(self._fd.read(SPARSE_CHUNK_HEADER_SIZE))
                sector_size = (chunk_header.chunk_sz * self.header.blk_sz) >> 9
                chunk_data_size = chunk_header.total_sz - self.header.chunk_hdr_sz
                if chunk_header.chunk_type == 0xCAC1:
                    data = self._read_data(chunk_data_size)
                    len_data = len(data)
                    if len_data == (sector_size << 9):
                        out.write(data)
                        output_len += len_data
                        sector_base += sector_size
                else:
                    if chunk_header.chunk_type == 0xCAC2:
                        data = self._read_data(chunk_data_size)
                        len_data = sector_size << 9
                        out.write(struct.pack("B", 0) * len_data)
                        output_len += len(data)
                        sector_base += sector_size
                    else:
                        if chunk_header.chunk_type == 0xCAC3:
                            data = self._read_data(chunk_data_size)
                            len_data = sector_size << 9
                            out.write(struct.pack("B", 0) * len_data)
                            output_len += len(data)
                            sector_base += sector_size
                        else:
                            len_data = sector_size << 9
                            out.write(struct.pack("B", 0) * len_data)
                            sector_base += sector_size
                chunks -= 1
        return unsparse_file


def simg2img(path):
    with open(path, 'rb') as fd:
        if SparseImage(fd).check():
            print('Sparse image detected.')
            print('Process conversion to non sparse image...')
            unsparse_file = SparseImage(fd).unsparse()
            print('Result:[ok]')
        else:
            print(f"{path} not Sparse.Skip!")
    try:
        if os.path.exists(unsparse_file):
            os.remove(path)
            os.rename(unsparse_file, path)
    except Exception as e:
        print(e)


class Extractor:
    def __init__(self):
        self.BASE_DIR_ = None
        self.CONFING_DIR = None
        self.DIR = None
        self.FileName = ""
        self.OUTPUT_IMAGE_FILE = ""
        self.EXTRACT_DIR = ""
        self.BLOCK_SIZE = 4096
        self.context = []
        self.fs_config = []

    @staticmethod
    def __out_name(file_path, out=1):
        name = file_path if out == 1 else os.path.basename(file_path).rsplit('.', 1)[0]
        name = name.split('-')[0]
        name = name.split(' ')[0]
        name = name.split('+')[0]
        name = name.split('{')[0]
        name = name.split('(')[0]
        return name

    @staticmethod
    def __append(msg, log):
        if not os.path.isfile(log) and not os.path.exists(log):
            with open(log, 'tw', encoding='utf-8'):
                ...
        with open(log, 'a', newline='\n') as file:
            print(msg, file=file)

    @staticmethod
    def __get_perm(arg):
        if len(arg) < 9 or len(arg) > 10:
            return
        if len(arg) > 8:
            arg = arg[1:]
        oor, ow, ox, gr, gw, gx, wr, ww, wx = list(arg)
        o, g, w, s = 0, 0, 0, 0
        if oor == 'r':
            o += 4
        if ow == 'w':
            o += 2
        if ox == 'x':
            o += 1
        if ox == 'S':
            s += 4
        if ox == 's':
            s += 4
            o += 1
        if gr == 'r':
            g += 4
        if gw == 'w':
            g += 2
        if gx == 'x':
            g += 1
        if gx == 'S':
            s += 2
        if gx == 's':
            s += 2
            g += 1
        if wr == 'r':
            w += 4
        if ww == 'w':
            w += 2
        if wx == 'x':
            w += 1
        if wx == 'T':
            s += 1
        if wx == 't':
            s += 1
            w += 1
        return f'{s}{o}{g}{w}'

    def __ext4extractor(self):
        fs_config_file = self.FileName + '_fs_config'
        fuk_symbols = '\\^$.|?*+(){}[]'
        contexts = self.CONFING_DIR + os.sep + self.FileName + "_file_contexts"

        def scan_dir(root_inode, root_path=""):
            for entry_name, entry_inode_idx, entry_type in root_inode.open_dir():
                if entry_name in ['.', '..'] or entry_name.endswith(' (2)'):
                    continue
                entry_inode = root_inode.volume.get_inode(entry_inode_idx, entry_type)
                entry_inode_path = root_path + '/' + entry_name
                mode = self.__get_perm(entry_inode.mode_str)
                uid = entry_inode.inode.i_uid
                gid = entry_inode.inode.i_gid
                cap = ''
                link_target = ''
                tmp_path = self.DIR + entry_inode_path
                spaces_file = self.BASE_DIR_ + 'config' + os.sep + self.FileName + '_space.txt'
                for f, e in entry_inode.xattrs():
                    if f == 'security.selinux':
                        t_p_mkc = tmp_path
                        for fuk_ in fuk_symbols:
                            t_p_mkc = t_p_mkc.replace(fuk_, '\\' + fuk_)
                        self.context.append(f"/{t_p_mkc} {e.decode('utf8')[:-1]}")
                    elif f == 'security.capability':
                        r = struct.unpack('<5I', e)
                        if r[1] > 65535:
                            cap = hex(int(f'{r[3]:04x}{r[1]:04x}', 16))
                        else:
                            cap = hex(int(f'{r[3]:04x}{r[2]:04x}{r[1]:04x}', 16))
                        cap = f" capabilities={cap}"
                if entry_inode.is_symlink:
                    try:
                        link_target = entry_inode.open_read().read().decode("utf8")
                    except Exception and BaseException:
                        link_target_block = int.from_bytes(entry_inode.open_read().read(), "little")
                        link_target = root_inode.volume.read(link_target_block * root_inode.volume.block_size,
                                                             entry_inode.inode.i_size).decode("utf8")
                if tmp_path.find(' ', 1, len(tmp_path)) > 0:
                    self.__append(tmp_path, spaces_file)
                    self.fs_config.append(
                        f"{tmp_path.replace(' ', '_')} {uid} {gid} {mode}{cap} {link_target}")
                else:
                    self.fs_config.append(
                        f'{self.DIR + entry_inode_path} {uid} {gid} {mode}{cap} {link_target}')
                if entry_inode.is_dir:
                    dir_target = self.EXTRACT_DIR + entry_inode_path.replace(' ', '_').replace('"', '')
                    if dir_target.endswith('.') and os.name == 'nt':
                        dir_target = dir_target[:-1]
                    if not os.path.isdir(dir_target):
                        os.makedirs(dir_target)
                    if os.name == 'posix' and os.geteuid() == 0:
                        os.chmod(dir_target, int(mode, 8))
                        os.chown(dir_target, uid, gid)
                    scan_dir(entry_inode, entry_inode_path)
                elif entry_inode.is_file:
                    file_target = self.EXTRACT_DIR + entry_inode_path.replace(' ', '_').replace('"', '')
                    if os.name == 'nt':
                        file_target = file_target.replace('\\', '/')
                    try:
                        with open(file_target, 'wb') as out:
                            out.write(entry_inode.open_read().read())
                    except Exception and BaseException as e:
                        print(f'[E] Cannot Write {file_target}, Because of {e}')
                    if os.name == 'posix' and os.geteuid() == 0:
                        os.chmod(file_target, int(mode, 8))
                        os.chown(file_target, uid, gid)
                elif entry_inode.is_symlink:
                    target = self.EXTRACT_DIR + entry_inode_path.replace(' ', '_')
                    try:
                        if os.path.islink(target) or os.path.isfile(target):
                            try:
                                os.remove(target)
                            finally:
                                ...
                        if os.name == 'posix':
                            os.symlink(link_target, target)
                        if os.name == 'nt':
                            with open(target.replace('/', os.sep), 'wb') as out:
                                out.write(b'!<symlink>' + link_target.encode('utf-16') + b'\x00\x00')
                                try:
                                    windll.kernel32.SetFileAttributesA(LPCSTR(target.encode()),
                                                                       DWORD(FILE_ATTRIBUTE_SYSTEM))
                                except Exception as e:
                                    print(e.__str__())
                    except BaseException and Exception:
                        try:
                            if link_target and all(c_ in printable for c_ in link_target):
                                if os.name == 'posix':
                                    os.symlink(link_target, target)
                                if os.name == 'nt':
                                    with open(target.replace('/', os.sep), 'wb') as out:
                                        out.write(b'!<symlink>' + link_target.encode('utf-16') + b'\x00\x00')
                                    try:
                                        windll.kernel32.SetFileAttributesA(LPCSTR(target.encode()),
                                                                           DWORD(FILE_ATTRIBUTE_SYSTEM))
                                    except Exception as e:
                                        print(e.__str__())
                        finally:
                            ...

        dir_my = self.CONFING_DIR + os.sep
        if not os.path.isdir(dir_my):
            os.makedirs(dir_my)
        self.__append(os.path.getsize(self.OUTPUT_IMAGE_FILE), dir_my + self.FileName + '_size.txt')
        with open(self.OUTPUT_IMAGE_FILE, 'rb') as file:
            dir_r = self.__out_name(os.path.basename(self.OUTPUT_IMAGE_FILE).rsplit('.', 1)[0])
            self.DIR = dir_r
            scan_dir(ext4.Volume(file).root)
            self.fs_config.insert(0, '/ 0 2000 0755' if dir_r == 'vendor' else '/ 0 0 0755')
            self.fs_config.insert(1, f'{dir_r} 0 2000 0755' if dir_r == 'vendor' else '/lost+found 0 0 0700')
            self.fs_config.insert(2 if dir_r == 'system' else 1, f'{dir_r} 0 0 0755')
            self.__append('\n'.join(self.fs_config), self.CONFING_DIR + os.sep + fs_config_file)
            if self.context:
                self.context.sort()
                for c in self.context:
                    if re.search('lost..found', c):
                        self.context.insert(0, '/ ' + c.split()[1])
                        self.context.insert(1, '/' + dir_r + '(/.*)? ' + c.split()[1])
                        self.context.insert(2, f'/{dir_r} {c.split()[1]}')
                        self.context.insert(3, '/' + dir_r + '/lost+\\found ' + c.split()[1])
                        break

                for c in self.context:
                    if re.search('/system/system/build..prop ', c):
                        self.context.insert(3, '/lost+\\found' + ' u:object_r:rootfs:s0')
                        self.context.insert(4, '/' + dir_r + '/' + dir_r + '(/.*)? ' + c.split()[1])
                        break
                self.__append('\n'.join(self.context), contexts)

    @staticmethod
    def fix_moto(input_file):
        if not os.path.exists(input_file):
            return
        output_file = input_file + "_"
        if os.path.exists(output_file):
            try:
                os.remove(output_file)
            finally:
                ...
        with open(input_file, 'rb') as f:
            data = f.read(500000)
        if not re.search(b'\x4d\x4f\x54\x4f', data):
            return
        offset = 0
        for i in re.finditer(b'\x53\xEF', data):
            if data[i.start() - 1080] == 0:
                offset = i.start() - 1080
                break
        if offset > 0:
            with open(output_file, 'wb') as o, open(input_file, 'rb') as f:
                data = f.read(15360)
                if data:
                    o.write(data)
        try:
            os.remove(input_file)
            os.rename(output_file, input_file)
        finally:
            ...

    def main(self, target: str, output_dir: str, target_type: str = 'img'):
        self.BASE_DIR_ = output_dir + os.sep
        self.EXTRACT_DIR = os.path.realpath(os.path.dirname(output_dir)) + os.sep + self.__out_name(
            os.path.basename(output_dir))
        self.OUTPUT_IMAGE_FILE = (os.path.realpath(os.path.dirname(target)) + os.sep) + os.path.basename(target)
        self.FileName = self.__out_name(os.path.basename(target), out=0)
        if sys.argv.__len__() == 3:
            self.CONFING_DIR = sys.argv[2] + os.sep + 'config'
        else:
            self.CONFING_DIR = os.path.dirname(output_dir) + os.sep + 'config'
        if target_type == 's_img':
            simg2img(target)
            target_type = 'img'
        if target_type == 'img':
            with open(os.path.abspath(self.OUTPUT_IMAGE_FILE), 'rb') as f:
                data = f.read(500000)
            if re.search(b'\x4d\x4f\x54\x4f', data):
                print(".....MOTO structure! Fixing.....")
                self.fix_moto(os.path.abspath(self.OUTPUT_IMAGE_FILE))
            print("Extracting %s --> %s" % (os.path.basename(target), os.path.basename(self.EXTRACT_DIR)))
            start = dti()
            self.__ext4extractor()
            print("Done! [%s]" % (dti() - start))


if __name__ == '__main__':
    if sys.argv.__len__() == 3:
        Extractor().main(sys.argv[1], (sys.argv[2] + os.sep + os.path.basename(sys.argv[1]).split('.')[0]))
    else:
        if sys.argv.__len__() == 2:
            if not os.path.isdir("out"):
                os.makedirs("out")
            Extractor().main(sys.argv[1], "out" + os.sep + os.path.basename(sys.argv[1]).split('.')[0])
