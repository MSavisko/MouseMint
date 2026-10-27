"""Import credentials only on the disposable GitHub release runner."""
from pathlib import Path
import base64
import os
import re
import secrets
import subprocess

REQUIRED = ['APPLE_CERTIFICATE_BASE64','APPLE_CERTIFICATE_PASSWORD','APPLE_TEAM_ID',
            'APPLE_NOTARY_KEY','APPLE_NOTARY_KEY_ID','APPLE_NOTARY_ISSUER_ID','SPARKLE_PRIVATE_KEY']


def validate_credentials(environment):
    if environment.get('GITHUB_ACTIONS') != 'true':
        raise ValueError('Signing import is restricted to the disposable GitHub runner')
    missing = [key for key in REQUIRED if not environment.get(key)]
    if missing: raise ValueError('Configure these release secrets: '+', '.join(missing))
    if not re.fullmatch(r'[A-Z0-9]{10}',environment['APPLE_TEAM_ID']):
        raise ValueError('Invalid APPLE_TEAM_ID')


def main():
    validate_credentials(os.environ)
    temporary = Path(os.environ['RUNNER_TEMP'])
    keychain = temporary/'mousemint-release.keychain-db'
    certificate = temporary/'mousemint-certificate.p12'
    notary = temporary/'mousemint-notary.p8'
    os.umask(0o077)
    certificate.write_bytes(base64.b64decode(os.environ['APPLE_CERTIFICATE_BASE64'],validate=True))
    notary.write_text(os.environ['APPLE_NOTARY_KEY'])
    password = secrets.token_urlsafe(32)
    def run(*args): subprocess.run(list(map(str,args)),check=True,stdout=subprocess.DEVNULL)
    run('security','create-keychain','-p',password,keychain)
    run('security','set-keychain-settings','-lut','21600',keychain)
    run('security','unlock-keychain','-p',password,keychain)
    run('security','import',certificate,'-k',keychain,'-P',os.environ['APPLE_CERTIFICATE_PASSWORD'],'-T','/usr/bin/codesign','-T','/usr/bin/security')
    run('security','set-key-partition-list','-S','apple-tool:,apple:,codesign:','-s','-k',password,keychain)
    run('security','list-keychains','-d','user','-s',keychain)
    identities=subprocess.check_output(['security','find-identity','-v','-p','codesigning',str(keychain)],text=True)
    matches=[re.search(r'\b([A-F0-9]{40})\b',line).group(1) for line in identities.splitlines()
             if 'Developer ID Application:' in line and '('+os.environ['APPLE_TEAM_ID']+')' in line]
    if len(matches)!=1: raise ValueError('Expected one valid Developer ID Application identity for APPLE_TEAM_ID')
    with open(os.environ['GITHUB_OUTPUT'],'a') as output: output.write('identity='+matches[0]+'\n')
    certificate.unlink()
    print('Developer ID identity imported into the temporary release keychain.')

if __name__=='__main__':
    try: main()
    except ValueError as error: raise SystemExit(str(error))
