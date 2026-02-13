# 💬 Chat Application

A beautiful, modern chat application built with Flutter featuring smooth animations, clean architecture, and an elegant Bhagwa-Blue-White color scheme.

## ✨ Features

### 🎨 Beautiful UI
- **Animated Splash Screen** with gradient background
- **Modern Design** with Material 3
- **Smooth Animations** throughout the app
- **Bhagwa-Blue-White** color scheme (Indian tricolor inspired)

### 👥 Users Management
- View all users in a clean list
- Search users by name
- See online users in a horizontal scroll
- Online/offline status indicators
- Last seen timestamps

### 💬 Chat Interface
- Real-time message display
- Message bubbles with timestamps
- Read receipts (double tick)
- Smooth message animations
- Voice and attachment options (UI ready)
- User status in app bar

## 🏗️ Architecture

This project follows **Clean Architecture** principles with a feature-first approach:

```
lib/
├── core/                    # Shared functionality
│   ├── router/             # Navigation (GoRouter)
│   ├── theme/              # Colors & Theme
│   └── widgets/            # Reusable widgets
│
└── features/               # Feature modules
    ├── splash/            # Splash screen
    ├── users/             # Users list
    └── chat/              # Chat functionality
        ├── domain/        # Models
        ├── data/          # Providers
        └── presentation/  # UI
```

## 🚀 Getting Started

### Prerequisites
- Flutter SDK 3.9.2+
- Dart SDK
- Android Studio / VS Code

### Installation

1. Clone the repository
2. Install dependencies:
   ```bash
   flutter pub get
   ```
3. Run the app:
   ```bash
   flutter run
   ```

## 📦 Dependencies

- **go_router** (^14.6.2) - Navigation with custom transitions
- **flutter_riverpod** (^2.6.1) - State management
- **intl** (^0.19.0) - Date/time formatting

## 🎨 Color Palette

- **Saffron**: `#FF9933` - Primary actions, gradients
- **Blue**: `#1976D2` - Secondary elements
- **White**: `#FFFFFF` - Backgrounds
- **Grey Shades**: Text hierarchy

## 📱 Screenshots Flow

```
Splash Screen → Users List → Chat Screen
```

## 🔧 Key Technologies

- **Flutter** - UI Framework
- **GoRouter** - Type-safe navigation
- **Riverpod** - State management
- **Material 3** - Modern design system

## 📖 Documentation

- [Project Structure](PROJECT_STRUCTURE.md) - Detailed folder structure
- [Setup Guide](SETUP_GUIDE.md) - Installation and customization

## 🎯 Future Enhancements

- [ ] Backend integration (Firebase/Socket.io)
- [ ] User authentication
- [ ] Image/file sharing
- [ ] Voice messages
- [ ] Video calls
- [ ] Group chats
- [ ] Push notifications
- [ ] Dark mode
- [ ] Message reactions
- [ ] Typing indicators

## 🤝 Contributing

Contributions are welcome! Feel free to submit issues and pull requests.

## 📄 License

This project is open source and available under the MIT License.

## 👨‍💻 Developer

Built with ❤️ using Flutter

---

**Note**: This is a UI-focused implementation with dummy data. Perfect starting point for building a full-featured chat application!
