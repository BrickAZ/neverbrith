"""Build an immutable local Neverbirth runtime ZIP and its exact file manifest.

Only runtime roots are included; reports, tests, worktrees, tools and .git are
never packaged. Paused character files remain inert compatibility assets.
The output is a local verification artifact, not a Workshop upload.
"""
from pathlib import Path
import argparse
import hashlib
import json
import zipfile
from architecture_check import check

ROOT_FILES = ('metadata.xml', 'README.md', 'README.zh-CN.md', 'COMPATIBILITY.md', 'COMPATIBILITY.zh-CN.md', 'LICENSE', 'LICENSE.md', 'THIRD-PARTY-NOTICES.md')


def runtime_files(root):
    files = set(root.glob('*.lua'))
    files.update(root / name for name in ROOT_FILES if (root / name).is_file())
    directories = [root / name for name in ('scripts', 'generated', 'content')]
    directories.extend(p for p in root.glob('resources*') if p.is_dir())
    for directory in directories:
        if directory.is_dir():
            files.update(p for p in directory.rglob('*') if p.is_file() and '__pycache__' not in p.parts)
    for path in files:
        if not path.resolve().is_relative_to(root):
            raise ValueError(f'runtime symlink leaves source root: {path}')
    return sorted(files)


def package(root, output):
    root, output = Path(root).resolve(), Path(output).resolve()
    if output.exists():
        raise ValueError('output already exists; choose a fresh candidate directory')
    architecture = check(root)
    if not architecture['passed']:
        raise ValueError(f'architecture preflight failed: {architecture["errors"]}, {architecture["limitations"]}')
    files = runtime_files(root)
    names = {p.relative_to(root).as_posix() for p in files}
    missing = set(architecture['runtimeFiles']) - names
    if missing:
        raise ValueError(f'loaded modules omitted from package: {sorted(missing)}')
    output.mkdir(parents=True)
    rows = []
    archive = output / 'neverbrith.zip'
    with zipfile.ZipFile(archive, 'x', compression=zipfile.ZIP_DEFLATED) as package_file:
        for path in files:
            name = path.relative_to(root).as_posix()
            data = path.read_bytes()
            info = zipfile.ZipInfo(name, (1980, 1, 1, 0, 0, 0))
            info.compress_type = zipfile.ZIP_DEFLATED
            info.external_attr = 0o100644 << 16
            package_file.writestr(info, data)
            rows.append({'path': name, 'bytes': len(data), 'sha256': hashlib.sha256(data).hexdigest()})
    extracted = output / 'extracted'
    extracted.mkdir()
    with zipfile.ZipFile(archive) as package_file:
        for entry in package_file.infolist():
            target = (extracted / entry.filename).resolve()
            if not target.is_relative_to(extracted):
                raise ValueError('archive path outside extraction root')
            package_file.extract(entry, extracted)
    for row in rows:
        if hashlib.sha256((extracted / row['path']).read_bytes()).hexdigest() != row['sha256']:
            raise ValueError(f'extracted content mismatch: {row["path"]}')
    extracted_check = check(extracted)
    assert extracted_check['passed'], extracted_check
    result = {'archive': archive.name, 'archiveSha256': hashlib.sha256(archive.read_bytes()).hexdigest(),
              'files': rows, 'fileCount': len(rows), 'runtimeModuleCount': len(architecture['runtimeFiles']),
              'extractionHashesMatch': True, 'isolatedArchitecturePassed': True,
              'limits': 'No native game execution or performance evidence is implied by packaging.'}
    (output / 'manifest.json').write_text(json.dumps(result, ensure_ascii=False, indent=2), encoding='utf-8')
    return result


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--root', type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    result = package(args.root, args.output)
    print(json.dumps({k: v for k, v in result.items() if k != 'files'}, ensure_ascii=False))
