"""Counterexamples for the static architecture check, not gameplay tests."""
from pathlib import Path
import importlib.util
import tempfile
import unittest

SPEC = importlib.util.spec_from_file_location('architecture_check', Path(__file__).resolve().parents[1] / 'tools/architecture_check.py')
checker = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(checker)


class ArchitectureTests(unittest.TestCase):
    def run_case(self, files):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            for name, text in files.items():
                path = root / name
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_text(text, encoding='utf-8')
            return checker.check(root)

    def test_comments_strings_and_exports_are_not_reads(self):
        result = self.run_case({'main.lua': '-- mod.OtherTestAPI.read()\nlocal s="mod.OtherTestAPI.foo"\nmod.OwnTestAPI = {}'})
        self.assertTrue(result['passed'], result)

    def test_actual_test_interface_read_rejected(self):
        result = self.run_case({'main.lua': 'local q=mod.OtherTestAPI.Read'})
        self.assertIn('production TestAPI read', result['errors'][0])

    def test_colon_and_bracket_test_interface_reads(self):
        for source in ('mod:OtherTestAPI()', 'local x=mod["OtherTestAPI"].Read'):
            self.assertFalse(self.run_case({'main.lua': source})['passed'])

    def test_long_string_shorthand_loads_are_followed(self):
        for source in ('include [[missing]]', 'include [=[missing]=]', 'include([==[missing]==])'):
            result = self.run_case({'main.lua': source})
            self.assertIn('missing runtime module: missing.lua', result['errors'])

    def test_legacy_return_exception_is_specific(self):
        files = {'main.lua': "include('scripts.features.big_dog_bark')", 'scripts/features/big_dog_bark.lua': 'Neverbirth.BigDogBarkTestAPI={}\nreturn Neverbirth.BigDogBarkTestAPI'}
        self.assertTrue(self.run_case(files)['passed'])
        files['scripts/features/big_dog_bark.lua'] += '\nlocal x=Neverbirth.OtherTestAPI.Query'
        self.assertFalse(self.run_case(files)['passed'])

    def test_missing_transitive_dependency(self):
        result = self.run_case({'main.lua': "include('scripts.a')", 'scripts/a.lua': "include('missing')"})
        self.assertIn('missing runtime module: missing.lua', result['errors'])

    def test_runtime_reverse_dependency(self):
        result = self.run_case({'main.lua': "include('scripts.runtime.a')", 'scripts/runtime/a.lua': "include('scripts.features.x')", 'scripts/features/x.lua': 'return {}'})
        self.assertTrue(any('reverse dependency' in e for e in result['errors']))

    def test_dynamic_load_remains_incomplete(self):
        result = self.run_case({'main.lua': 'include(moduleName)'})
        self.assertFalse(result['passed'])
        self.assertEqual(len(result['limitations']), 1)

    def test_unscoped_root_and_paused_character(self):
        result = self.run_case({'main.lua': 'local data=persistence.GetRoot', 'content/players.xml': '<players><player name="Paused"/></players>'})
        self.assertEqual(len(result['errors']), 2)

    def test_temporary_probe(self):
        result = self.run_case({'main.lua': '-- BATCH21_NATIVE_PROBE\nreturn {}'})
        self.assertIn('temporary native probe', result['errors'][0])


if __name__ == '__main__':
    unittest.main()
