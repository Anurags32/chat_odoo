# Chat Application - Project Structure

## 📁 Folder Structure

```
lib/
├── core/
│   ├── router/
│   │   └── app_router.dart          # GoRouter configuration with animations
│   ├── theme/
│   │   ├── app_colors.dart          # Bhagwa-Blue-White color scheme
│   │   └── app_theme.dart           # Material theme configuration
│   └── widgets/
│       ├── custom_button.dart       # Reusable button widget
│       └── custom_text_field.dart   # Reusable text field widget
│
├── features/
│   ├── splash/
│   │   └── presentation/
│   │       └── pages/
│   │           └── splash_screen.dart    # Animated splash screen
│   │
│   ├── users/
│   │   ├── data/
│   │   │   └── providers/
│   │   │       └── users_provider.dart   # Riverpod state management
│   │   └── presentation/
│   │       ├── pages/
│   │       │   └── users_list_screen.dart # Users listing with search
│   │       └── widgets/
│   │           └── user_card.dart         # User card widget
│   │
│   └── chat/
│       ├── domain/
│       │   └── models/
│       │       ├── message_model.dart     # Message data model
│       │       └── user_model.dart        # User data model
│       ├── data/
│       │   └── providers/
│       │       └── chat_provider.dart     # Chat state management
│       └── presentation/
│           ├── pages/
│           │   └── chat_screen.dart       # Chat interface
│           └── widgets/
│               ├── chat_input.dart        # Message input widget
│               └── message_bubble.dart    # Message bubble widget
│
└── main.dart                              # App entry point
```

## 🎨 Features

### 1. Splash Screen
- Animated logo with scale and fade effects
- Gradient background (Saffron → Blue → White)
- Auto-navigation to users list after 3 seconds

### 2. Users List Screen
- Search functionality
- Online users horizontal scroll section
- Animated user cards with staggered entrance
- Online/offline status indicators
- Pull-to-refresh capability

### 3. Chat Screen
- Real-time message display
- Message bubbles with timestamps
- Read receipts (double tick)
- Smooth animations
- Voice and attachment options
- User online status in app bar

## 🎨 Color Scheme

- **Saffron (Bhagwa)**: `#FF9933` - Primary actions, gradients
- **Blue**: `#1976D2` - Secondary elements, links
- **White**: `#FFFFFF` - Backgrounds, text on colored surfaces
- **Supporting Colors**: Grey shades for text hierarchy

## 🔧 Technologies Used

- **Flutter**: UI framework
- **GoRouter**: Navigation with custom transitions
- **Riverpod**: State management
- **Intl**: Date/time formatting

## 🚀 Key Features

1. **Clean Architecture**: Separation of concerns with features-based structure
2. **Reusable Components**: Custom widgets for consistency
3. **Smooth Animations**: Page transitions, list animations, micro-interactions
4. **State Management**: Riverpod for scalable state handling
5. **Type Safety**: Strong typing with models
6. **Responsive Design**: Adapts to different screen sizes

## 📱 Screens Flow

```
Splash Screen (3s)
    ↓
Users List Screen
    ↓ (tap on user)
Chat Screen
```

## 🎯 Best Practices Implemented

- Feature-first folder structure
- Separation of UI and business logic
- Reusable widget components
- Consistent theming
- Proper state management
- Clean code with meaningful names
- Type-safe navigation with GoRouter
