"""Exercise the real publishing shell with fake Apple/GitHub tools.

These checks prove orchestration and failure gates, not Apple notarization.
All files and operations stay in a disposable fixture directory.
"""
from pathlib import Path
import json
import os
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
FAKE_TOOL = r'''
import json,os,sys
from pathlib import Path
name=Path(sys.argv[0]).name
args=sys.argv[1:]
with open(os.environ['FIXTURE_EVENTS'],'a') as log:
    log.write(json.dumps([name]+args)+'\n')
failure=os.environ.get('FAIL_STAGE','')
if name=='python3':
    if args[0]=='-': os.execv(os.environ['REAL_PYTHON'],[os.environ['REAL_PYTHON']]+args)
    if args[0]=='Tools/release.py' and args[1]=='package':
        folder=Path('dist/release');folder.mkdir(parents=True,exist_ok=True)
        for ext in ['dmg','zip']: (folder/('MouseMint-1.7.0-arm64.'+ext)).write_bytes(b'fixture archive')
    if args[0]=='Tools/release.py' and args[1]=='validate-feed' and failure=='feed-validate': sys.exit(1)
elif name=='ditto': Path(args[-1]).write_bytes(b'fixture notarization archive')
elif name=='xcrun':
    if args[:2]==['notarytool','submit']:
        kind='dmg' if args[2].endswith('.dmg') else 'app'
        print(json.dumps({'id':'fixture-'+kind,'message':'Successfully uploaded file','name':Path(args[2]).name}))
    elif args[:2]==['notarytool','wait']:
        kind=args[2].removeprefix('fixture-')
        if failure==kind+'-timeout': sys.exit(75)
        status='Invalid' if failure==kind+'-notary' else 'Accepted'
        print(json.dumps({'id':args[2],'status':status}))
    elif args[:2]==['stapler','staple']:
        kind='dmg' if args[2].endswith('.dmg') else 'app'
        if failure==kind+'-staple': sys.exit(1)
elif name=='generate_appcast':
    if failure=='feed-sign': sys.exit(1)
    Path('.build/update-feed/appcast.xml').write_text('<rss>fixture signed feed</rss>')
elif name=='gh':
    if args[:2]==['release','view']: print('Fixture release notes')
    if args[:2]==['release','upload'] and failure=='upload': sys.exit(1)
'''

class PublishPipelineTests(unittest.TestCase):
    def exercise(self, failure=''):
        with tempfile.TemporaryDirectory(prefix='MouseMint publish tests ') as temporary:
            folder=Path(temporary);bin=folder/'bin';bin.mkdir()
            tool=bin/'fake-tool'
            tool.write_text('#!'+sys.executable+'\n'+FAKE_TOOL);tool.chmod(0o755)
            for name in ['python3','ditto','xcrun','codesign','spctl','gh']:
                (bin/name).symlink_to(tool)
            generator=folder/'Tuist/.build/artifacts/sparkle/Sparkle/bin/generate_appcast'
            generator.parent.mkdir(parents=True);generator.symlink_to(tool)
            (folder/'dist/MouseMint.app').mkdir(parents=True)
            events=folder/'events.jsonl'
            environment=dict(os.environ,PATH=str(bin)+os.pathsep+os.environ['PATH'],
                GITHUB_ACTIONS='true',RELEASE_TAG='v1.7.0',SIGNING_IDENTITY='fixture-identity',
                SPARKLE_PRIVATE_KEY='fixture-not-a-real-key',RUNNER_TEMP=str(folder/'runner'),
                APPLE_NOTARY_KEY_ID='fixture-key-id',APPLE_NOTARY_ISSUER_ID='fixture-issuer',
                GH_REPO='MSavisko/MouseMint',GH_TOKEN='fixture-not-a-real-token',
                FIXTURE_EVENTS=str(events),REAL_PYTHON=sys.executable,FAIL_STAGE=failure)
            result=subprocess.run(['/bin/bash',str(ROOT/'Tools/publish.sh')],cwd=folder,
                env=environment,capture_output=True,text=True)
            trace=[json.loads(line) for line in events.read_text().splitlines()]
            checksums=(folder/'dist/release/SHA256SUMS.txt').exists()
            receipts={path.name:path.read_text() for path in (folder/'.build/notarization').glob('*.json')}
            return result,trace,checksums,receipts

    def test_only_successful_pipeline_uploads_then_publishes(self):
        result,events,checksums,_=self.exercise()
        self.assertEqual(result.returncode,0,result.stderr)
        notarizations=[event for event in events if event[:3]==['xcrun','notarytool','submit']]
        self.assertEqual(len(notarizations),2)
        self.assertTrue(checksums)
        release_actions=[event[2] for event in events if event[:2]==['gh','release']]
        self.assertEqual(release_actions,['view','upload','edit'])
        publish=events[-1]
        self.assertEqual(publish[:4],['gh','release','edit','v1.7.0'])
        self.assertIn('--draft=false',publish)
        self.assertIn('--latest',publish)

    def test_failures_leave_the_release_unpublished(self):
        for stage in ['app-notary','app-staple','dmg-notary','dmg-staple','feed-sign','feed-validate','upload']:
            with self.subTest(stage=stage):
                result,events,_,_=self.exercise(stage)
                self.assertNotEqual(result.returncode,0)
                self.assertFalse(any(event[:3]==['gh','release','edit'] for event in events))
                if stage!='upload':
                    self.assertFalse(any(event[:3]==['gh','release','upload'] for event in events))

    def test_timeout_keeps_submission_id_without_publishing_or_resubmitting(self):
        for kind in ['app','dmg']:
            with self.subTest(kind=kind):
                result,events,_,receipts=self.exercise(kind+'-timeout')
                self.assertNotEqual(result.returncode,0)
                self.assertIn('Notarization submitted: fixture-'+kind,result.stdout)
                receipt=json.loads(receipts[kind+'.submission.json'])
                self.assertEqual(receipt['id'],'fixture-'+kind)
                waits=[event for event in events if event[:4]==['xcrun','notarytool','wait','fixture-'+kind]]
                self.assertEqual(len(waits),1)
                submissions=[event for event in events if event[:3]==['xcrun','notarytool','submit']]
                self.assertEqual(len(submissions),1 if kind=='app' else 2)
                self.assertFalse(any(event[:3] in [['gh','release','upload'],['gh','release','edit']] for event in events))

if __name__=='__main__': unittest.main()
