import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:nikki/models/novel.dart';
import 'package:nikki/models/word_entry.dart';
import 'package:nikki/providers/history_provider.dart';
import 'package:nikki/providers/explanation_provider.dart';
import 'package:nikki/providers/settings_provider.dart';
import 'package:nikki/core/constants/camera_colors.dart';
import 'package:nikki/widgets/explanation_sheet.dart';
import 'package:nikki/widgets/handle_draggable_sheet.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final historyProvider = context.watch<HistoryProvider>();

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // Top bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.settings_outlined),
                    onPressed: () => Navigator.pushNamed(context, '/settings'),
                  ),
                ],
              ),
            ),

            // Novel tabs
            SizedBox(
              height: 48,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                itemCount: historyProvider.novels.length + 1,
                itemBuilder: (context, index) {
                  if (index == historyProvider.novels.length) {
                    return _AddNovelTab(onTap: () => _showCreateNovelDialog(context));
                  }
                  final novel = historyProvider.novels[index];
                  final isSelected = novel.id == historyProvider.selectedNovelId;
                  return _NovelTab(
                    name: novel.name,
                    isSelected: isSelected,
                    onTap: () => historyProvider.selectNovel(novel.id!),
                    onLongPress: () => _showNovelOptionsDialog(context, novel),
                  );
                },
              ),
            ),

            Divider(height: 1, color: theme.dividerColor),

            // Search bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: TextField(
                controller: _searchController,
                onChanged: (query) => historyProvider.updateSearchQuery(query),
                decoration: InputDecoration(
                  hintText: 'Search words...',
                  hintStyle: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.4)),
                  prefixIcon: Icon(Icons.search, color: theme.colorScheme.onSurface.withOpacity(0.4)),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: theme.dividerColor),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: theme.colorScheme.onSurface),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
            ),

            // Word list
            Expanded(
              child: _buildWordList(context, historyProvider),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWordList(BuildContext context, HistoryProvider provider) {
    final theme = Theme.of(context);

    if (provider.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (provider.novels.isEmpty) {
      return Center(
        child: Text(
          'No novels yet.\nTap + to create one.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, color: theme.colorScheme.onSurface.withOpacity(0.5)),
        ),
      );
    }

    if (provider.entries.isEmpty) {
      return Center(
        child: Text(
          provider.searchQuery.isNotEmpty ? 'No results found.' : 'No saved words yet.',
          style: TextStyle(fontSize: 14, color: theme.colorScheme.onSurface.withOpacity(0.5)),
        ),
      );
    }

    return ListView.builder(
      itemCount: provider.entries.length,
      itemBuilder: (context, index) {
        final entry = provider.entries[index];
        return _WordListItem(
          entry: entry,
          onTap: () => _showExplanationSheet(context, entry),
          onDismissed: () => provider.deleteWord(entry.id!),
        );
      },
    );
  }

  void _showExplanationSheet(BuildContext context, WordEntry entry) {
    final explanationProvider = context.read<ExplanationProvider>();
    explanationProvider.showCachedExplanation(entry.selectedText, entry.explanationJson);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      backgroundColor: CameraColors.linen,
      builder: (context) => const HandleDraggableSheet(
        initialFraction: 0.6,
        maxFraction: 0.9,
        child: ExplanationSheet(),
      ),
    );
  }

  void _showCreateNovelDialog(BuildContext context) {
    final nameController = TextEditingController();
    final settings = context.read<SettingsProvider>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New Novel'),
        content: TextField(
          controller: nameController,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Novel name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final name = nameController.text.trim();
              if (name.isNotEmpty) {
                context.read<HistoryProvider>().createNovel(
                      name,
                      settings.sourceLanguage,
                      settings.targetLanguage,
                    );
                Navigator.pop(ctx);
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  void _showNovelOptionsDialog(BuildContext context, Novel novel) {
    showDialog(
      context: context,
      builder: (ctx) => SimpleDialog(
        children: [
          SimpleDialogOption(
            onPressed: () {
              Navigator.pop(ctx);
              _showRenameDialog(context, novel);
            },
            child: const Text('Rename'),
          ),
          SimpleDialogOption(
            onPressed: () {
              Navigator.pop(ctx);
              _showDeleteNovelDialog(context, novel);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showRenameDialog(BuildContext context, Novel novel) {
    final nameController = TextEditingController(text: novel.name);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename Novel'),
        content: TextField(
          controller: nameController,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Novel name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final name = nameController.text.trim();
              if (name.isNotEmpty) {
                context.read<HistoryProvider>().renameNovel(novel.id!, name);
                Navigator.pop(ctx);
              }
            },
            child: const Text('Rename'),
          ),
        ],
      ),
    );
  }

  void _showDeleteNovelDialog(BuildContext context, Novel novel) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Novel'),
        content: Text("Delete '${novel.name}' and all its words?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              context.read<HistoryProvider>().deleteNovel(novel.id!);
              Navigator.pop(ctx);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

class _NovelTab extends StatelessWidget {
  final String name;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _NovelTab({
    required this.name,
    required this.isSelected,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isSelected ? theme.colorScheme.onSurface : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          name,
          style: TextStyle(
            fontSize: 14,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: theme.colorScheme.onSurface,
          ),
        ),
      ),
    );
  }
}

class _AddNovelTab extends StatelessWidget {
  final VoidCallback onTap;

  const _AddNovelTab({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        alignment: Alignment.center,
        child: Icon(Icons.add, size: 20, color: theme.colorScheme.onSurface.withOpacity(0.6)),
      ),
    );
  }
}

class _WordListItem extends StatelessWidget {
  final WordEntry entry;
  final VoidCallback onTap;
  final VoidCallback onDismissed;

  const _WordListItem({
    required this.entry,
    required this.onTap,
    required this.onDismissed,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dismissible(
      key: ValueKey(entry.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: Colors.red,
        child: const Text('Delete', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
      ),
      onDismissed: (_) => onDismissed(),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.selectedText,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _getBriefMeaning(entry.explanationJson),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        color: theme.colorScheme.onSurface.withOpacity(0.6),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Text(
                _formatDate(entry.createdAt),
                style: TextStyle(
                  fontSize: 12,
                  color: theme.colorScheme.onSurface.withOpacity(0.5),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getBriefMeaning(String json) {
    try {
      final map = jsonDecode(json) as Map<String, dynamic>;
      return map['meaning'] as String? ?? map['reading'] as String? ?? '';
    } catch (_) {
      return '';
    }
  }

  String _formatDate(int millis) {
    final date = DateTime.fromMillisecondsSinceEpoch(millis);
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[date.month - 1]} ${date.day}';
  }
}
