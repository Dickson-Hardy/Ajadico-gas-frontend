"""Prepare a CI keystore without logging secrets or overwriting an existing key."""
import base64
import binascii
import os
from pathlib import Path


def prepare(environment):
    names = (
        "ANDROID_KEYSTORE_PATH", "ANDROID_KEYSTORE_PASSWORD",
        "ANDROID_KEY_ALIAS", "ANDROID_KEY_PASSWORD",
    )
    if any(not environment.get(name, "").strip() for name in names):
        raise ValueError("All Android release-signing settings are required.")
    path = Path(environment["ANDROID_KEYSTORE_PATH"])
    if not path.is_absolute():
        raise ValueError("ANDROID_KEYSTORE_PATH must be an absolute path.")
    if path.suffix.lower() not in {".jks", ".keystore"}:
        raise ValueError("Use a .jks or .keystore signing file.")
    if (path.name.lower() == "debug.keystore"
            or environment["ANDROID_KEY_ALIAS"].strip().lower() == "androiddebugkey"):
        raise ValueError("The default Android debug identity is not a release key.")
    encoded = environment.get("ANDROID_KEYSTORE_BASE64", "").strip()
    if not encoded:
        if not path.is_file():
            raise ValueError("Provide an existing keystore or ANDROID_KEYSTORE_BASE64.")
        return path
    try:
        data = base64.b64decode(encoded, validate=True)
    except (ValueError, binascii.Error) as error:
        raise ValueError("The encoded Android keystore is invalid.") from error
    if not data:
        raise ValueError("The Android keystore cannot be empty.")
    # Exclusive creation prevents replacing a real signing key by accident.
    with path.open("xb") as target:
        os.chmod(path, 0o600)
        target.write(data)
    return path


if __name__ == "__main__":
    try:
        prepare(os.environ)
    except (ValueError, OSError):
        raise SystemExit("Release signing setup failed. Check settings, keystore path and encoding.")
