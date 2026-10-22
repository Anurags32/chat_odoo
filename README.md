# 📱 Odoo Communication App (Chat & Calls)

A high-performance, secure, and modern mobile communication application built with **Flutter**, designed specifically for real-time messaging, WebRTC audio/video calls, and presence management backed entirely by **Odoo**.

> **Note**: This application is strictly dedicated to communication (**Chat, Audio Calls, Video Calls, Group Calls, Contacts, and Online Status**). No business modules (CRM, Sales, HR, Accounting) are included.

---

## 🌟 Key Features

### 🔐 1. Authentication & Security
- **Dynamic Odoo Server Connection**: Connect to any custom Odoo server URL, database name, username, and password.
- **Persistent Sessions**: Automated session restoration across app launches via secure cookie and Bearer token management.
- **Hardware-Level Encryption**: All sensitive credentials, session tokens, and passwords are encrypted using `flutter_secure_storage` (Android Keystore / iOS Keychain).
- **Offline Data Sync**: Contacts, channels, and message history are securely cached locally for offline browsing.

### 💬 2. One-to-One & Group Chat
- **Direct & Group Conversations**: Fully synced with Odoo Discuss (`mail.channel`).
- **Rich Media Sharing**:
  - Image sharing (camera capture & photo gallery).
  - Document & file sharing (`FilePicker` integration).
  - Voice notes and audio attachments.
  - Interactive emoji picker.
- **Real-Time Indicators**: Real-time typing indicators, read receipts (sent, delivered, read double-ticks), and unread badges.
- **WebSocket Longpolling Bus**: Subscribes directly to Odoo bus channels for instant inbound messages.

### 📞 3. WebRTC Audio & Video Calling
- **1-to-1 Audio & Video Calls**: Low-latency peer-to-peer media streams with dynamic STUN/TURN ICE server negotiation.
- **Group Calling**: Multi-party grid layout with speaking active border indicators, mute status, and dynamic speaker toggles.
- **In-Call Controls**: Camera switch (front/back), mic mute, video disable/enable, speakerphone toggle, and call timer.
- **Call History**: Complete call log (incoming, outgoing, missed) stored in Odoo backend with call duration and timestamps.
- **CallKit & ConnectionService Ready**: Background call notifications with full-screen incoming call UI.

### 🟢 4. Presence & Network Intelligence
- **Real-Time Status**: Online/offline indicators (green/grey status dots) and "last seen" timestamps.
- **Network Resilience Banner**: Non-intrusive offline indicator with automatic reconnection and cache sync when internet connectivity is restored.

---

## 🎨 Design System & UI/UX

Designed with a modern, high-contrast, premium interface supporting both **Light Mode** and **Dark Mode**:

- **Primary Brand Color**: Deep Indigo / Purple (`#6366F1`)
- **Accent Brand Color**: Vibrant Cyan / Teal (`#06B6D4`)
- **Action Highlight**: Sunset Orange (`#F97316`)
- **Dark Mode Background**: OLED Pitch & Slate Charcoal (`#0B0F19`, `#1E293B`)
- **Light Mode Background**: Crisp Clean White & Ice Mist (`#FFFFFF`, `#F8FAFC`)
- **Typography**: Google Fonts **Poppins** with clear hierarchy and accessibility standards.
- **Bottom Navigation Tabs**:
  1. `Chats` (Filter by All, Direct, Groups)
  2. `Calls` (All Calls vs Missed Calls with quick callback)
  3. `Contacts` (Live search, presence badge, quick call buttons)
  4. `Profile` (Online status selector, user details, server config, logout)

---

## 🏛️ Clean Architecture

The app is built following **Clean Architecture** with separation of concerns:

```
lib/
├── core/
│   ├── network/            # DioClient, WebSocketService, ApiConstants, AuthInterceptor
│   ├── router/             # AppRouter (GoRouter declarative routes)
│   ├── services/           # ConnectivityService
│   ├── storage/            # StorageService (FlutterSecureStorage & SharedPreferences)
│   ├── theme/              # AppColors & AppTheme (Material 3 Light/Dark)
│   └── widgets/            # SkeletonLoader, EmptyStateWidget, ConnectivityBanner, UserAvatarWidget
│
└── features/
    ├── auth/               # LoginScreen, ApiService, Session Management
    ├── call/               # WebRtcService, GroupCallScreen, Audio/Video Call, PushNotificationService
    ├── chat/               # ChatsTab, RealChatScreen, ChatInput, Message Bubbles
    ├── groups/             # GroupChatScreen, Group Management
    ├── onboarding/         # OnboardingScreen (3 interactive walkthrough slides)
    ├── profile/            # ProfileScreen, Status selector, Server settings
    ├── splash/             # SplashScreen with smooth logo transitions
    └── users/              # ContactsTab, Search, Presence indicators
```

---

## 🚀 Setup & Installation

### Prerequisites
- Flutter SDK `3.9.2` or later
- Dart SDK `3.3.0` or later
- Android Studio / Xcode
- A running Odoo server instance (v14, v15, v16, v17, or v18)

### 1. Clone & Install Dependencies
```bash
git clone <repository_url>
cd chat_odoo
flutter pub get
```

### 2. Verify Code Quality & Static Analysis
```bash
flutter analyze
```

### 3. Run the App
```bash
# Debug mode
flutter run

# Specify device/simulator
flutter run -d chrome
flutter run -d ios
flutter run -d android
```

---

## ⚙️ Odoo Backend Configuration

1. When launching the app for the first time, you will be prompted on the **Login Screen** for:
   - **Server URL**: e.g. `https://your-odoo-instance.com`
   - **Database Name**: e.g. `odoo_db`
   - **Email / Username**: e.g. `admin`
   - **Password**: `admin`
2. The app communicates with Odoo via:
   - `/web/session/authenticate` (Standard Odoo JSON-RPC session handshake)
   - `/websocket` (Odoo Longpolling / WebSocket channel bus)
   - Custom REST/RPC endpoints for WebRTC signaling (`/webrtc/*`) and call history.
