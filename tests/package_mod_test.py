from pathlib import Path
import sys
import tempfile
import unittest
import zipfile

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'tools'))
from package_mod import package


class PackageTests(unittest.TestCase):
    def test_real_archive_has_dependencies_and_no_report_or_test_code(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder) / 'source'
            for name, data in {'main.lua': "include('scripts.feature')", 'scripts/feature.lua': 'return {}', 'content/players.xml': '<players/>', 'resources/gfx/a.png': 'asset', 'reports/archive/main.lua': 'error()', 'tests/fixture.lua': 'error()'}.items():
                path = root / name
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_text(data)
            result = package(root, Path(folder) / 'candidate')
            self.assertEqual(result['fileCount'], 4)
            self.assertTrue(result['extractionHashesMatch'])
            with zipfile.ZipFile(Path(folder) / 'candidate/neverbrith.zip') as archive:
                self.assertIn('scripts/feature.lua', archive.namelist())
                self.assertNotIn('tests/fixture.lua', archive.namelist())
            with self.assertRaisesRegex(ValueError, 'output already exists'):
                package(root, Path(folder) / 'candidate')

    def test_missing_required_module_blocks_package(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder) / 'source'
            root.mkdir()
            (root / 'main.lua').write_text("include('missing')")
            with self.assertRaisesRegex(ValueError, 'architecture preflight'):
                package(root, Path(folder) / 'candidate')
            self.assertFalse((Path(folder) / 'candidate').exists())


if __name__ == '__main__':
    unittest.main()
