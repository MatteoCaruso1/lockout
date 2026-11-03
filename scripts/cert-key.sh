#!/usr/bin/env bash
# Codemagic's variable box is a single line, so a pasted PEM key loses its
# line breaks. Rebuild a valid PEM file from whatever was pasted and print its
# path. Never prints the key itself.
set -euo pipefail
python3 - <<'PY'
import os, re, textwrap
raw = os.environ.get("CERTIFICATE_PRIVATE_KEY", "")
m = re.search(r"-----BEGIN ([A-Z ]+)-----(.*?)-----END \1-----", raw, re.S)
if not m:
    raise SystemExit("CERTIFICATE_PRIVATE_KEY has no -----BEGIN/END----- lines; paste the whole key file")
kind, body = m.group(1), re.sub(r"\s+", "", m.group(2))
pem = f"-----BEGIN {kind}-----\n" + "\n".join(textwrap.wrap(body, 64)) + f"\n-----END {kind}-----\n"
path = os.path.join(os.environ.get("CM_BUILD_DIR", "."), "cert_key.pem")
open(path, "w").write(pem)
print(f"Key type: {kind}, {len(body)} base64 chars", file=__import__("sys").stderr)
print(path)
PY
