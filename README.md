# ResolveDesk Mobile (Paradesk)

[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter&logoColor=white)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.x-0175C2?logo=dart&logoColor=white)](https://dart.dev)
[![Version](https://img.shields.io/badge/Version-3.8.0%2B13-1e3a8a)](pubspec.yaml)
[![License](https://img.shields.io/badge/License-Proprietary-red)]()

A high-performance, enterprise-grade field service engineering application built with Flutter. ResolveDesk (branded as **Paradesk**) empowers field service engineers and technicians at **Paramount Office Systems Pvt Ltd** to manage service calls, track resolution timers, record equipment installations, capture digital customer sign-offs, and generate official A4 PDF service vouchers directly on-site.

---

## 🌟 Key Features

### 1. 📋 Real-Time Service Dispatch & SLA Management
- **Live Ticket Queue**: View complaints grouped by status: *Assigned*, *Pending*, *Ongoing*, *On Hold*, *Rescheduled*, and *Resolved*.
- **Working Hours Resolution Timer**: Resolution time is tracked strictly within working hours (10:00 AM – 6:30 PM, Mon–Sat).
- **Client Busy / Hold (Timer Freeze)**: Pause resolution timers with verified delay reasons (e.g., client meeting, site locked) so technician wait time is not penalized against SLAs.
- **One-Tap Actions**: Direct customer phone dialer and Google Maps navigation to customer site coordinates.

### 2. 🖨️ Official A4 PDF Engine & In-Memory LRU Pre-Caching
- **1:1 Official Document Layout**: Compiles dynamic A4 Service Call Reports and Installation Reports matching physical company paper stationery with company letterhead, contact grids, and terms.
- **Bounded LRU Cache**: Employs an in-memory Least Recently Used (LRU) PDF byte cache (bounded to 6 documents) in `PdfReportService`.
- **Zero-Latency Rendering**: Pre-caches PDF bytes asynchronously in the background when previews open, achieving `< 50ms` instant render for printing and downloads.

### 3. 💬 One-Tap WhatsApp PDF Sharing
- Technicians can instantly dispatch signed official A4 PDF receipts directly to the customer's WhatsApp before leaving the premises, complete with automated pre-filled greeting and ticket reference.

### 4. ✍️ Smooth Digital Signature Canvas
- **Quadratic Bezier Curve Smoothing**: Replaces jagged polygonal finger lines with continuous mid-point quadratic Bezier curves (`quadraticBezierTo`), producing natural pen-on-paper digital signatures.
- **Multi-Source Ingestion**: Supports direct screen stylus/finger drawing, mobile camera document photography, or image gallery selection.
- **Offscreen Canvas Export**: Renders signatures onto high-resolution white off-screen canvases exported as base64 PNG data.

### 5. 📳 Tactile Haptic Feedback Engine
- Integrated system haptics (`HapticFeedback`) delivering physical tactile feedback:
  - `selectionClick()` on bottom navigation tabs, metric summary cards, and status filter chips.
  - `mediumImpact()` on primary actions (*Mark Ongoing*, *Mark Resolved*, *Save Reschedule*, *Share WhatsApp*, and *Print*).
  - `lightImpact()` on pad clearing and filter resets.

### 6. 🛡️ Resilient Offline & Error State Architecture
- **Actionable Empty States**: Context-aware recovery buttons (`[ Reset Filter & Show All ]` or `[ + Create New Report ]`) when queries yield no results.
- **Isolated Failure Boundaries**: Summary metrics and ticket queues load concurrently without blocking each other if network latency fluctuates.
- **Role-Based Access Control (RBAC)**: Enforces granular technician permissions via `PermissionAccess` loaded securely from JWT session claims.

---

## 📱 User Interface & Visual Hierarchy

The application follows an **Executive Palette** built on Apple HIG and Material 3 design systems:

| Role | Color | Hex Code | Purpose |
| :--- | :--- | :--- | :--- |
| **Primary Navy** | Cobalt Royal Navy | `#1e3a8a` | Header banners, primary action buttons, active navigation indicators |
| **Slate Dark** | Deep Charcoal Slate | `#0f172a` | High-contrast typography, complaint reference numbers |
| **Emerald Green** | Forest Emerald | `#15803d` | Resolved badges, WhatsApp share triggers, success confirmations |
| **Amber Gold** | Warning Amber | `#d97706` | Pending badges, timer pause indicators |
| **Neutral Surface** | Cloud Gray | `#f8fafc` | Scaffolding background, card containers |

---

## 🏗️ Project Architecture

The codebase follows **Clean Architecture** patterns, isolating presentation, business logic, network communication, and hardware services:

```
resolvedesk_mobileapp/
├── android/                        # Native Android configuration & Gradle build scripts
├── assets/                         # Static assets (Company logos, application icons)
│   └── images/
│       ├── app_icon.png
│       └── paramount_logo.png
├── ios/                            # Native iOS configuration
├── lib/
│   ├── config/                     # Environment & networking configuration
│   │   ├── api_config.dart         # Centralized Dio HTTP client, JWT interceptor, token refresh
│   │   └── environment_config.dart # Base URL management (Production vs. Local Development)
│   ├── pages/                      # Screen views and controllers
│   │   ├── login_page.dart         # Authentication screen
│   │   ├── technician_dashboard_page.dart # Home dashboard, metric cards, ticket queue
│   │   ├── complaint_details_page.dart    # Ticket workspace, status transitions, hold bottom sheet
│   │   ├── service_call_reports_page.dart # Service reports directory with filters
│   │   ├── create_service_report_page.dart # Service call report creation & editing form
│   │   ├── installation_reports_page.dart # Equipment installation reports directory
│   │   ├── create_installation_report_page.dart # Installation report creation & editing form
│   │   └── enquiries_page.dart     # Customer lead and sales enquiry logging
│   ├── services/                   # Hardware, storage, and platform services
│   │   ├── app_update_service.dart # In-app OTA APK version checker and auto-installer
│   │   ├── notification_service.dart # Firebase Cloud Messaging (FCM) & local alerts
│   │   ├── pdf_report_service.dart # A4 PDF generation engine with bounded LRU cache
│   │   └── permission_access.dart  # Permission matrix parsed from user JWT
│   ├── widgets/                    # Reusable components and dialogs
│   │   ├── service_report_preview_dialog.dart     # Service report A4 preview & 2-tier action footer
│   │   ├── installation_report_preview_dialog.dart # Installation report A4 preview & 2-tier action footer
│   │   ├── signature_upload_widget.dart           # Bezier-smoothed digital signature pad
│   │   └── paradesk_shimmer.dart                  # Skeleton loading placeholders
│   └── main.dart                   # Application entrypoint & dependency bootstrap
└── pubspec.yaml                    # Package dependencies and asset manifests
```

---

## 🚀 Getting Started

### Prerequisites
- **Flutter SDK**: `^3.19.0` or higher (compatible with Dart `^3.12.0`)
- **Android Studio** / **VS Code** with Flutter & Dart extensions
- **Java JDK**: 17 or higher
- Android device or emulator running Android 8.0+ (API level 26+)

### 1. Clone the Repository
```bash
git clone https://github.com/kittusensei7/Resolvedesk_mobileapp.git
cd Resolvedesk_mobileapp
```

### 2. Install Dependencies
```bash
flutter pub get
```

### 3. Firebase Configuration
For push notifications to function, obtain your project's `google-services.json` from the Firebase Console and place it at:
```
android/app/google-services.json
```
*(Note: `google-services.json` is protected by `.gitignore` and must never be committed to public repositories).*

---

## 🌐 Environment & API Configuration

The application automatically toggles between development and production endpoints via [EnvironmentConfig](lib/config/environment_config.dart):

| Environment | Base URL | Trigger |
| :--- | :--- | :--- |
| **Production** | `https://paradesk.cloud/api` | Default for release builds (`flutter build apk`) or with compile flag |
| **Local Development** | `http://127.0.0.1:4000/api` | Default for debug runs (`flutter run`) |

To explicitly target production during debug mode:
```bash
flutter run --dart-define=ENV=production
```

Or target a custom backend IP (e.g., when testing over wireless ADB):
```bash
flutter run --dart-define=API_BASE_URL=http://192.168.1.50:4000/api
```

---

## 🛠️ Development & Quality Assurance

### Static Code Analysis
Run Flutter's linter to verify zero syntax errors and clean formatting:
```bash
flutter analyze
```

### Launch Debugging
Launch the app with hot-reload enabled:
```bash
flutter run
```

---

## 📦 Building for Production

### Android Release APK (Direct Sideloading)
```bash
flutter build apk --release
```
The output binary will be located at:
```
build/app/outputs/flutter-apk/app-release.apk
```

### Android App Bundle (Google Play Store)
```bash
flutter build appbundle --release
```
The output bundle will be located at:
```
build/app/outputs/bundle/release/app-release.aab
```

---

## 🔒 Security & Best Practices

- **Zero Hardcoded Secrets**: All API endpoints use compile-time constants or runtime environment variables.
- **Encrypted Local Storage**: Sensitive tokens and refresh credentials are encrypted at rest using `flutter_secure_storage` (Android Keystore / iOS Keychain).
- **Protected Secrets in `.gitignore`**: Keystores (`*.keystore`, `*.jks`), private credentials (`key.properties`, `local.properties`), Firebase credentials (`google-services.json`, `GoogleService-Info.plist`), and environment files (`.env`) are strictly excluded from version control.

---

## 📄 License & Ownership

Copyright © 2026 **Paramount Office Systems Pvt Ltd**. All Rights Reserved.  
Proprietary software for internal enterprise operations. Unauthorized copying, distribution, or reverse engineering is strictly prohibited.
