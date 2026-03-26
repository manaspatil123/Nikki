import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:nikki/models/word_entry.dart';
import 'package:nikki/providers/history_provider.dart';
import 'package:nikki/providers/explanation_provider.dart';
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
  void initState() {
    super.initState();
    // Refresh entries when screen opens (picks up newly saved words)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<HistoryProvider>().loadEntries();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final historyProvider = context.watch<HistoryProvider>();

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
      backgroundColor: CameraColors.linen,
      body: SafeArea(
        child: Column(
          children: [
            // Top bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: CameraColors.brown),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'History',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                ],
              ),
            ),

            // Subtitle
            const Padding(
              padding: EdgeInsets.only(left: 60, bottom: 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'History is automatically cleared after 30 days',
                  style: TextStyle(
                    fontSize: 12,
                    color: CameraColors.brown,
                  ),
                ),
              ),
            ),

            // Search bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: TextField(
                controller: _searchController,
                onChanged: (query) => historyProvider.updateSearchQuery(query),
                style: const TextStyle(color: Colors.black, fontSize: 15),
                cursorColor: CameraColors.teal,
                decoration: InputDecoration(
                  hintText: 'Search words...',
                  hintStyle: const TextStyle(color: CameraColors.brown),
                  prefixIcon: const Icon(Icons.search, color: CameraColors.brown),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: CameraColors.caramel),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: CameraColors.teal, width: 1.5),
                  ),
                  contentPadding: const EdgeInsets.only(left: 0, right: 12, top: 12, bottom: 12),
                ),
              ),
            ),

            const SizedBox(height: 8),

            // Word list
            Expanded(
              child: _buildWordList(context, historyProvider),
            ),
          ],
        ),
      ),
    ),
    );
  }

  Widget _buildWordList(BuildContext context, HistoryProvider provider) {
    if (provider.isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: CameraColors.teal),
      );
    }

    if (provider.entries.isEmpty) {
      return Center(
        child: Text(
          provider.searchQuery.isNotEmpty ? 'No results found.' : 'No saved words yet.',
          style: const TextStyle(fontSize: 15, color: CameraColors.brown),
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
          onDelete: () => provider.deleteWord(entry.id!),
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
      builder: (context) => HandleDraggableSheet(
        initialFraction: 0.6,
        maxFraction: 0.9,
        child: ExplanationSheet(
          mode: ExplanationSheetMode.history,
          onRemove: () {
            this.context.read<HistoryProvider>().deleteWord(entry.id!);
          },
        ),
      ),
    );
  }
}

class _WordListItem extends StatefulWidget {
  final WordEntry entry;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _WordListItem({
    required this.entry,
    required this.onTap,
    required this.onDelete,
  });

  @override
  State<_WordListItem> createState() => _WordListItemState();
}

class _WordListItemState extends State<_WordListItem>
    with SingleTickerProviderStateMixin {
  static const _actionWidth = 56.0;
  static const _actionCount = 2;
  static const _revealWidth = _actionWidth * _actionCount + 12; // + gaps

  late AnimationController _animController;
  double _dragOffset = 0;
  bool _isOpen = false;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    )..addListener(() {
        setState(() => _dragOffset = _animController.value * -_revealWidth);
      });
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _onHorizontalDragUpdate(DragUpdateDetails details) {
    setState(() {
      _dragOffset = (_dragOffset + details.delta.dx).clamp(-_revealWidth, 0.0);
    });
  }

  void _onHorizontalDragEnd(DragEndDetails details) {
    final velocity = details.velocity.pixelsPerSecond.dx;
    if (velocity < -300 || _dragOffset < -_revealWidth / 2) {
      _animController.value = _dragOffset / -_revealWidth;
      _animController.animateTo(1.0, curve: Curves.easeOut);
      _isOpen = true;
    } else {
      _animController.value = _dragOffset / -_revealWidth;
      _animController.animateTo(0.0, curve: Curves.easeOut);
      _isOpen = false;
    }
  }

  void _close() {
    _animController.animateTo(0.0, curve: Curves.easeOut);
    _isOpen = false;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: SizedBox(
        height: 70,
        child: Stack(
          children: [
            // Action buttons — behind the card
            Positioned(
              right: 0,
              top: 0,
              bottom: 0,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Blue note button
                  Container(
                    width: _actionWidth,
                    margin: const EdgeInsets.symmetric(vertical: 2),
                    decoration: BoxDecoration(
                      color: CameraColors.teal,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Center(
                      child: Icon(Icons.edit_note, color: Colors.white, size: 26),
                    ),
                  ),
                  const SizedBox(width: 4),
                  // Red delete button
                  GestureDetector(
                    onTap: () {
                      _close();
                      widget.onDelete();
                    },
                    child: Container(
                      width: _actionWidth,
                      margin: const EdgeInsets.symmetric(vertical: 2),
                      decoration: BoxDecoration(
                        color: CameraColors.dangerBorder,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Center(
                        child: Icon(Icons.delete_outline, color: Colors.white, size: 24),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Foreground card — slides left
            Transform.translate(
              offset: Offset(_dragOffset, 0),
              child: GestureDetector(
                onTap: _isOpen ? _close : widget.onTap,
                onHorizontalDragUpdate: _onHorizontalDragUpdate,
                onHorizontalDragEnd: _onHorizontalDragEnd,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              widget.entry.selectedText,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _getBriefMeaning(widget.entry.explanationJson),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 14,
                                color: CameraColors.brown,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        _formatDate(widget.entry.createdAt),
                        style: const TextStyle(
                          fontSize: 12,
                          color: CameraColors.brown,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
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
