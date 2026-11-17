"""Merge a supplied test manifest into tests/metadata.json; no DB/operation edits."""
import argparse
import json
import sys
from datetime import datetime
from pathlib import Path


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('manifest', type=Path, help='Addition JSON path, relative to current terminal directory')
    parser.add_argument('--metadata', type=Path, help='Target metadata; default: project tests/metadata.json')
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[1]
    path = (args.metadata or root / 'tests' / 'metadata.json').resolve()
    tests_root = path.parent
    project_root = tests_root.parent
    source = args.manifest.resolve()
    data = json.loads(path.read_text(encoding='utf-8-sig'))
    addition_doc = json.loads(source.read_text(encoding='utf-8-sig'))
    if not isinstance(data, dict) or data.get('version') != 1 or not isinstance(data.get('scripts'), list):
        raise ValueError('Target must be version=1 metadata with a scripts list')
    if not isinstance(addition_doc, dict) or not isinstance(addition_doc.get('scripts'), list):
        raise ValueError('Manifest must be a JSON object containing scripts: [...]')
    addition = addition_doc['scripts']
    if not addition:
        raise ValueError('Manifest scripts list is empty')
    seen = set()
    for spec in addition:
        if not isinstance(spec, dict) or not isinstance(spec.get('path'), str):
            raise ValueError('Each entry needs a string path')
        script = (tests_root / spec['path']).resolve()
        if not script.is_relative_to(tests_root) or script.suffix.lower() != '.sql':
            raise ValueError('Invalid SQL path: ' + spec['path'])
        if not script.is_file():
            raise ValueError('Missing SQL: ' + str(script))
        canonical = script.relative_to(tests_root).as_posix()
        spec['path'] = canonical
        if canonical in seen:
            raise ValueError('Duplicate addition path: ' + canonical)
        seen.add(canonical)
        if not isinstance(spec.get('cases'), list) or not spec['cases']:
            raise ValueError('Missing cases: ' + canonical)
        for case in spec['cases']:
            if not isinstance(case, dict) or any(not case.get(k) for k in ('test_id', 'requirement', 'initial_state', 'expected_result')):
                raise ValueError('Incomplete case metadata: ' + canonical)
        mode = spec.get('mode', 'sql')
        if mode not in ('sql', 'negative', 'workflow'):
            raise ValueError('Unknown mode: ' + str(mode))
        if mode == 'workflow':
            steps = spec.get('steps', [spec])
            if not isinstance(steps, list) or not steps:
                raise ValueError('Workflow steps must be a non-empty list')
            for step in steps:
                name = step.get('operation')
                if not isinstance(name, str):
                    raise ValueError('Workflow step missing operation: ' + canonical)
                operation = (project_root / 'operations' / name).resolve()
                if operation.parent != (project_root / 'operations').resolve() or not operation.is_file():
                    raise ValueError('Missing/invalid operation: ' + name)
    # Merge by canonical script path; preserve all unrelated fields and fixtures.
    retained = []
    for spec in data['scripts']:
        canonical = (tests_root / spec['path']).resolve()
        if not canonical.is_relative_to(tests_root):
            raise ValueError('Existing metadata path escapes tests directory')
        if canonical.relative_to(tests_root).as_posix() not in seen:
            retained.append(spec)
    data['scripts'] = retained + addition
    ids = [case['test_id'] for spec in data['scripts'] for case in spec['cases']]
    paths = [(tests_root / spec['path']).resolve() for spec in data['scripts']]
    if len(ids) != len(set(ids)) or len(paths) != len(set(paths)):
        raise ValueError('Duplicate Test IDs or script paths; nothing written')
    serialized = json.dumps(data, indent=2, ensure_ascii=False) + '\n'
    if path.read_text(encoding='utf-8-sig') == serialized:
        print('Metadata already configured; nothing changed')
        return
    backup = path.with_name(path.name + '.bak_' + datetime.now().strftime('%Y%m%d_%H%M%S_%f'))
    backup.write_bytes(path.read_bytes())
    path.write_text(serialized, encoding='utf-8')
    print('Merged:', source)
    print('Target:', path)
    print('Backup:', backup)
    print('Existing unrelated test entries and setup fields preserved.')
    print('Next: python tools/run_sql_tests.py --list')


if __name__ == '__main__':
    try:
        main()
    except (ValueError, OSError, KeyError, TypeError) as exc:
        sys.exit('Configuration stopped: ' + str(exc))