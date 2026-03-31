import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:nikki/models/novel.dart';
import 'package:nikki/models/word_entry.dart';
import 'package:nikki/providers/camera_provider.dart';
import 'package:nikki/providers/history_provider.dart';
import 'package:nikki/providers/explanation_provider.dart';
import 'package:nikki/core/constants/camera_colors.dart';
import 'package:nikki/theme/nikki_colors.dart';
import 'package:nikki/widgets/date_section_header.dart';
import 'package:nikki/widgets/explanation_sheet.dart';
import 'package:nikki/widgets/handle_draggable_sheet.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final TextEditingController _searchController = TextEditingController();
  bool _selectMode = false;
  final Set<int> _selectedIds = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<HistoryProvider>().loadEntries();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _enterSelectMode() {
    setState(() {
      _selectMode = true;
      _selectedIds.clear();
    });
  }

  void _exitSelectMode() {
    setState(() {
      _selectMode = false;
      _selectedIds.clear();
    });
  }

  void _toggleSelection(int id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
  }

  // _showActions is now handled by PopupMenuButton in the build method.

  void _showAddToNovelDialogForEntry(WordEntry entry) {
    final colors = NikkiColors.of(context);
    showDialog(
      context: context,
      barrierColor: colors.overlay,
      builder: (ctx) => _AddToNovelDialog(
        onSave: (novelId) {
          context.read<HistoryProvider>().assignToNovel([entry.id!], novelId);
        },
      ),
    );
  }

  void _deleteSelected() {
    if (_selectedIds.isEmpty) return;
    context.read<HistoryProvider>().deleteMultiple(_selectedIds.toList());
    _exitSelectMode();
  }

  void _showAddToNovelDialog() {
    if (_selectedIds.isEmpty) return;
    final colors = NikkiColors.of(context);
    showDialog(
      context: context,
      barrierColor: colors.overlay,
      builder: (ctx) => _AddToNovelDialog(
        onSave: (novelId) {
          context.read<HistoryProvider>().assignToNovel(_selectedIds.toList(), novelId);
          _exitSelectMode();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = NikkiColors.of(context);
    final historyProvider = context.watch<HistoryProvider>();

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: colors.background,
        body: SafeArea(
          child: Column(
            children: [
              // Top bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    IconButton(
                      icon: Icon(Icons.arrow_back, color: colors.textSecondary),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'History',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: colors.textPrimary,
                        ),
                      ),
                    ),
                    // Select / action buttons
                    if (_selectMode) ...[
                      PopupMenuButton<String>(
                        enabled: _selectedIds.isNotEmpty,
                        color: colors.card,
                        offset: const Offset(0, 40),
                        constraints: const BoxConstraints(minWidth: 180),
                        onSelected: (value) {
                          if (value == 'add_to_novel') {
                            _showAddToNovelDialog();
                          } else if (value == 'delete') {
                            _deleteSelected();
                          }
                        },
                        itemBuilder: (ctx) => [
                          const PopupMenuItem(
                            value: 'add_to_novel',
                            child: Text('Add to novel', style: TextStyle(fontSize: 14, color: CameraColors.darkTeal, fontWeight: FontWeight.w500)),
                          ),
                          const PopupMenuItem(
                            value: 'delete',
                            child: Text('Delete', style: TextStyle(fontSize: 14, color: CameraColors.dangerBorder, fontWeight: FontWeight.w500)),
                          ),
                        ],
                        child: Icon(
                          Icons.more_horiz,
                          color: _selectedIds.isNotEmpty ? colors.textSecondary : colors.textSecondary.withOpacity(0.3),
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 12),
                      GestureDetector(
                        onTap: _exitSelectMode,
                        child: Icon(Icons.close, color: colors.textSecondary, size: 24),
                      ),
                    ] else
                      GestureDetector(
                        onTap: historyProvider.entries.isNotEmpty ? _enterSelectMode : null,
                        child: Text(
                          'Select',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: historyProvider.entries.isNotEmpty
                                ? CameraColors.teal
                                : CameraColors.teal.withOpacity(0.3),
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              // Subtitle
              Padding(
                padding: const EdgeInsets.only(left: 60, bottom: 4),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'History is automatically cleared after 30 days',
                    style: TextStyle(fontSize: 12, color: colors.textSecondary),
                  ),
                ),
              ),

              // Search bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: TextField(
                  controller: _searchController,
                  onChanged: (query) => historyProvider.updateSearchQuery(query),
                  style: TextStyle(color: colors.textPrimary, fontSize: 15),
                  cursorColor: CameraColors.teal,
                  decoration: InputDecoration(
                    hintText: 'Search words...',
                    hintStyle: TextStyle(color: colors.textSecondary),
                    prefixIcon: Icon(Icons.search, color: colors.textSecondary),
                    filled: true,
                    fillColor: colors.inputFill,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: colors.inputBorder),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: CameraColors.teal, width: 1.5),
                    ),
                    contentPadding: const EdgeInsets.only(left: 0, right: 12, top: 12, bottom: 12),
                  ),
                ),
              ),

              // Selection count
              if (_selectMode && _selectedIds.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(left: 24, top: 8),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '${_selectedIds.length} selected',
                      style: const TextStyle(fontSize: 13, color: CameraColors.teal, fontWeight: FontWeight.w600),
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
    final colors = NikkiColors.of(context);
    if (provider.isLoading) {
      return const Center(child: CircularProgressIndicator(color: CameraColors.teal));
    }

    if (provider.entries.isEmpty) {
      return Center(
        child: Text(
          provider.searchQuery.isNotEmpty ? 'No results found.' : 'No saved words yet.',
          style: TextStyle(fontSize: 15, color: colors.textSecondary),
        ),
      );
    }

    final entries = provider.entries;

    return ListView.builder(
      itemCount: entries.length,
      itemBuilder: (context, index) {
        final entry = entries[index];
        final isSelected = _selectedIds.contains(entry.id);
        final showDateHeader = index == 0 ||
            !DateSectionHeader.sameDay(entries[index - 1].createdAt, entry.createdAt);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (showDateHeader) DateSectionHeader(timestamp: entry.createdAt),
            _WordListItem(
              entry: entry,
              selectMode: _selectMode,
              isSelected: isSelected,
              onTap: _selectMode
                  ? () => _toggleSelection(entry.id!)
                  : () => _showExplanationSheet(context, entry),
              onDelete: () => provider.deleteWord(entry.id!),
              onAddToNovel: () => _showAddToNovelDialogForEntry(entry),
            ),
          ],
        );
      },
    );
  }

  void _showExplanationSheet(BuildContext context, WordEntry entry) {
    final colors = NikkiColors.of(context);
    final explanationProvider = context.read<ExplanationProvider>();
    explanationProvider.showCachedExplanation(entry.selectedText, entry.explanationJson);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      backgroundColor: colors.dialogBg,
      builder: (sheetCtx) => HandleDraggableSheet(
        initialFraction: 0.9,
        maxFraction: 0.9,
        child: ExplanationSheet(
          mode: ExplanationSheetMode.history,
          onRemove: () {
            this.context.read<HistoryProvider>().deleteWord(entry.id!);
          },
          onAddToNovel: () {
            Navigator.pop(sheetCtx);
            _showAddToNovelDialogForEntry(entry);
          },
        ),
      ),
    );
  }
}

