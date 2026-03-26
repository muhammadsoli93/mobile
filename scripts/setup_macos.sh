#!/usr/bin/env bash
set -euo pipefail

echo "==> Flutter doctor"
flutter doctor

echo "==> Enable desktop targets"
flutter config --enable-windows-desktop --enable-macos-desktop

echo "==> Install dependencies"
flutter pub get

echo "Setup complete."
