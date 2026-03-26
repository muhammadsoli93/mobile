$ErrorActionPreference = "Stop"

Write-Host "==> Flutter doctor"
flutter doctor

Write-Host "==> Enable desktop targets"
flutter config --enable-windows-desktop --enable-macos-desktop

Write-Host "==> Install dependencies"
flutter pub get

Write-Host "Setup complete."
