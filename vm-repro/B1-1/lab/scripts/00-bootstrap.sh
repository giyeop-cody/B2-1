#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/00-env.sh"
[[ $(uname -m) == x86_64 ]] || { echo 'Ubuntu amd64 VM required'; exit 1; }
python3 - "$LAB_SRC" <<'CHECK'
import sys,json,hashlib,pathlib
root=pathlib.Path(sys.argv[1])
for item in json.loads((root/'manifest.json').read_text())['files']:
 p=root/item['path']
 assert hashlib.sha256(p.read_bytes()).hexdigest()==item['sha256'],str(p)
 print('PASS SHA256',item['path'])
CHECK
