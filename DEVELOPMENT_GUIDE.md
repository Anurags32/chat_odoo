# 🛠️ Development Guide

## Project Overview

This is a modern Flutter chat application with clean architecture, smooth animations, and beautiful UI.

## 🏗️ Architecture Principles

### 1. Feature-First Structure
Each feature is self-contained with its own:
- Domain layer (models, entities)
- Data layer (providers, repositories)
- Presentation layer (pages, widgets)

### 2. Clean Code Practices
- **Single Responsibility**: Each class has one job
- **DRY (Don't Repeat Yourself)**: Reusable components
- **SOLID Principles**: Maintainable and scalable code
- **Type Safety**: Strong typing throughout

### 3. State Management
Using **Riverpod** for:
- Predictable state changes
- Easy testing
- Better performance
- Type-safe providers

## 📂 Folder Structure Explained

```
lib/
├── core/                           # Shared across features
│   ├── router/
│   │   └── app_router.dart        # Navigation configuration
│   ├── theme/
│   │   ├── app_colors.dart        # Color constants
│   │   └── app_theme.dart         # Theme configuration
│   └── widgets/
│       ├── custom_button.dart     # Reusable button
│       └── custom_text_field.dart # Reusable input field
│
├── features/                       # Feature modules
│   ├── splash/
│   │   └── presentation/
│   │       └── pages/
│   │           └── splash_screen.dart
│   │
│   ├── users/
│   │   ├── data/
│   │   │   └── providers/
│   │   │       └── users_provider.dart    # User state
│   │   └── presentation/
│   │       ├── pages/
│   │       │   └── users_list_screen.dart # Main users page
│   │       └── widgets/
│   │           └── user_card.dart         # User list item
│   │
│   └── chat/
│       ├── domain/
│       │   └── models/
│       │       ├── message_model.dart     # Message entity
│       │       └── user_model.dart        # User entity
│       ├── data/
│       │   └── providers/
│       │       └── chat_provider.dart     # Chat state
│       └── presentation/
│           ├── pages/
│           │   └── chat_screen.dart       # Chat interface
│           └── widgets/
│               ├── chat_input.dart        # Message input
│               └── message_bubble.dart    # Message display
│
└── main.dart                              # App entry point
```

## 🎨 Theming System

### Color Scheme
Located in `lib/core/theme/app_colors.dart`:

```dart
// Primary colors
saffronPrimary: #FF9933  // Main actions
bluePrimary: #1976D2     // Secondary elements
white: #FFFFFF           // Backgrounds

// Gradients
primaryGradient: Saffron → Light Saffron
blueGradient: Blue → Light Blue
```

### Theme Configuration
Located in `lib/core/theme/app_theme.dart`:
- Material 3 design
- Custom color scheme
- Consistent component styling
- Elevation and shadows

## 🔄 State Management with Riverpod

### Provider Types Used

1. **StateNotifierProvider** - For mutable state
```dart
final usersProvider = StateNotifierProvider<UsersNotifier, List<UserModel>>(
  (ref) => UsersNotifier(),
);
```

2. **Usage in Widgets**
```dart
class MyWidget extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final users = ref.watch(usersProvider);
    return ListView(...);
  }
}
```

## 🧭 Navigation with GoRouter

### Route Configuration
Located in `lib/core/router/app_router.dart`:

```dart
static const String splash = '/';
static const String usersList = '/users';
static const String chat = '/chat';
```

### Custom Transitions
- **Fade**: Splash screen
- **Slide**: Users list and chat screens
- **Smooth curves**: easeInOut animations

### Navigation Usage
```dart
// Navigate to route
context.go(AppRouter.usersList);

// Navigate with data
context.push(AppRouter.chat, extra: user);

// Go back
context.pop();
```

## 🎭 Animation Guidelines

### 1. Page Transitions
- Use `CustomTransitionPage` in GoRouter
- Duration: 300ms
- Curves: easeInOut, easeIn, easeOut

### 2. List Animations
- Staggered entrance
- Fade + Slide combination
- Delay based on index

### 3. Micro-interactions
- Button press feedback
- Input field focus
- Message send animation

## 📝 Code Style Guide

### Naming Conventions
- **Classes**: PascalCase (`UserCard`, `ChatScreen`)
- **Variables**: camelCase (`userName`, `messageList`)
- **Constants**: camelCase with const (`primaryColor`)
- **Private**: prefix with _ (`_buildWidget`)

### Widget Organization
```dart
class MyWidget extends StatelessWidget {
  // 1. Constructor
  const MyWidget({super.key});
  
  // 2. Build method
  @override
  Widget build(BuildContext context) {
    return Container();
  }
  
  // 3. Private helper methods
  Widget _buildSection() {
    return Container();
  }
}
```

### File Organization
- One widget per file
- File name matches class name (snake_case)
- Group related widgets in same folder

## 🧪 Testing Strategy

### Unit Tests
- Test models and business logic
- Test state management
- Test utility functions

### Widget Tests
- Test individual widgets
- Test user interactions
- Test navigation

### Integration Tests
- Test complete user flows
- Test data persistence
- Test API integration

## 🚀 Adding New Features

### Step-by-Step Process

1. **Create Feature Folder**
```
features/
└── new_feature/
    ├── domain/
    ├── data/
    └── presentation/
```

2. **Define Models** (domain/models/)
```dart
class MyModel {
  final String id;
  final String name;
  
  MyModel({required this.id, required this.name});
}
```

3. **Create Provider** (data/providers/)
```dart
class MyNotifier extends StateNotifier<MyState> {
  MyNotifier() : super(MyState.initial());
}

final myProvider = StateNotifierProvider<MyNotifier, MyState>(
  (ref) => MyNotifier(),
);
```

4. **Build UI** (presentation/)
- Create page
- Create widgets
- Connect to provider

5. **Add Route** (core/router/)
```dart
GoRoute(
  path: '/my-feature',
  builder: (context, state) => MyFeaturePage(),
),
```

## 🔧 Common Tasks

### Add New User
Edit `lib/features/users/data/providers/users_provider.dart`:
```dart
UserModel(
  id: '9',
  name: 'New User',
  avatar: '👤',
  status: 'Available',
  isOnline: true,
),
```

### Change Colors
Edit `lib/core/theme/app_colors.dart`:
```dart
static const Color saffronPrimary = Color(0xFFYOURCOLOR);
```

### Add New Widget
1. Create file in appropriate widgets folder
2. Make it reusable with parameters
3. Use consistent styling from theme
4. Add to exports if needed

### Modify Animation
```dart
AnimationController(
  duration: const Duration(milliseconds: 500), // Change duration
  vsync: this,
);
```

## 📦 Dependencies Management

### Adding New Package
1. Add to `pubspec.yaml`
2. Run `flutter pub get`
3. Import in files
4. Document usage

### Updating Packages
```bash
flutter pub outdated
flutter pub upgrade
```

## 🐛 Debugging Tips

### Common Issues

1. **State not updating**
   - Check provider is watched correctly
   - Verify state is being modified
   - Use `ref.read()` for one-time reads

2. **Navigation not working**
   - Check route paths
   - Verify GoRouter configuration
   - Check for typos in route names

3. **Animations stuttering**
   - Reduce animation complexity
   - Check for heavy computations
   - Use `const` constructors

### Debug Tools
```bash
# Check for issues
flutter analyze

# Format code
flutter format .

# Run with verbose logging
flutter run -v
```

## 📚 Best Practices

1. **Always use const constructors** when possible
2. **Extract widgets** when they get complex
3. **Use meaningful names** for variables and functions
4. **Comment complex logic** but keep code self-documenting
5. **Handle errors gracefully** with try-catch
6. **Test on multiple devices** and screen sizes
7. **Keep widgets small** (< 300 lines)
8. **Use theme colors** instead of hardcoded values
9. **Optimize images** before adding to assets
10. **Follow Flutter style guide**

## 🎯 Performance Tips

1. Use `const` constructors
2. Avoid rebuilding entire trees
3. Use `ListView.builder` for long lists
4. Implement pagination for large datasets
5. Cache images and data
6. Use `RepaintBoundary` for complex widgets
7. Profile with DevTools

## 📖 Resources

- [Flutter Documentation](https://flutter.dev/docs)
- [Riverpod Documentation](https://riverpod.dev)
- [GoRouter Documentation](https://pub.dev/packages/go_router)
- [Material Design 3](https://m3.material.io)

---

Happy Coding! 🚀
