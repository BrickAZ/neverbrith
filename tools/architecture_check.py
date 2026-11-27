"""Conservative checks of literal Lua loads and explicit architecture contracts.

This is a tokenizer, not a Lua interpreter. Runtime installation/rollback tests
remain authoritative for aliases, conditional execution and callback ordering.
"""
from pathlib import Path
import argparse
import json
import re

TOKEN = re.compile(r'--\[(=*)\[.*?\]\1\]|--[^\n]*|"(?:\\.|[^"\\])*"|\'(?:\\.|[^\'\\])*\'|\[(=*)\[.*?\]\2\]|[A-Za-z_][A-Za-z0-9_]*|[^\s]', re.S)
MODULE = re.compile(r'^[A-Za-z_][A-Za-z0-9_]*(?:[./][A-Za-z_][A-Za-z0-9_]*)*$')


def string_literal(value):
    if len(value) >= 2 and value[0] in ('"', "'"):
        return value[1:-1]
    long_string = re.fullmatch(r'\[(=*)\[(.*?)\]\1\]', value, re.S)
    return long_string.group(2) if long_string else None


def tokens(source):
    result, offset, line = [], 0, 1
    for m in TOKEN.finditer(source):
        line += source.count('\n', offset, m.start())
        if not m.group().startswith('--'):
            result.append((m.group(), line))
        line += m.group().count('\n')
        offset = m.end()
    return result


def check(root):
    root = Path(root).resolve()
    pending, seen, edges, errors, limitations = ['main.lua'], set(), [], [], []
    while pending:
        relative = pending.pop()
        if relative in seen:
            continue
        seen.add(relative)
        path = root / relative
        if not path.is_file():
            errors.append(f'missing runtime module: {relative}')
            continue
        actual = root
        for segment in Path(relative).parts:
            names = {p.name for p in actual.iterdir()}
            if segment not in names:
                errors.append(f'path case mismatch: {relative}')
                break
            actual /= segment
        source = path.read_text(encoding='utf-8-sig')
        ts = tokens(source)
        for i, (value, line) in enumerate(ts):
            previous = ts[i - 1][0] if i else ''
            following = ts[i + 1][0] if i + 1 < len(ts) else ''
            member = value
            after_member = following
            direct_member = previous in ('.', ':')
            if previous == '[' and following == ']':
                member = string_literal(value) or ''
                after_member = ts[i + 2][0] if i + 2 < len(ts) else ''
                direct_member = True
            if member.endswith('TestAPI') and direct_member:
                own_return = (relative == 'scripts/features/big_dog_bark.lua' and value == 'BigDogBarkTestAPI'
                              and i >= 3 and ts[i - 3][0] == 'return' and ts[i - 2][0] == 'Neverbirth')
                method_definition = i >= 3 and ts[i - 3][0] == 'function' and previous in ('.', ':')
                if after_member != '=' and not own_return and not method_definition:
                    errors.append(f'production TestAPI read: {relative}:{line} {member}')
            if value not in ('include', 'require') or previous in ('.', ':', 'function'):
                continue
            if following != '(' and string_literal(following) is None:
                continue
            j = i + (2 if following == '(' else 1)
            arg = ts[j][0] if j < len(ts) else ''
            module = string_literal(arg)
            literal = module is not None and MODULE.fullmatch(module)
            if following == '(':
                literal = literal and j + 1 < len(ts) and ts[j + 1][0] == ')'
            if not literal:
                limitations.append(f'dynamic/unsupported load: {relative}:{line}')
                continue
            target = module.replace('.', '/') + '.lua'
            if value == 'require' and module == 'json':
                continue
            edges.append({'from': relative, 'to': target, 'line': line})
            if relative.startswith('scripts/runtime/') and not target.startswith(('scripts/runtime/', 'scripts/catalog/')):
                errors.append(f'runtime reverse dependency: {relative}:{line} -> {target}')
            pending.append(target)
        if relative == 'main.lua':
            compact = ' '.join(t[0] for t in ts)
            if 'persistence . GetRoot' in compact:
                errors.append('bootstrap exposes unrestricted persistence.GetRoot')
            if re.search(r'TEMPORARY.*PROBE|MOTION_NATIVE_ACCEPTANCE_TEMPORARY|BATCH\d+_NATIVE_PROBE', source):
                errors.append('temporary native probe in production main.lua')
    if 'dante_character.lua' in seen:
        errors.append('paused custom character is loaded')
    players = root / 'content/players.xml'
    if players.is_file():
        # XML well-formedness is checked by the existing generic/strict validators.
        # This guard only recognizes the native player registration tag.
        declarations = re.sub(r'<!--.*?-->', '', players.read_text(encoding='utf-8-sig'), flags=re.S)
        if re.search(r'<player(?=[\s/>])', declarations):
            errors.append('paused custom characters have active XML registrations')
    return {'passed': not errors and not limitations, 'runtimeFiles': sorted(seen), 'edges': edges,
            'errors': errors, 'limitations': limitations,
            'exceptions': ['big_dog_bark returns its own legacy TestAPI view; main discards it; no consumer dependency'],
            'coverage': 'Literal include/require graph, exact path case, runtime layer direction, direct TestAPI member reads, scoped bootstrap, paused characters, temporary probes. Does not resolve aliases or prove native callback behavior.'}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--root', type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument('--report', type=Path)
    args = parser.parse_args()
    result = check(args.root)
    if args.report:
        args.report.parent.mkdir(parents=True, exist_ok=True)
        args.report.write_text(json.dumps(result, ensure_ascii=False, indent=2), encoding='utf-8')
    print(json.dumps({k: result[k] for k in ('passed', 'errors', 'limitations')}, ensure_ascii=False))
    print(f"runtime files: {len(result['runtimeFiles'])}, literal edges: {len(result['edges'])}")
    return 0 if result['passed'] else 1


if __name__ == '__main__':
    raise SystemExit(main())
