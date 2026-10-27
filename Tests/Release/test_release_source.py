"""Check release trust rules with real temporary Git history and a fake GitHub API."""
from pathlib import Path
import json
import os
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
FAKE_GH = r'''
import json,os,sys
args=sys.argv[1:]
if args[0]=='api':
    print('Drafts are unavailable through the tag endpoint',file=sys.stderr)
    sys.exit(1)
if os.environ['FIXTURE_SCENARIO']=='missing': sys.exit(1)
values={'isDraft':os.environ['FIXTURE_SCENARIO']!='published',
        'targetCommitish':os.environ['FIXTURE_TARGET']}
field=args[args.index('--json')+1]
value=values[field]
print(value if isinstance(value,str) else json.dumps(value))
'''


class ReleaseSourceTests(unittest.TestCase):
    def exercise(self, scenario='draft'):
        with tempfile.TemporaryDirectory(prefix='MouseMint release source tests ') as temporary:
            folder=Path(temporary)
            def git(*arguments):
                return subprocess.check_output(['git',*arguments],cwd=folder,text=True,stderr=subprocess.DEVNULL).strip()
            git('init','--initial-branch=main')
            def commit(message):
                git('-c','user.name=MouseMint Tests','-c','user.email=fixture@example.invalid',
                    'commit','--allow-empty','-m',message)
                return git('rev-parse','HEAD')
            trusted=commit('Trusted release source')
            git('update-ref','refs/remotes/origin/main',trusted)
            current=commit('Unmerged change') if scenario=='outside-main' else trusted
            bin=folder/'bin';bin.mkdir()
            gh=bin/'gh';gh.write_text('#!'+sys.executable+'\n'+FAKE_GH);gh.chmod(0o755)
            environment=dict(os.environ,PATH=str(bin)+os.pathsep+os.environ['PATH'],
                RELEASE_TAG='v1.7.0',GH_REPO='fixture/repository',
                RELEASE_COMMIT='0'*40 if scenario=='wrong-checkout' else current,
                FIXTURE_TARGET='f'*40 if scenario=='wrong-target' else current,
                FIXTURE_SCENARIO=scenario)
            return subprocess.run(['/bin/bash',str(ROOT/'Tools/verify-release-source.sh')],
                cwd=folder,env=environment,capture_output=True,text=True)

    def test_owned_draft_at_the_exact_main_commit_is_accepted(self):
        result=self.exercise()
        self.assertEqual(result.returncode,0,result.stderr)

    def test_untrusted_or_non_draft_release_is_rejected(self):
        for scenario in ['outside-main','wrong-checkout','wrong-target','published','missing']:
            with self.subTest(scenario=scenario):
                result=self.exercise(scenario)
                self.assertNotEqual(result.returncode,0)


if __name__=='__main__': unittest.main()
