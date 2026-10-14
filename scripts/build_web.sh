#!/usr/bin/env bash
set -euo pipefail
# Build configuration is explicit; never source a file containing server keys.
python3 scripts/validate_build_config.py
if ! command -v flutter >/dev/null 2>&1; then
  sdk_dir="$(mktemp -d)/flutter"
  git clone --depth 1 --branch 3.47.6 https://github.com/flutter/flutter.git "$sdk_dir"
  export PATH="$sdk_dir/bin:$PATH"
fi
flutter --version
flutter pub get
flutter analyze --no-pub
flutter build web --release --no-pub \
  --dart-define=SUPABASE_URL="$SUPABASE_URL" \
  --dart-define=SUPABASE_ANON_KEY="$SUPABASE_ANON_KEY"
