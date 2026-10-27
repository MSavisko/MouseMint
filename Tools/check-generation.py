"""Check real Tuist cache invalidation after metadata-only changes in a clean copy."""
from pathlib import Path
import base64
import os
import re
import shutil
import subprocess
import tempfile

root=Path(__file__).resolve().parents[1]
files=subprocess.check_output(['git','ls-files','--cached','--others','--exclude-standard','-z'],cwd=root).decode().split('\0')
with tempfile.TemporaryDirectory(prefix='MouseMint metadata ') as temporary:
    folder=Path(temporary)
    for name in files:
        source=root/name
        if name and source.is_file():
            destination=folder/name; destination.parent.mkdir(parents=True,exist_ok=True)
            shutil.copy2(source,destination)
    subprocess.run(['mise','trust',str(folder/'mise.toml')],check=True,stdout=subprocess.DEVNULL)
    original=(folder/'version.txt').read_text().strip()
    public=(folder/'Resources/SparklePublicKey.txt').read_text().strip()
    major,minor,patch=map(int,original.split('.'))
    next_version=f'{major}.{minor}.{patch+1}'
    changed_public=base64.b64encode(base64.b64decode(public)[::-1]).decode()
    for version,key in [(original,public),(next_version,changed_public)]:
        (folder/'version.txt').write_text(version+'\n')
        (folder/'Resources/SparklePublicKey.txt').write_text(key+'\n')
        result=subprocess.run(['mise','run','generate'],cwd=folder,capture_output=True,text=True)
        if result.returncode: raise RuntimeError(result.stdout+result.stderr)
        project=(folder/'MouseMint.xcodeproj/project.pbxproj').read_text()
        def settings(name): return [match.strip().strip('"') for match in re.findall(rf'{name} = (.+);',project)]
        assert set(settings('MARKETING_VERSION'))=={version},'Tuist reused a stale version'
        assert set(settings('SPARKLE_PUBLIC_KEY'))=={key},'Tuist reused a stale verification key'
print('Clean generation in a path with spaces and metadata-only cache invalidation passed.')
