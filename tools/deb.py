# Packs a Debian package from a layout folder (DEBIAN/control plus files) without dpkg-deb.
# Gzip members and ustar tars, which the dpkg in iOS 6 Cydia reads.
import io, os, sys, tarfile, time

def tar(root, skip):
    buf = io.BytesIO()
    with tarfile.open(fileobj=buf, mode='w:gz', format=tarfile.USTAR_FORMAT) as t:
        for d, dirs, files in os.walk(root):
            dirs[:] = sorted(x for x in dirs if os.path.join(d, x) != skip)
            for name in [''] + sorted(files):
                p = os.path.join(d, name) if name else d
                if p == skip or name == '.DS_Store': continue
                ti = t.gettarinfo(p, './' + os.path.relpath(p, root).lstrip('.').lstrip('/'))
                ti.uid = ti.gid = 0; ti.uname = ti.gname = 'root'
                ti.mode = 0o755 if ti.isdir() or name.endswith('.dylib') else 0o644
                t.addfile(ti, open(p, 'rb') if ti.isfile() else None)
    return buf.getvalue()

def ar_member(name, data):
    h = f'{name:<16}{int(time.time()):<12}0     0     100644  {len(data):<10}`\n'.encode()
    return h + data + (b'\n' if len(data) % 2 else b'')

layout, out = sys.argv[1], sys.argv[2]
control = tar(os.path.join(layout, 'DEBIAN'), None)
data = tar(layout, os.path.join(layout, 'DEBIAN'))
with open(out, 'wb') as f:
    f.write(b'!<arch>\n' + ar_member('debian-binary', b'2.0\n') + ar_member('control.tar.gz', control) + ar_member('data.tar.gz', data))
