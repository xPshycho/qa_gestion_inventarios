#!/usr/bin/env python3
"""Fail closed when staging evidence contains secrets in plain or encoded data."""

from __future__ import annotations

import base64
import binascii
import gzip
import io
import os
from pathlib import Path
import re
import sys
import zipfile


SECRET_ENVIRONMENT_VARIABLES = (
    "POSTGRES_PASSWORD",
    "KEYCLOAK_DB_PASSWORD",
    "KEYCLOAK_ADMIN_PASSWORD",
    "KEYCLOAK_ADMIN_CLIENT_SECRET",
    "E2E_ADMIN_PASSWORD",
    "E2E_OPERATOR_PASSWORD",
    "E2E_VIEWER_PASSWORD",
    "E2E_AUDITOR_PASSWORD",
    "GRAFANA_ADMIN_PASSWORD",
)
JWT_PATTERN = re.compile(
    rb"eyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}"
)
BASE64_PATTERN = re.compile(rb"base64,([A-Za-z0-9+/_-]{128,}={0,2})")
MAX_INPUT_BYTES = 100 * 1024 * 1024
MAX_EXPANDED_BYTES = 200 * 1024 * 1024
MAX_RECURSION = 4


class UnsafeEvidence(RuntimeError):
    pass


expanded_bytes = 0
inspected_payloads = 0


def configured_secrets() -> tuple[bytes, ...]:
    missing = [name for name in SECRET_ENVIRONMENT_VARIABLES if not os.getenv(name)]
    if missing:
        raise RuntimeError("required secret environment variables are missing")
    return tuple(os.environ[name].encode() for name in SECRET_ENVIRONMENT_VARIABLES)


SECRETS = configured_secrets()
SECRET_ENCODINGS = tuple(base64.b64encode(secret) for secret in SECRETS)
USER_ENVIRONMENT_VARIABLES = (
    "E2E_ADMIN_USERNAME",
    "E2E_OPERATOR_USERNAME",
    "E2E_VIEWER_USERNAME",
    "E2E_AUDITOR_USERNAME",
    "GRAFANA_ADMIN_USER",
)
BASIC_AUTH_ENCODINGS = tuple(
    base64.b64encode(
        f"{os.environ[user_name]}:{os.environ[password_name]}".encode()
    )
    for user_name, password_name in zip(
        USER_ENVIRONMENT_VARIABLES,
        SECRET_ENVIRONMENT_VARIABLES[4:],
        strict=True,
    )
)


def account_expansion(size: int) -> None:
    global expanded_bytes
    expanded_bytes += size
    if expanded_bytes > MAX_EXPANDED_BYTES:
        raise UnsafeEvidence("encoded evidence exceeds the safe expansion limit")


def inspect_payload(data: bytes, label: str, depth: int = 0) -> None:
    global inspected_payloads
    inspected_payloads += 1
    if len(data) > MAX_INPUT_BYTES:
        raise UnsafeEvidence(f"{label}: file or payload exceeds the safe scan limit")
    if any(secret in data for secret in SECRETS):
        raise UnsafeEvidence(f"{label}: configured secret detected")
    if any(encoded in data for encoded in SECRET_ENCODINGS):
        raise UnsafeEvidence(f"{label}: base64-encoded secret detected")
    if any(encoded in data for encoded in BASIC_AUTH_ENCODINGS):
        raise UnsafeEvidence(f"{label}: Basic authentication value detected")
    if JWT_PATTERN.search(data):
        raise UnsafeEvidence(f"{label}: JWT-like value detected")
    if depth >= MAX_RECURSION:
        return

    if data.startswith(b"PK\x03\x04"):
        with zipfile.ZipFile(io.BytesIO(data)) as archive:
            for member in archive.infolist():
                if member.is_dir():
                    continue
                if member.file_size > MAX_INPUT_BYTES:
                    raise UnsafeEvidence(f"{label}: archive member exceeds the safe limit")
                member_data = archive.read(member)
                account_expansion(len(member_data))
                inspect_payload(member_data, f"{label}:archive-member", depth + 1)

    if data.startswith(b"\x1f\x8b"):
        decoded = gzip.decompress(data)
        account_expansion(len(decoded))
        inspect_payload(decoded, f"{label}:gzip", depth + 1)

    for match in BASE64_PATTERN.finditer(data):
        encoded = match.group(1)
        padding = b"=" * ((4 - len(encoded) % 4) % 4)
        try:
            decoded = base64.b64decode(
                encoded.replace(b"-", b"+").replace(b"_", b"/") + padding,
                validate=True,
            )
        except (ValueError, binascii.Error):
            continue
        if len(decoded) < 32:
            continue
        account_expansion(len(decoded))
        inspect_payload(decoded, f"{label}:base64", depth + 1)


def main() -> int:
    if len(sys.argv) != 2:
        print("usage: scan-evidence.py EVIDENCE_DIRECTORY", file=sys.stderr)
        return 2

    evidence_directory = Path(sys.argv[1]).resolve()
    if not evidence_directory.is_dir():
        print("evidence directory does not exist", file=sys.stderr)
        return 1

    try:
        for evidence_file in sorted(evidence_directory.rglob("*")):
            if evidence_file.is_symlink():
                raise UnsafeEvidence("symbolic links are not allowed in evidence")
            if not evidence_file.is_file():
                continue
            if evidence_file.stat().st_size > MAX_INPUT_BYTES:
                raise UnsafeEvidence(
                    f"{evidence_file.name}: file exceeds the safe scan limit"
                )
            inspect_payload(evidence_file.read_bytes(), evidence_file.name)
    except (OSError, RuntimeError, UnsafeEvidence, zipfile.BadZipFile) as error:
        print(f"evidence safety scan failed: {error}", file=sys.stderr)
        return 1

    print(
        "Recursive evidence scan passed "
        f"({inspected_payloads} plain/encoded payloads inspected)."
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
