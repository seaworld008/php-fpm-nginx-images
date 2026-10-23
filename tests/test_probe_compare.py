import io
import tempfile
import unittest
from contextlib import redirect_stdout
from pathlib import Path

try:
    from tools import probe_compare as pc
except ImportError:
    pc = None

BEFORE = (
    'https\t443\ta.example.com\t/\t200\t10000\ttext/html\t\n'
    'https\t443\ta.example.com\t/__x.html\t404\t5157\ttext/html\t\n'
    'http\t80\ta.example.com\t/\t301\t169\ttext/html\thttps://a.example.com/\n'
    'https\t443\tb.example.com\t/\t502\t157\ttext/html\t\n'
)


class ProbeCompareTests(unittest.TestCase):
    def setUp(self):
        self.assertIsNotNone(pc, 'probe_compare implementation is not present')
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)

    def write(self, name, text):
        p = Path(self.tmp.name) / name
        p.write_text(text, encoding='utf-8')
        return str(p)

    def test_identical_results(self):
        rows = pc.load(io.StringIO(BEFORE))
        self.assertEqual(pc.differences(rows, rows), [])

    def test_small_size_drift_is_tolerated(self):
        after = BEFORE.replace('\t10000\t', '\t10300\t')
        self.assertEqual(pc.differences(pc.load(io.StringIO(BEFORE)), pc.load(io.StringIO(after))), [])

    def test_status_redirect_and_missing_rows_are_reported(self):
        lines = BEFORE.splitlines()
        after = '\n'.join([lines[0],                                                   # unchanged
                           lines[2].replace('https://a.example.com/', 'https://other/'),  # redirect changed
                           lines[3].replace('\t502\t', '\t200\t')]) + '\n'             # status changed; lines[1] missing
        diffs = pc.differences(pc.load(io.StringIO(BEFORE)), pc.load(io.StringIO(after)))
        kinds = sorted(d[0] for d in diffs)
        self.assertEqual(kinds, ['changed', 'changed', 'missing'])

    def test_main_exit_code(self):
        a = self.write('a.tsv', BEFORE)
        b = self.write('b.tsv', BEFORE.replace('\t200\t10000', '\t500\t10000'))
        with redirect_stdout(io.StringIO()) as out:
            self.assertEqual(pc.main([a, a]), 0)
            self.assertEqual(pc.main([a, b]), 1)
        self.assertIn('不同 1 条', out.getvalue())


if __name__ == '__main__':
    unittest.main()
