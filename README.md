# KuMarket Mobile (Flutter)

This repository is prepared for team usage on both **Windows** and **macOS**.

## 1. Clone from GitHub

```bash
git clone https://github.com/muhammadsoli93/mobile.git
cd mobile
```

## 2. Requirements

- Flutter SDK (stable)
- Dart SDK (comes with Flutter)
- Git

Windows:
- Visual Studio 2022 with "Desktop development with C++" (for Windows desktop build)
- Android Studio (for Android emulator/build)

macOS:
- Xcode + Command Line Tools (for iOS/macOS build)
- Android Studio (optional, for Android emulator/build)

## 3. One-time Flutter setup

```bash
flutter doctor
flutter config --enable-windows-desktop --enable-macos-desktop
flutter pub get
```

## 4. Run app

Windows desktop:
```bash
flutter run -d windows
```

macOS desktop:
```bash
flutter run -d macos
```

Android:
```bash
flutter run -d android
```

iOS (macOS only):
```bash
flutter run -d ios
```

Web:
```bash
flutter run -d chrome
```

## 5. Helper scripts

Windows PowerShell:
```powershell
./scripts/setup_windows.ps1
./scripts/run_windows.ps1
```

macOS:
```bash
chmod +x scripts/setup_macos.sh scripts/run_macos.sh
./scripts/setup_macos.sh
./scripts/run_macos.sh
```

## 6. Team workflow (GitHub)

```bash
git checkout -b feature/your-task
git add .
git commit -m "feat: your change"
git push origin feature/your-task
```

For this project, `main` is already connected to:
`https://github.com/muhammadsoli93/mobile.git`
