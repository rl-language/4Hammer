"""Host-runner regressions; no compiler or Godot process is needed."""
import contextlib
import ctypes
import io
import json
from pathlib import Path
import sys
import tempfile
from types import SimpleNamespace
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / 'tools'))
import ctest_rules as runner


class DiscoveryTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.root = Path(self.directory.name)
        self.patch = patch.object(runner, 'PYTHON_TESTS', self.root)
        self.patch.start()

    def tearDown(self):
        self.patch.stop()
        self.directory.cleanup()

    def baseline(self, source):
        (self.root / 'baseline.py').write_text(source)
        return runner.discover('baseline')

    def test_discovery_does_not_import_or_run_test_code(self):
        names = self.baseline('raise RuntimeError("must not execute")\ndef test_case():\n    return True\n')
        self.assertEqual(names, ['test_case'])

    def test_empty_and_duplicate_suites_are_rejected(self):
        for source in ['', 'def test_case():\n    return True\ndef test_case():\n    return True\n']:
            with self.subTest(source=source), self.assertRaises(RuntimeError):
                self.baseline(source)

    def test_required_and_optional_parameters_are_rejected(self):
        for parameters in ['x', 'x=True', '*args', '**kwargs', '*, x=True']:
            with self.subTest(parameters=parameters), self.assertRaises(RuntimeError):
                self.baseline(f'def test_case({parameters}):\n    return True\n')

    def test_discrepancy_manifest_must_match(self):
        (self.root / 'known_discrepancies.py').write_text('def test_case():\n    return False\n')
        with patch.object(runner, 'manifest', return_value={}), self.assertRaises(RuntimeError):
            runner.discover('discrepancies')

    def test_missing_artifacts_fail_without_running_a_build(self):
        with self.assertRaisesRegex(RuntimeError, 'Missing Godot build artifact'):
            runner.load(self.root / 'missing.py', self.root / 'missing.so')


class ResultTests(unittest.TestCase):
    def execute(self, function, suite='baseline'):
        module = SimpleNamespace(test_case=function)
        with patch.object(runner.importlib, 'import_module', return_value=module), \
             patch.object(runner, 'manifest', return_value={'test_case': {'source': 'fixture rule'}}), \
             contextlib.redirect_stdout(io.StringIO()), contextlib.redirect_stderr(io.StringIO()):
            return runner.execute(suite, 'test_case')

    def test_pass_and_false_assertion(self):
        self.assertEqual(self.execute(lambda: True), 0)
        self.assertEqual(self.execute(lambda: False), 1)

    def test_non_bool_result_fails(self):
        self.assertEqual(self.execute(lambda: 1), 1)
        self.assertEqual(self.execute(lambda: None), 1)

    def test_expected_failure_and_unexpected_pass(self):
        self.assertEqual(self.execute(lambda: False, 'discrepancies'), 77)
        self.assertEqual(self.execute(lambda: True, 'discrepancies'), 1)

    def test_exception_is_failure_even_for_known_discrepancy(self):
        def broken_fixture():
            raise ValueError('broken fixture')
        self.assertEqual(self.execute(broken_fixture, 'discrepancies'), 1)

    def test_python_test_edits_change_results_without_touching_the_library(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            library = root / 'existing-godot.so'
            library.write_bytes(b'unchanged compiled game')
            before = library.stat().st_mtime_ns
            path = root / 'test_case.py'
            for value, expected in [(True, 0), (False, 1)]:
                path.write_text(f'def test_case():\n    return {value}\n')
                module = {}
                exec(compile(path.read_text(), str(path), 'exec'), module)
                self.assertEqual(self.execute(module['test_case']), expected)
                self.assertEqual(library.read_bytes(), b'unchanged compiled game')
                self.assertEqual(library.stat().st_mtime_ns, before)


class ArrayDispatchTests(unittest.TestCase):
    def test_wrong_length_or_element_type_is_rejected_before_native_call(self):
        from bindings import Symbols
        calls = []
        def rl_fixture__bool_13_r_bool(array):
            calls.append(array)
            return True
        function = rl_fixture__bool_13_r_bool
        symbols = Symbols()
        symbols.module = SimpleNamespace(wrappers={'fixture': [function]}, signatures={function: [bool, list]})
        self.assertTrue(symbols.call('fixture', (ctypes.c_bool * 13)()))
        self.assertEqual(len(calls), 1)
        for array in [(ctypes.c_bool * 2)(), (ctypes.c_longlong * 13)()]:
            with self.subTest(array=type(array).__name__), self.assertRaises(TypeError):
                symbols.call('fixture', array)
        self.assertEqual(len(calls), 1)


if __name__ == '__main__':
    unittest.main()
