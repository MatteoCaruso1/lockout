#!/usr/bin/env bash
# Codemagic's variable box is a single line, so a pasted PEM key loses its
# line breaks (and a partial copy may lose its BEGIN/END lines). Rebuild a
# valid PEM file from whatever was pasted and print its path. Never prints the
# key itself, only its shape, so a bad paste can be diagnosed from the log.
set -euo pipefail
python3 - <<'PY'
import os, re, sys, textwrap
raw = os.environ.get("CERTIFICATE_PRIVATE_KEY", "")
stripped = raw.strip()
shape = {
    "length": len(stripped),
    "lines": raw.count("\n") + 1,
    "has_BEGIN": "-----BEGIN" in raw,
    "has_END": "-----END" in raw,
    "non_base64_chars": len(re.sub(r"[A-Za-z0-9+/=\s-]", "", raw)),
}
print(f"CERTIFICATE_PRIVATE_KEY shape: {shape}", file=sys.stderr)

m = re.search(r"-----BEGIN ([A-Z ]+)-----(.*?)-----END \1-----", raw, re.S)
if m:
    kind, body = m.group(1), m.group(2)
else:
    # Body only (copied without the first and last lines): assume the RSA key
    # that ssh-keygen -m PEM writes.
    kind, body = "RSA PRIVATE KEY", re.sub(r"-----[^-]*-----", "", raw)
body = re.sub(r"\s+", "", body)
if kind == "PRIVATE KEY" and len(body) < 400:
    sys.exit("This looks like the App Store Connect .p8 key, not the certificate key. "
             "Paste Downloads\\Codemagic key\\lockout_certificate_private_key instead.")
if not re.fullmatch(r"[A-Za-z0-9+/=]{800,}", body):
    sys.exit("CERTIFICATE_PRIVATE_KEY is not a private key (see shape above). "
             "Paste the whole of Downloads\\Codemagic key\\lockout_certificate_private_key.")
pem = f"-----BEGIN {kind}-----\n" + "\n".join(textwrap.wrap(body, 64)) + f"\n-----END {kind}-----\n"
path = os.path.join(os.environ.get("CM_BUILD_DIR", "."), "cert_key.pem")
open(path, "w").write(pem)
print(f"Key rebuilt: {kind}, {len(body)} base64 chars", file=sys.stderr)
print(path)
PY
