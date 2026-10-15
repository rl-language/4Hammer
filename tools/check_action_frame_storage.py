"""Audit action declarations, nesting and generated context-frame multiplicity.

The wrapper is inspected as ctypes metadata without loading/calling native code.
The constructor graph and fully delegated calls establish serial game lifetimes;
completed result lifetimes remain a manual/code-regression responsibility.
"""
import argparse
import collections
import ctypes
import importlib.util
import json
from pathlib import Path
import re


def metadata(path):
    class MetadataOnly:
        def __getattr__(self, name):
            def unavailable(*args):
                raise RuntimeError('Unexpected native call during layout audit: ' + name)
            return unavailable
    original = ctypes.CDLL
    try:
        ctypes.CDLL = lambda *args, **kwargs: MetadataOnly()
        spec = importlib.util.spec_from_file_location('frame_layout_audit', path)
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        return module
    finally:
        ctypes.CDLL = original


def frame_counts(type_, frames, cache):
    if type_ in cache:
        return cache[type_].copy()
    result = collections.Counter()
    if getattr(type_, '__name__', '') in frames:
        result[type_.__name__] += 1
    if issubclass(type_, ctypes.Array):
        result.update({name: count * type_._length_
                       for name, count in frame_counts(type_._type_, frames, cache).items()})
    elif hasattr(type_, '_fields_'):
        for field in type_._fields_:
            result.update(frame_counts(field[1], frames, cache))
    cache[type_] = result.copy()
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--wrapper', type=Path, required=True)
    parser.add_argument('--output', type=Path,
                        help='Write the complete declaration/lifetime inventory')
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[1]
    actions, producers, functions = {}, {}, collections.defaultdict(list)
    for path in sorted((root / 'src').rglob('*.rl')):
        source = path.read_text()
        # Ordinary helpers may construct a child without returning its frame.
        # Follow their bodies too, including multiline signatures and overloads.
        for header in re.finditer(r'^fun(?:<[^\n]+>)? (\w+)\([\s\S]*?\)(?: -> [^\n]+)?:\n', source, re.M):
            tail = source[header.end():]
            end = re.search(r'^\S', tail, re.M)
            functions[header[1]].append(tail[:end.start()] if end else tail)
        for header in re.finditer(r'^act (\w+)\(([\s\S]*?)\) -> (\w+):\n', source, re.M):
            tail = source[header.end():]
            end = re.search(r'^\S', tail, re.M)
            body = tail[:end.start()] if end else tail
            assert not re.search(r'^\s*subaction(?!\*)\b', body, re.M), header[1]
            assert header[3] not in actions, ('Duplicate frame declaration', header[3])
            actions[header[3]] = dict(function=header[1], frame=header[3],
                                     source=str(path.relative_to(root)),
                                     line=source[:header.start()].count('\n') + 1,
                                     body=body)
            producers[header[1]] = header[3]
    def called_frames(body, visited):
        result = set()
        # Ignore comments and strings so prose/example calls are not edges.
        body = re.sub(r'"[^"\n]*"|#[^\n]*', '', body)
        for name in re.findall(r'(?<!\.)\b(\w+)\(', body):
            if name in producers:
                result.add(producers[name])
            elif name in functions and name not in visited:
                for helper in functions[name]:
                    result.update(called_frames(helper, visited | {name}))
        return result
    graph = {}
    for frame, action in actions.items():
        graph[frame] = called_frames(action['body'], set())
    def descendants(frame, seen):
        for child in graph[frame]:
            if child not in seen:
                seen.add(child)
                descendants(child, seen)
        return seen
    for frame in actions:
        assert frame not in descendants(frame, set()), ('Nested re-entry', frame)
    module = metadata(args.wrapper.resolve())
    counts = frame_counts(module.Game, actions, {})
    slots = dict(re.findall(r'^    (\w+) (\w+)$',
                           (root / 'src/action_frames.rl').read_text(), re.M))
    slots.update(Attack='attack', RerollableDice='current_roll',
                 RerollableDicePair='current_pair_roll')
    for frame in slots:
        assert counts[frame] == 1, (frame, counts[frame])
    duplicated = {frame: count for frame, count in counts.items() if count > 1}
    assert not duplicated, ('Unshared game frame copies', duplicated)
    rows = []
    for frame, action in sorted(actions.items()):
        row = {key: value for key, value in action.items() if key != 'body'}
        row.update(game_copies=counts[frame], native_bytes=ctypes.sizeof(getattr(module, frame)),
                   storage=('Board.' + ('shared_actions.' if frame not in
                            ('Attack', 'RerollableDice', 'RerollableDicePair') else '')
                            + slots[frame]) if frame in slots else 'single parent/root',
                   nested_reentry=False, calls=sorted(graph[frame]))
        rows.append(row)
    if args.output:
        args.output.write_text(json.dumps(rows, indent=2) + '\n')
    print(json.dumps(dict(result='PASS', actions_audited=len(actions),
                          context_slots=len(slots), game_bytes=ctypes.sizeof(module.Game),
                          board_bytes=ctypes.sizeof(module.Board), duplicate_frames=0)))


if __name__ == '__main__':
    main()
