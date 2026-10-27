"""Check the actual disk image contents without launching the app."""
from pathlib import Path
import subprocess
import sys
import tempfile

with tempfile.TemporaryDirectory(prefix='MouseMint verify ') as temporary:
    mount=Path(temporary)
    subprocess.run(['hdiutil','attach','-readonly','-nobrowse','-mountpoint',str(mount),sys.argv[1]],check=True)
    try:
        assert (mount/'MouseMint.app/Contents/MacOS/MouseMint').is_file(), 'App is missing'
        assert (mount/'Applications').is_symlink(), 'Applications shortcut is missing'
        assert (mount/'Applications').readlink()==Path('/Applications'), 'Wrong install destination'
        assert (mount/'.background/background.png').is_file(), 'DMG background is missing'
        assert (mount/'.DS_Store').is_file(), 'Finder layout is missing'
        subprocess.run(['codesign','--verify','--deep','--strict',str(mount/'MouseMint.app')],check=True)
    finally:
        subprocess.run(['hdiutil','detach',str(mount)],check=True)
print('DMG app, signature, Applications shortcut, background and Finder layout passed.')
