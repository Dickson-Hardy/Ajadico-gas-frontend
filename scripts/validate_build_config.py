"""Reject absent or server-secret configuration before it can enter an artifact."""
import base64
import json
import os
from urllib.parse import urlparse


def validate(endpoint, key):
    uri = urlparse(endpoint.strip())
    if uri.scheme != "https" or not uri.hostname or uri.username or uri.query or uri.fragment:
        raise ValueError("A valid HTTPS SUPABASE_URL is required.")
    value = key.strip()
    if value.startswith("sb_publishable_") and len(value) > 20:
        return
    try:
        parts = value.split(".")
        payload = json.loads(base64.urlsafe_b64decode(parts[1] + "=" * (-len(parts[1]) % 4)))
        if len(parts) == 3 and payload.get("role") == "anon":
            return
    except (IndexError, ValueError, AttributeError):
        pass
    raise ValueError("SUPABASE_ANON_KEY must be a publishable/anon key, never a server secret.")


if __name__ == "__main__":
    try:
        validate(os.getenv("SUPABASE_URL", ""), os.getenv("SUPABASE_ANON_KEY", ""))
    except ValueError as error:
        raise SystemExit(str(error))