// ── Word list item with selection support ──

class _WordListItem extends StatefulWidget {
  final WordEntry entry;
  final bool selectMode;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback? onAddToNovel;

  const _WordListItem({
    required this.entry,
    required this.selectMode,
    required this.isSelected,
    required this.onTap,
    required this.onDelete,
    this.onAddToNovel,
  });

  @override
  State<_WordListItem> createState() => _WordListItemState();
}

class _WordListItemState extends State<_WordListItem>
    with SingleTickerProviderStateMixin {
  static const _actionWidth = 56.0;
  static const _actionCount = 2;
  static const _revealWidth = _actionWidth * _actionCount + 12;

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
  void didUpdateWidget(covariant _WordListItem old) {
    super.didUpdateWidget(old);
    // Close swipe actions when entering select mode.
    if (widget.selectMode && !old.selectMode && _isOpen) {
      _close();
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _onHorizontalDragUpdate(DragUpdateDetails details) {
    if (widget.selectMode) return;
    setState(() {
      _dragOffset = (_dragOffset + details.delta.dx).clamp(-_revealWidth, 0.0);
    });
  }

  void _onHorizontalDragEnd(DragEndDetails details) {
    if (widget.selectMode) return;
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
    final colors = NikkiColors.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: SizedBox(
        height: 70,
        child: Stack(
          children: [
            // Swipe action buttons (hidden in select mode)
            if (!widget.selectMode)
              Positioned(
                right: 0,
                top: 0,
                bottom: 0,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GestureDetector(
                      onTap: () {
                        _close();
                        widget.onAddToNovel?.call();
                      },
                      child: Container(
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
                    ),
                    const SizedBox(width: 4),
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

            // Foreground card
            Transform.translate(
              offset: Offset(widget.selectMode ? 0 : _dragOffset, 0),
              child: GestureDetector(
                onTap: _isOpen ? _close : widget.onTap,
                onHorizontalDragUpdate: _onHorizontalDragUpdate,
                onHorizontalDragEnd: _onHorizontalDragEnd,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: colors.card,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      // Tick checkbox (select mode only)
                      if (widget.selectMode) ...[
                        Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: widget.isSelected ? CameraColors.teal : Colors.transparent,
                            border: Border.all(
                              color: widget.isSelected ? CameraColors.teal : colors.textSecondary,
                              width: 1.5,
                            ),
                          ),
                          child: widget.isSelected
                              ? const Icon(Icons.check, size: 16, color: Colors.white)
                              : null,
                        ),
                        const SizedBox(width: 12),
                      ],
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              widget.entry.selectedText,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: colors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _getBriefMeaning(widget.entry.explanationJson),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 14,
                                color: colors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        _formatDate(widget.entry.createdAt),
                        style: TextStyle(fontSize: 12, color: colors.textSecondary),
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

// ── Add to Novel Dialog ──

class _AddToNovelDialog extends StatefulWidget {
  final void Function(int novelId) onSave;

  const _AddToNovelDialog({required this.onSave});

  @override
  State<_AddToNovelDialog> createState() => _AddToNovelDialogState();
}

class _AddToNovelDialogState extends State<_AddToNovelDialog> {
  int? _selectedNovelId;

  @override
  Widget build(BuildContext context) {
    final colors = NikkiColors.of(context);
    final novels = context.watch<CameraProvider>().novels;

    return Scaffold(
      backgroundColor: colors.overlay,
      resizeToAvoidBottomInset: false,
      body: Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 28, vertical: 80),
          constraints: const BoxConstraints(maxHeight: 500),
          decoration: BoxDecoration(
            color: colors.background,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 12, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'I wish to save these words to...',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Georgia',
                          color: colors.textPrimary,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: colors.textSecondary, width: 1.5),
                        ),
                        child: Icon(Icons.close, size: 14, color: colors.textSecondary),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Novel list
              Flexible(
                child: novels.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          'No novels created yet.',
                          style: TextStyle(fontSize: 14, color: colors.textSecondary),
                        ),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: novels.length,
                        itemBuilder: (context, index) {
                          final novel = novels[index];
                          final isSelected = _selectedNovelId == novel.id;
                          return GestureDetector(
                            onTap: () => setState(() => _selectedNovelId = novel.id),
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              decoration: BoxDecoration(
                                color: colors.card,
                                borderRadius: BorderRadius.circular(10),
                                border: isSelected
                                    ? Border.all(color: CameraColors.teal, width: 1.5)
                                    : null,
                              ),
                              child: Row(
                                children: [
                                  // Radio indicator
                                  Container(
                                    width: 20,
                                    height: 20,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: isSelected ? CameraColors.teal : colors.textSecondary,
                                        width: 1.5,
                                      ),
                                    ),
                                    child: isSelected
                                        ? Center(
                                            child: Container(
                                              width: 10,
                                              height: 10,
                                              decoration: const BoxDecoration(
                                                shape: BoxShape.circle,
                                                color: CameraColors.teal,
                                              ),
                                            ),
                                          )
                                        : null,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          novel.name,
                                          style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w600,
                                            color: colors.textPrimary,
                                          ),
                                        ),
                                        Text(
                                          novel.sourceLanguage,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: colors.textSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),

              // Save button
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
                child: SizedBox(
                  width: double.infinity,
                  child: GestureDetector(
                    onTap: _selectedNovelId != null
                        ? () {
                            widget.onSave(_selectedNovelId!);
                            Navigator.pop(context);
                          }
                        : null,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: _selectedNovelId != null
                            ? CameraColors.darkTeal
                            : Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Text(
                          'Save',
                          style: TextStyle(
                            color: _selectedNovelId != null ? Colors.white : Colors.grey,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
