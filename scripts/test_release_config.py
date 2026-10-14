import base64
import json
import tempfile
import unittest
from pathlib import Path

from prepare_android_signing import prepare
from validate_build_config import validate


class ReleaseConfigurationTest(unittest.TestCase):
    def test_backend_configuration(self):
        validate("https://example.com", "sb_publishable_test_only_key")
        def jwt(role):
            payload = base64.urlsafe_b64encode(json.dumps({"role": role}).encode()).decode().rstrip("=")
            return "test." + payload + ".test"
        validate("https://example.com", jwt("anon"))
        for endpoint, key in [
            ("", ""), ("http://example.com", "sb_publishable_test_only_key"),
            ("https://example.com", "sb_secret_test_only_key"),
            ("https://example.com", jwt("service_role")),
        ]:
            with self.subTest(endpoint=endpoint), self.assertRaises(ValueError):
                validate(endpoint, key)

    def test_signing_requires_all_settings(self):
        with self.assertRaises(ValueError):
            prepare({})

    def test_signing_does_not_overwrite_existing_key(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "test.jks"
            settings = {
                "ANDROID_KEYSTORE_PATH": str(path),
                "ANDROID_KEYSTORE_PASSWORD": "test-only",
                "ANDROID_KEY_ALIAS": "test-only",
                "ANDROID_KEY_PASSWORD": "test-only",
                "ANDROID_KEYSTORE_BASE64": base64.b64encode(b"test-only-not-a-keystore").decode(),
            }
            self.assertEqual(prepare(settings), path)
            with self.assertRaises(FileExistsError):
                prepare(settings)
            self.assertEqual(path.read_bytes(), b"test-only-not-a-keystore")

    def test_default_debug_identity_and_unignored_suffix_rejected(self):
        with tempfile.TemporaryDirectory() as directory:
            settings = {
                "ANDROID_KEYSTORE_PATH": str(Path(directory) / "release.jks"),
                "ANDROID_KEYSTORE_PASSWORD": "test-only",
                "ANDROID_KEY_ALIAS": "release-test",
                "ANDROID_KEY_PASSWORD": "test-only",
            }
            for name, alias in [("debug.keystore", "release-test"),
                                ("release.jks", "AndroidDebugKey"),
                                ("release.bin", "release-test")]:
                settings["ANDROID_KEYSTORE_PATH"] = str(Path(directory) / name)
                settings["ANDROID_KEY_ALIAS"] = alias
                with self.subTest(name=name, alias=alias), self.assertRaises(ValueError):
                    prepare(settings)


if __name__ == "__main__":
    unittest.main()
