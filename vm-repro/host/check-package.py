#!/usr/bin/env python3
"""Validate bundled immutable inputs and syntax of all shipped shell scripts."""
import hashlib,json,pathlib,subprocess
root=pathlib.Path(__file__).resolve().parents[1]
for item in json.loads((root/'inputs/manifest.json').read_text())['files']:
 p=root/'inputs'/item['path']
 assert p.stat().st_size==item['bytes'],p
 assert hashlib.sha256(p.read_bytes()).hexdigest()==item['sha256'],p
 print('PASS input',item['path'])
for p in sorted(root.rglob('*.sh')):
 subprocess.run(['bash','-n',str(p)],check=True)
print('PASS all shell syntax')
