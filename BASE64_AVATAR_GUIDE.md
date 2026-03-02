# Base64 Avatar Implementation Guide

## Overview
This guide explains how to display base64-encoded avatar images from your `/chat/users` API.

## Changes Made

### 1. Updated ApiUserModel
- Changed `avatarUrl` (String) → `avatar` (String?)
- Made it nullable to handle users without avatars
- Added `hasAvatar` getter for convenience

### 2. Created Base64Avatar Widget
**Location:** `lib/core/widgets/base64_avatar.dart`

A reusable widget that:
- Decodes base64 strings to display images
- Handles data URI prefixes (e.g., `data:image/png;base64,`)
- Shows fallback text avatar if image fails
- Includes comprehensive error handling

**Usage:**
```dart
Base64Avatar(
  base64String: user.avatar,
  radius: 20,
  fallbackText: user.name,
  backgroundColor: Colors.blue,
  textColor: Colors.white,
)
```

### 3. Created UserAvatarWidget
**Location:** `lib/core/widgets/user_avatar_widget.dart`

A specialized widget that:
- Uses Base64Avatar internally
- Shows online/offline/away status indicator
- Customizable radius and colors
- Automatically determines status color

**Usage:**
```dart
UserAvatarWidget(
  user: user,
  radius: 24,
  showOnlineIndicator: true,
)
```

### 4. Updated Existing Screens
- `api_users_screen.dart` - Now uses UserAvatarWidget
- `real_chat_screen.dart` - Now uses UserAvatarWidget in two places

## API Response Format

Your API returns:
```json
{
  "success": true,
  "users": [
    {
      "id": 9,
      "name": "shital",
      "email": "shital@gmail.com",
      "partner_id": 60,
      "avatar": "iVBORw0KGgoAAAANSUhEUgAAAIAAAACACAIAAABMXPacAAB9...",
      "im_status": "offline"
    }
  ]
}
```

## Status Indicators

The `UserAvatarWidget` automatically shows colored dots based on `im_status`:
- **online** → Green dot
- **away** → Orange dot
- **offline** → Grey dot

## Example: Complete User List Screen

See `lib/features/chat/presentation/pages/users_list_screen.dart` for a complete example showing:
- Fetching users from API
- Displaying avatars in a list
- Showing status chips
- Handling loading and error states
- User detail dialog

## Fallback Behavior

If the avatar fails to load or is null:
1. Shows a circular avatar with the user's first initial
2. Uses the specified background color (default: blue)
3. White text for the initial

## Performance Notes

- Base64 decoding happens once per widget build
- Images are cached by Flutter's MemoryImage
- Minimal memory footprint for small avatars
- Error handling prevents crashes from malformed data

## Testing

To test with your API:
1. Ensure your API returns base64 strings in the `avatar` field
2. The widget handles both raw base64 and data URI formats
3. Check console for any decoding errors

## Troubleshooting

**Avatar not showing:**
- Check if `user.avatar` is not null
- Verify base64 string is valid
- Check console for decoding errors

**Status indicator not showing:**
- Ensure `im_status` field is present in API response
- Valid values: "online", "away", "offline"

**Performance issues:**
- Consider using smaller avatar images
- Implement pagination for large user lists
