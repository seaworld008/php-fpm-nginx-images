import json
from pathlib import Path
import tempfile
import unittest

try:
    from tools import check_docs
except ImportError:
    check_docs = None


class DocsTests(unittest.TestCase):
    def setUp(self):
        self.assertIsNotNone(check_docs, 'documentation checker is not present')
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)

    def write(self, name, text):
        p = self.root / name
        p.parent.mkdir(parents=True, exist_ok=True)
        p.write_text(text)

    def test_valid_relative_link(self):
        self.write('README.md', '[guide](docs/a.md)\n')
        self.write('docs/a.md', '# title\n')
        self.assertEqual(check_docs.validate(self.root), [])

    def test_missing_relative_link(self):
        self.write('README.md', '[guide](missing.md)\n')
        self.assertTrue(check_docs.validate(self.root))

    def test_external_and_anchor_not_fetched(self):
        self.write('README.md', '[external](https://example.invalid/a) [anchor](#title)\n')
        self.assertEqual(check_docs.validate(self.root), [])

    def test_code_block_links_ignored(self):
        self.write('README.md', '```text\n[not-a-link](missing.md)\n```\n')
        self.assertEqual(check_docs.validate(self.root), [])

    def test_unclosed_fence_detected(self):
        self.write('README.md', '```text\nunclosed\n')
        self.assertTrue(check_docs.validate(self.root))

    def test_invalid_json_detected(self):
        self.write('example.json', '{broken}\n')
        self.assertTrue(check_docs.validate(self.root))

    def test_valid_json(self):
        self.write('example.json', json.dumps({'status': 'UNVERIFIED'}))
        self.assertEqual(check_docs.validate(self.root), [])

    def test_link_outside_repository_rejected(self):
        self.write('README.md', '[outside](../outside.md)\n')
        self.assertTrue(check_docs.validate(self.root))

    def test_fragment_does_not_break_file_link(self):
        self.write('README.md', '[guide](a.md#section)\n')
        self.write('a.md', '# Section\n')
        self.assertEqual(check_docs.validate(self.root), [])


if __name__ == '__main__':
    unittest.main()
