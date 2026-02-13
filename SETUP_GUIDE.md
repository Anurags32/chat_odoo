# Chat Application - Setup Guide

## 🚀 Quick Start

### Prerequisites
- Flutter SDK (3.9.2 or higher)
- Dart SDK
- Android Studio / VS Code
- Android Emulator or iOS Simulator

### Installation Steps

1. **Install Dependencies**
   ```bash
   flutter pub get
   ```

2. **Run the App**
   ```bash
   # For Android
   flutter run
   
   # For iOS
   flutter run -d ios
   
   # For Web
   flutter run -d chrome
   ```

3. **Build Release Version**
   ```bash
   # Android APK
   flutter build apk --release
   
   # iOS
   flutter build ios --release
   ```

## 📱 App Features

### 1. Splash Screen
- Beautiful animated splash with gradient background
- Auto-navigates to users list after 3 seconds

### 2. Users List
- View all available users
- Search users by name
- See online users in horizontal scroll
- Tap any user to start chatting

### 3. Chat Interface
- Send and receive messages
- See message timestamps
- Read receipts (double tick for read messages)
- Online/offline status
- Voice and attachment buttons (UI ready)

## 🎨 Customization

### Change Colors
Edit `lib/core/theme/app_colors.dart`:
```dart
static const Color saffronPrimary = Color(0xFFFF9933);
static const Color bluePrimary = Color(0xFF1976D2);
```

### Add More Users
Edit `lib/features/users/data/providers/users_provider.dart`:
```dart
List<UserModel> _getDummyUsers() {
  return [
    UserModel(
      id: '9',
      name: 'Your Name',
      avatar: '👤',
      status: 'Available',
      isOnline: true,
    ),
    // Add more users...
  ];
}
```

### Modify Splash Duration
Edit `lib/features/splash/presentation/pages/splash_screen.dart`:
```dart
Future.delayed(const Duration(seconds: 3), () { // Change duration here
```

## 🔧 Project Structure

```
lib/
├── core/              # Core functionality (theme, router, widgets)
├── features/          # Feature modules
│   ├── splash/       # Splash screen
│   ├── users/        # Users list
│   └── chat/         # Chat functionality
└── main.dart         # App entry point
```

## 📦 Dependencies

- **go_router**: Navigation with animations
- **flutter_riverpod**: State management
- **intl**: Date/time formatting

## 🎯 Next Steps

To make this a real chat app, you can:

1. **Add Backend Integration**
   - Firebase Realtime Database
   - Socket.io for real-time messaging
   - REST API integration

2. **Add Authentication**
   - Firebase Auth
   - Phone number verification
   - Social login

3. **Add More Features**
   - Image/file sharing
   - Voice messages
   - Video calls
   - Group chats
   - Push notifications
   - Message reactions
   - Typing indicators

4. **Improve UI**
   - Dark mode
   - Custom themes
   - More animations
   - Profile pages

## 🐛 Troubleshooting

### Issue: Dependencies not resolving
```bash
flutter clean
flutter pub get
```

### Issue: Build errors
```bash
flutter doctor
flutter upgrade
```

### Issue: Hot reload not working
- Restart the app
- Check for syntax errors

## 📝 Notes

- This is a UI-focused implementation with dummy data
- Messages are stored in memory (will reset on app restart)
- No backend integration yet
- Perfect starting point for a full-featured chat app

## 🎉 Enjoy Building!

Feel free to customize and extend this app according to your needs!
