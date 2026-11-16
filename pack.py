"""Build an MSIX package from a folder (stored/uncompressed entries)."""
import base64, hashlib, os, struct, sys, zlib, zipfile

src, out = sys.argv[1], sys.argv[2]

def png(path, size, rgb=(0, 120, 215)):
    # Solid blue square with a white "H"-ish block, written without PIL
    rows = []
    for y in range(size):
        row = bytearray([0])
        for x in range(size):
            fx, fy = x / size, y / size
            white = 0.25 < fy < 0.75 and (0.25 < fx < 0.37 or 0.63 < fx < 0.75 or (0.45 < fy < 0.55 and 0.25 < fx < 0.75))
            row += bytes((255, 255, 255) if white else rgb)
        rows.append(bytes(row))
    def chunk(t, d):
        return struct.pack(">I", len(d)) + t + d + struct.pack(">I", zlib.crc32(t + d) & 0xffffffff)
    data = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", size, size, 8, 2, 0, 0, 0)) \
        + chunk(b"IDAT", zlib.compress(b"".join(rows), 9)) + chunk(b"IEND", b"")
    with open(path, "wb") as f:
        f.write(data)

assets = os.path.join(src, "Assets")
png(os.path.join(assets, "StoreLogo.png"), 50)
png(os.path.join(assets, "Square150x150Logo.png"), 150)
png(os.path.join(assets, "Square44x44Logo.png"), 44)

files = []
for root, _, names in os.walk(src):
    for n in sorted(names):
        full = os.path.join(root, n)
        files.append((full, os.path.relpath(full, src).replace(os.sep, "/")))
files.sort(key=lambda f: (f[1] != "AppxManifest.xml", f[1]))  # manifest last-ish is fine; keep deterministic

BLOCK = 65536
bm = ['<?xml version="1.0" encoding="UTF-8"?>',
      '<BlockMap xmlns="http://schemas.microsoft.com/appx/2010/blockmap" '
      'HashMethod="http://www.w3.org/2001/04/xmlenc#sha256">']
exts = set()
for full, arc in files:
    data = open(full, "rb").read()
    lfh = 30 + len(arc.encode())
    bm.append(f'<File Name="{arc.replace("/", chr(92))}" Size="{len(data)}" LfhSize="{lfh}">')
    for i in range(0, max(len(data), 1), BLOCK):
        h = base64.b64encode(hashlib.sha256(data[i:i + BLOCK]).digest()).decode()
        bm.append(f'<Block Hash="{h}"/>')
    bm.append('</File>')
    if arc != "AppxManifest.xml":
        exts.add(arc.rsplit(".", 1)[-1].lower())
bm.append('</BlockMap>')

mime = {"exe": "application/x-msdownload", "png": "image/png", "dll": "application/x-msdownload",
        "xml": "application/vnd.ms-appx.manifest+xml"}
ct = ['<?xml version="1.0" encoding="UTF-8"?>',
      '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">']
for e in sorted(exts):
    ct.append(f'<Default Extension="{e}" ContentType="{mime.get(e, "application/octet-stream")}"/>')
ct += ['<Override PartName="/AppxManifest.xml" ContentType="application/vnd.ms-appx.manifest+xml"/>',
       '<Override PartName="/AppxBlockMap.xml" ContentType="application/vnd.ms-appx.blockmap+xml"/>',
       '</Types>']

with zipfile.ZipFile(out, "w", zipfile.ZIP_STORED) as z:
    for full, arc in files:
        z.write(full, arc)
    z.writestr("AppxBlockMap.xml", "\r\n".join(bm))
    z.writestr("[Content_Types].xml", "\r\n".join(ct))
print("wrote", out)
