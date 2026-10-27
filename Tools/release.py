"""Validate release metadata and build a Finder drag-and-drop disk image."""
from pathlib import Path
import argparse
import base64
import json
import plistlib
import re
import struct
import subprocess
import tempfile
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
SPARKLE = '{http://www.andymatuschak.org/xml-namespaces/sparkle}'
REPOSITORY = 'https://github.com/MSavisko/MouseMint'


def versions(tag, source_version):
    match = re.fullmatch(r'v(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)', tag)
    if not match or tag[1:] != source_version.strip():
        raise ValueError('Release tag must exactly match version.txt (vMAJOR.MINOR.PATCH)')
    major, minor, patch = map(int, match.groups())
    if major >= 9900 or minor >= 100 or patch >= 100:
        raise ValueError('Version exceeds Apple bundle-version component limits')
    # Keep every Sparkle-enabled build above the legacy build number 8.
    return tag[1:], f'{major + 100}.{minor}.{patch}'


def validate_appcast(path, tag, archive, expected_build):
    items = ET.parse(path).findall('./channel/item')
    if len(items) != 1:
        raise ValueError('Expected exactly one current release in the feed')
    item = items[0]; enclosure = item.find('enclosure')
    if enclosure is None:
        raise ValueError('Missing update enclosure')
    expected_url = f'{REPOSITORY}/releases/download/{tag}/{archive.name}'
    version = item.findtext(SPARKLE+'version') or enclosure.get(SPARKLE+'version')
    short_version = item.findtext(SPARKLE+'shortVersionString') or enclosure.get(SPARKLE+'shortVersionString')
    if (enclosure.get('url') != expected_url or enclosure.get('length') != str(archive.stat().st_size)
            or version != expected_build or short_version != tag[1:]):
        raise ValueError('Appcast does not describe this exact release archive')
    try:
        signature = base64.b64decode(enclosure.get(SPARKLE+'edSignature', ''), validate=True)
    except ValueError as error:
        raise ValueError('Invalid update signature encoding') from error
    if len(signature) != 64:
        raise ValueError('Missing Ed25519 update signature')


def run(*args):
    subprocess.run([str(arg) for arg in args], check=True)


def validate_app(app, tag):
    version, build = versions(tag, (ROOT/'version.txt').read_text())
    info = plistlib.loads((app/'Contents/Info.plist').read_bytes())
    expected = {'CFBundleIdentifier':'io.github.msavisko.mousemint',
                'CFBundleShortVersionString':version, 'CFBundleVersion':build,
                'LSMinimumSystemVersion':'13.0', 'LSUIElement':True,
                'SUFeedURL':REPOSITORY+'/releases/latest/download/appcast.xml'}
    for key, value in expected.items():
        if info.get(key) != value: raise ValueError(f'Unexpected app metadata: {key}')
    public_key = (ROOT/'Resources/SparklePublicKey.txt').read_text().strip()
    if info.get('SUPublicEDKey') != public_key or len(base64.b64decode(public_key, validate=True)) != 32:
        raise ValueError('Missing or mismatched Sparkle public key')
    if not (app/'Contents/Frameworks/Sparkle.framework').is_dir():
        raise ValueError('Sparkle is not embedded')
    for name in ['LICENSE', 'THIRD_PARTY_NOTICES.md']:
        if (app/'Contents/Resources'/name).read_bytes() != (ROOT/name).read_bytes():
            raise ValueError(f'Missing or stale resource: {name}')
    return version, build


def package(app, output, tag):
    version, _ = versions(tag, (ROOT/'version.txt').read_text())
    output.mkdir(parents=True, exist_ok=True)
    name = f'MouseMint-{version}-arm64'
    with tempfile.TemporaryDirectory(prefix='MouseMint DMG ') as temporary:
        folder = Path(temporary); content=folder/'content'; content.mkdir()
        run('ditto', app, content/'MouseMint.app')
        (content/'Applications').symlink_to('/Applications')
        background = content/'.background'; background.mkdir()
        run('xcrun','swift',ROOT/'Tools/DMGBackground.swift',background/'background.png')
        if struct.unpack('>II',(background/'background.png').read_bytes()[16:24]) != (680,420):
            raise RuntimeError('Installer background does not match the Finder layout size')
        writable=folder/'layout.dmg'; mount=folder/'mount'; mount.mkdir()
        run('hdiutil','create','-ov','-format','UDRW','-fs','HFS+','-volname','MouseMint','-srcfolder',content,writable)
        run('hdiutil','attach','-nobrowse','-mountpoint',mount,writable)
        try:
            run('osascript',ROOT/'Tools/DMGLayout.applescript',mount)
            if not (mount/'.DS_Store').exists(): raise RuntimeError('Finder did not save the DMG layout')
        finally:
            run('hdiutil','detach',mount)
        run('hdiutil','convert',writable,'-format','UDZO','-imagekey','zlib-level=9','-ov','-o',output/(name+'.dmg'))
    run('ditto','-c','-k','--sequesterRsrc','--keepParent',app,output/(name+'.zip'))


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('command',choices=['version','validate-app','package','validate-feed'])
    parser.add_argument('--tag',required=True)
    parser.add_argument('--app',type=Path,default=ROOT/'dist/MouseMint.app')
    parser.add_argument('--output',type=Path,default=ROOT/'dist/release')
    parser.add_argument('--feed',type=Path)
    parser.add_argument('--archive',type=Path)
    args=parser.parse_args()
    version,build=versions(args.tag,(ROOT/'version.txt').read_text())
    if args.command=='version': print(json.dumps({'version':version,'build':build,'tag':args.tag}))
    elif args.command=='validate-app': validate_app(args.app,args.tag)
    elif args.command=='package': package(args.app.resolve(),args.output.resolve(),args.tag)
    else: validate_appcast(args.feed,args.tag,args.archive,build)

if __name__=='__main__': main()
