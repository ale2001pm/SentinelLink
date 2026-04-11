# SentinelLink Frontend

Flutter-based frontend for SentinelLink internal communication app.

## Getting Started

This project is a Flutter application with support for desktop and mobile platforms.

### Prerequisites

- Flutter SDK >= 3.0.0
- Dart >= 3.0.0

### Installation

1. Install dependencies:
```bash
flutter pub get
```

2. Generate build files (if needed):
```bash
flutter pub run build_runner build
```

### Running

Run on desktop:
```bash
flutter run -d windows
flutter run -d macos
flutter run -d linux
```

Run on mobile:
```bash
flutter run -d android
flutter run -d ios
```

### Project Structure

```
lib/
├── screens/       # All app screens
├── widgets/       # Custom widgets
├── models/        # Data models
├── services/      # Business logic & API calls
└── main.dart      # App entry point
```

## Phase 1: Initialization

This is Phase 1 of the SentinelLink project where the basic structure and dependencies are set up.
