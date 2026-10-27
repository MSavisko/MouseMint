import importlib.util
from pathlib import Path
import tempfile
import unittest

SPEC = importlib.util.spec_from_file_location('release', Path(__file__).resolve().parents[2] / 'Tools/release.py')
release = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(release)

class ReleaseTests(unittest.TestCase):
    def test_tag_must_match_the_reviewed_source_version(self):
        self.assertEqual(release.versions('v1.7.0', '1.7.0'), ('1.7.0', '101.7.0'))
        for tag in ['1.7.0', 'v1.7.0-beta', 'v1.7.0;touch x', 'v1.07.0', 'v1.7.1']:
            with self.subTest(tag=tag), self.assertRaises(ValueError):
                release.versions(tag, '1.7.0')

    def test_build_versions_increase_and_follow_apple_component_limits(self):
        builds = [release.versions('v'+v,v)[1] for v in ['1.6.1','1.7.0','2.0.0']]
        self.assertGreater(tuple(map(int,builds[0].split('.'))), (8,))
        self.assertEqual(builds, sorted(builds, key=lambda b:tuple(map(int,b.split('.')))))
        for v in ['9900.0.0','1.100.0','1.0.100']:
            with self.assertRaises(ValueError): release.versions('v'+v,v)

    def test_feed_must_describe_the_exact_signed_archive(self):
        with tempfile.TemporaryDirectory() as temp:
            folder=Path(temp); archive=folder/'MouseMint-1.7.0-arm64.zip'; archive.write_bytes(b'zip-fixture')
            feed=folder/'appcast.xml'
            content='''<rss xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle"><channel><item>
            <sparkle:version>101.7.0</sparkle:version><sparkle:shortVersionString>1.7.0</sparkle:shortVersionString>
            <enclosure url="https://github.com/MSavisko/MouseMint/releases/download/v1.7.0/MouseMint-1.7.0-arm64.zip"
            length="11" sparkle:edSignature="'''+('A'*86+'==')+'''" /></item></channel></rss>'''
            feed.write_text(content)
            release.validate_appcast(feed,'v1.7.0',archive,'101.7.0')
            for old,new in [('length="11"','length="1"'),('https://github.com','http://github.com'),('101.7.0','101.6.1'),('v1.7.0/','v1.6.1/'),('sparkle:edSignature','missingSignature')]:
                with self.subTest(mutation=old):
                    feed.write_text(content.replace(old,new))
                    with self.assertRaises(ValueError): release.validate_appcast(feed,'v1.7.0',archive,'101.7.0')


SIGNING_SPEC = importlib.util.spec_from_file_location('signing', Path(__file__).resolve().parents[2] / 'Tools/import-signing.py')
signing = importlib.util.module_from_spec(SIGNING_SPEC)
SIGNING_SPEC.loader.exec_module(signing)

class SigningSetupTests(unittest.TestCase):
    def test_missing_secrets_are_named_without_disclosing_any_value(self):
        with self.assertRaisesRegex(ValueError, 'APPLE_CERTIFICATE_BASE64') as error:
            signing.validate_credentials({'GITHUB_ACTIONS':'true','APPLE_NOTARY_KEY':'DO-NOT-PRINT-THIS'})
        self.assertNotIn('DO-NOT-PRINT-THIS',str(error.exception))

    def test_import_cannot_run_on_the_users_mac(self):
        with self.assertRaisesRegex(ValueError, 'GitHub'):
            signing.validate_credentials({})

if __name__=='__main__': unittest.main()
