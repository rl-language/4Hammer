"""Run the state/selector regression against freshly built native bindings."""
import argparse
import os
from pathlib import Path
import shutil
import subprocess
import tempfile


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--build-path', type=Path, required=True,
                        help='Directory containing matching librules.so and librlcrules.so')
    parser.add_argument('--godot', default='godot')
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[1]
    with tempfile.TemporaryDirectory(prefix='4hammer-godot-') as directory:
        project = Path(directory)
        for filename in ('librules.so', 'librlcrules.so'):
            shutil.copy2(args.build_path / filename, project / filename)
        shutil.copy2(root / 'scripts/Rules.gd', project / 'Rules.gd')
        shutil.copy2(root / 'scripts/MultipleChoises.gd', project / 'MultipleChoises.gd')
        shutil.copy2(root / 'scripts/InteractionManager.gd', project / 'InteractionManager.gd')
        shutil.copy2(root / 'tests/godot_state.gd', project / 'validate.gd')
        (project / 'project.godot').write_text(
            'config_version=5\n[application]\nconfig/name="State regression"\n'
            '[autoload]\nGlobalRules="*res://Rules.gd"\n')
        (project / 'rules.gdextension').write_text(
            '[configuration]\nentry_symbol="rules_library_init"\n'
            'compatibility_minimum="4.3"\n[libraries]\n'
            'linux.debug.x86_64="res://librules.so"\n'
            'linux.release.x86_64="res://librules.so"\n')
        (project / '.godot').mkdir()
        (project / '.godot/extension_list.cfg').write_text('res://rules.gdextension\n')
        environment = os.environ.copy()
        for variable, name in (('XDG_CONFIG_HOME', 'config'),
                               ('XDG_DATA_HOME', 'data'), ('XDG_CACHE_HOME', 'cache')):
            location = project / name
            location.mkdir()
            environment[variable] = str(location)
        try:
            result = subprocess.run(
                [args.godot, '--headless', '--path', str(project), '--script', 'validate.gd'],
                env=environment, text=True, capture_output=True, timeout=30)
        except subprocess.TimeoutExpired as error:
            for output in (error.stdout, error.stderr):
                if output:
                    print(output.decode() if isinstance(output, bytes) else output,
                          end='', flush=True)
            raise
        output = result.stdout + result.stderr
        print(output, end='', flush=True)
        if result.returncode or 'PASS: Godot schema exports' not in output or 'ERROR:' in output or 'instances leaked' in output:
            raise RuntimeError('Godot state/selector regression failed')


if __name__ == '__main__':
    main()
