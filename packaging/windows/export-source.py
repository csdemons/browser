#!/usr/bin/env python3
"""Export the exact tested Linux checkout changes for native Windows compile.

Run on homik. Produces source patches and selected untracked source/resources;
never includes obj/gen/out, system certificates, profile data, or credentials.
Review the emitted manifest before distributing the source bundle.
"""
import argparse
import hashlib
import json
import subprocess
from pathlib import Path
from zipfile import ZipFile, ZIP_DEFLATED

EXPECTED_CHROMIUM = 'a21ce95c24ce3'  # tag 156.0.8078.79, abbreviated SHA
ALLOWED_PREFIXES = ('chrome/', 'net/', 'services/', 'components/', 'third_party/boringssl/', 'ui/')
ALLOWED_EXTENSIONS = {'.h', '.hpp', '.cc', '.cpp', '.c', '.gn', '.gni', '.grd', '.grdp',
                      '.html', '.css', '.png', '.svg', '.js', '.ts', '.json', '.crt',
                      '.cer', '.pem', '.der', '.txt', '.xml', '.pak', '.ico', '.rc'}
MAX_FILE_SIZE = 8 * 1024 * 1024
MAX_TOTAL_FILES = 600


def git(repo, *args):
    return subprocess.check_output(['git', '-C', str(repo), *args])


def collect_untracked(repo, prefix, output, manifest, allowed_prefixes):
    entries = git(repo, 'ls-files', '-z', '--others', '--exclude-standard').split(b'\0')
    count = 0
    for entry in entries:
        if not entry:
            continue
        rel = entry.decode('utf-8')
        if not rel.startswith(allowed_prefixes):
            continue
        path = repo / rel
        if path.suffix.lower() not in ALLOWED_EXTENSIONS or not path.is_file() or path.is_symlink():
            continue
        if path.stat().st_size > MAX_FILE_SIZE:
            raise RuntimeError(f'Untracked source too large, review manually: {path}')
        arcname = f'files/{prefix}/{rel}'
        raw = path.read_bytes()
        output.writestr(arcname, raw)
        manifest['files'].append({'path': arcname, 'sha256': hashlib.sha256(raw).hexdigest()})
        count += 1
        if count > MAX_TOTAL_FILES:
            raise RuntimeError('Too many untracked files: inspect checkout before export')
    return count


def main():
    parser = argparse.ArgumentParser()
    repo_root = Path(__file__).resolve().parents[2]
    default_src = repo_root.parent / 'chromium' / 'src'
    parser.add_argument('--src', type=Path, default=default_src)
    parser.add_argument('--output', type=Path, default=repo_root / 'dist' / 'atom-browser-windows-source-0.1.0-alpha.zip')
    args = parser.parse_args()
    src = args.src.resolve()
    boringssl = src / 'third_party' / 'boringssl' / 'src'
    chromium_sha = git(src, 'rev-parse', 'HEAD').decode().strip()
    if not chromium_sha.startswith(EXPECTED_CHROMIUM):
        raise SystemExit(f'Unexpected Chromium HEAD: {chromium_sha}')
    boring_sha = git(boringssl, 'rev-parse', 'HEAD').decode().strip()
    args.output.parent.mkdir(parents=True, exist_ok=True)
    patch_chromium = git(src, 'diff', '--binary', 'HEAD')
    patch_boring = git(boringssl, 'diff', '--binary', 'HEAD')
    if not patch_chromium or not patch_boring:
        raise SystemExit('Expected both Chromium and BoringSSL patch changes; refusing partial snapshot')
    meta = {'chromium_sha': chromium_sha, 'boringssl_sha': boring_sha,
            'chromium_version': '156.0.8078.79', 'files': []}
    with ZipFile(args.output, 'w', compression=ZIP_DEFLATED, compresslevel=6) as archive:
        for name, contents in [('patches/chromium.patch', patch_chromium),
                               ('patches/boringssl.patch', patch_boring)]:
            archive.writestr(name, contents)
            meta['files'].append({'path': name, 'sha256': hashlib.sha256(contents).hexdigest()})
        n1 = collect_untracked(src, 'chromium', archive, meta, ALLOWED_PREFIXES)
        n2 = collect_untracked(boringssl, 'boringssl', archive, meta, ('include/', 'crypto/', 'ssl/', 'third_party/'))
        archive.writestr('manifest.json', json.dumps(meta, ensure_ascii=False, indent=2))
    print(f'Snapshot: {args.output}')
    print(f'Untracked source files: Chromium={n1}, BoringSSL={n2}')
    print('Review archive names and inspect patches. Windows compatibility is NOT yet tested.')

if __name__ == '__main__':
    main()
