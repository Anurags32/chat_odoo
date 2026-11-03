import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

class EmojiPickerWidget extends StatefulWidget {
  final Function(String emoji) onEmojiSelected;
  final VoidCallback? onBackspace;

  const EmojiPickerWidget({
    super.key,
    required this.onEmojiSelected,
    this.onBackspace,
  });

  @override
  State<EmojiPickerWidget> createState() => _EmojiPickerWidgetState();
}

class _EmojiPickerWidgetState extends State<EmojiPickerWidget>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  static const List<String> _smileys = [
    '😀', '😃', '😄', '😁', '😆', '😅', '😂', '🤣', '😊', '😇',
    '🙂', '🙃', '😉', '😌', '😍', '🥰', '😘', '😗', '😙', '😚',
    '😋', '😛', '😝', '😜', '🤪', '🤨', '🧐', '🤓', '😎', '🥸',
    '🤩', '🥳', '😏', '😒', '😞', '😔', '😟', '😕', '🙁', '☹️',
    '😣', '😖', '😫', '😩', '🥺', '😢', '😭', '😤', '😠', '😡',
    '🤬', '🤯', '😳', '🥵', '🥶', '😱', '😨', '😰', '😥', '😓',
    '🤗', '🤔', '🤭', '🤫', '🤥', '😶', '😐', '😑', '😬', '🙄',
  ];

  static const List<String> _gestures = [
    '👍', '👎', '👊', '✊', '🤛', '🤜', '🤞', '✌️', '🤟', '🤘',
    '👌', '🤏', '👈', '👉', '👆', '👇', '☝️', '✋', '🤚', '🖐️',
    '🖖', '👋', '🤙', '💪', '🦾', '🖕', '✍️', '🙏', '👏', '🤝',
  ];

  static const List<String> _hearts = [
    '❤️', '🧡', '💛', '💚', '💙', '💜', '🖤', '🤍', '🤎', '💔',
    '❣️', '💕', '💞', '💓', '💗', '💖', '💘', '💝', '💟', '💌',
    '💯', '💢', '💥', '💫', '💦', '💨', '🕳️', '💣', '💬', '👁️‍🗨️',
  ];

  static const List<String> _animals = [
    '🐶', '🐱', '🐭', '🐹', '🐰', '🦊', '🐻', '🐼', '🐻‍❄️', '🐨',
    '🐯', '🦁', '🐮', '🐷', '🐸', '🐵', '🐔', '🐧', '🐦', '🐤',
    '🦆', '🦅', '🦉', '🦇', '🐺', '🐗', '🐴', '🦄', '🐝', '🪱',
    '🐛', '🦋', '🐌', '🐞', '🐜', '🪰', '🪲', '🪳', '🦟', '🦗',
  ];

  static const List<String> _activities = [
    '⚽', '🏀', '🏈', '⚾', '🥎', '🎾', '🏐', '🏉', '🥏', '🎱',
    '🪀', '🏓', '🏸', '🏒', '🏑', '🥍', '🏏', '🪃', '🥅', '⛳',
    '🪁', '🏹', '🎣', '🤿', '🥊', '🥋', '🎽', '🛹', '🛼', '🛷',
    '⛸️', '🥌', '🎿', '⛷️', '🏂', '🪂', '🏋️', '🤼', '🤸', '⛹️',
  ];

  static const List<String> _objects = [
    '🔥', '✨', '🎉', '🎊', '🎈', '🎁', '🏆', '🥇', '🥈', '🥉',
    '📱', '📲', '💻', '⌨️', '🖥️', '🖨️', '🖱️', '📷', '📸', '📹',
    '💡', '🔦', '🏮', '🪔', '💵', '💴', '💶', '💷', '🪙', '💰',
    '🚗', '🚕', '🚙', '🚌', '🚎', '🏎️', '🚓', '🚑', '🚒', '✈️',
  ];

  final List<String> _allEmojis = [
    ..._smileys,
    ..._gestures,
    ..._hearts,
    ..._animals,
    ..._activities,
    ..._objects,
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Widget _buildEmojiGrid(List<String> emojis) {
    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
      ),
      itemCount: emojis.length,
      itemBuilder: (context, index) {
        final emoji = emojis[index];
        return InkWell(
          onTap: () => widget.onEmojiSelected(emoji),
          borderRadius: BorderRadius.circular(8),
          child: Center(
            child: Text(
              emoji,
              style: const TextStyle(fontSize: 26),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: 280,
      color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
      child: Column(
        children: [
          // Search & Backspace Row
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 8, 4),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    height: 36,
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppColors.darkSurfaceElevated
                          : AppColors.lightSurfaceElevated,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: TextField(
                      controller: _searchController,
                      onChanged: (val) => setState(() => _searchQuery = val),
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark
                            ? AppColors.darkTextPrimary
                            : AppColors.lightTextPrimary,
                      ),
                      decoration: const InputDecoration(
                        hintText: 'Search emoji...',
                        hintStyle: TextStyle(fontSize: 12),
                        border: InputBorder.none,
                        isDense: true,
                        prefixIcon: Icon(Icons.search_rounded, size: 16),
                        prefixIconConstraints: BoxConstraints(minWidth: 24),
                      ),
                    ),
                  ),
                ),
                if (widget.onBackspace != null) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.backspace_outlined, size: 20),
                    color: isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.lightTextSecondary,
                    onPressed: widget.onBackspace,
                  ),
                ],
              ],
            ),
          ),

          // Categories Tab Bar or Search Results
          if (_searchQuery.isNotEmpty)
            Expanded(
              child: _buildEmojiGrid(
                _allEmojis
                    .where((e) => e.contains(_searchQuery))
                    .toList(),
              ),
            )
          else ...[
            TabBar(
              controller: _tabController,
              isScrollable: false,
              indicatorColor: AppColors.primary,
              indicatorWeight: 2,
              tabs: const [
                Tab(text: '😀'),
                Tab(text: '👍'),
                Tab(text: '❤️'),
                Tab(text: '🐶'),
                Tab(text: '⚽'),
                Tab(text: '💡'),
              ],
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildEmojiGrid(_smileys),
                  _buildEmojiGrid(_gestures),
                  _buildEmojiGrid(_hearts),
                  _buildEmojiGrid(_animals),
                  _buildEmojiGrid(_activities),
                  _buildEmojiGrid(_objects),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

