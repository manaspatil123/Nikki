import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:nikki/core/constants/camera_colors.dart';
import 'package:nikki/theme/nikki_colors.dart';
import 'package:nikki/data/word_repository.dart';
import 'package:nikki/widgets/date_section_header.dart';
import 'package:nikki/models/novel.dart';
import 'package:nikki/models/word_entry.dart';
import 'package:nikki/widgets/explanation_sheet.dart';
import 'package:nikki/widgets/handle_draggable_sheet.dart';
import 'package:provider/provider.dart';
import 'package:nikki/providers/explanation_provider.dart';

class NovelDetailScreen extends StatefulWidget {
  final Novel novel;
  /// Called when the user taps "Start Reading" — should navigate to camera.
  final VoidCallback? onStartReading;

  const NovelDetailScreen({super.key, required this.novel, this.onStartReading});

  @override
  State<NovelDetailScreen> createState() => _NovelDetailScreenState();
}

class _NovelDetailScreenState extends State<NovelDetailScreen> {
  final WordRepository _wordRepo = WordRepository();
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _pinnedSearchFocus = FocusNode();
  List<WordEntry> _entries = [];
  String _searchQuery = '';
  bool _isLoading = true;
  bool _selectMode = false;
  final Set<int> _selectedIds = {};
  double _scrollOffset = 0;
  bool _searchActive = false;
  bool _suppressSearchExit = false;

  /// Scroll offset at which the pinned bar appears.
  static const _stickyThreshold = 300.0;

  @override
  void initState() {
    super.initState();
    _loadEntries(showLoading: true);
    _scrollController.addListener(_onScroll);
    _pinnedSearchFocus.addListener(_onSearchFocusChanged);
  }

  void _onSearchFocusChanged() {
    final focused = _pinnedSearchFocus.hasFocus;
    if (focused && !_searchActive) {
      setState(() => _searchActive = true);
    } else if (!focused && _searchQuery.isEmpty && _searchActive) {
      setState(() => _searchActive = false);
      // Scroll back to top when exiting search with empty query.
      if (_scrollController.hasClients) {
        _scrollController.animateTo(0,
            duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
      }
    }
  }

  void _onScroll() {
    final offset = _scrollController.offset;
    if (offset != _scrollOffset) {
      setState(() => _scrollOffset = offset);
    }
  }

  void _onInlineSearchTap() {
    // Scroll past the threshold so the pinned bar appears, then focus it.
    final target = _stickyThreshold;
    _scrollController.animateTo(
      target,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    ).then((_) {
      if (mounted) _pinnedSearchFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _pinnedSearchFocus.removeListener(_onSearchFocusChanged);
    _pinnedSearchFocus.dispose();
    super.dispose();
  }

  bool get _showStickyBar => _searchActive || _scrollOffset >= _stickyThreshold;

  Future<void> _loadEntries({bool showLoading = false}) async {
    if (showLoading) setState(() => _isLoading = true);
    if (_searchQuery.isNotEmpty) {
      _entries = await _wordRepo.searchEntries(widget.novel.id!, _searchQuery);
    } else {
      _entries = await _wordRepo.getEntriesByNovel(widget.novel.id!);
    }
    if (mounted) setState(() => _isLoading = false);
  }

  void _onSearchChanged(String query) {
    _searchQuery = query;
    _loadEntries();
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

  void _deleteSelected() {
    if (_selectedIds.isEmpty) return;
    _wordRepo.deleteMultiple(_selectedIds.toList());
    _exitSelectMode();
    _loadEntries();
  }

  void _removeSelectedFromNovel() {
    if (_selectedIds.isEmpty) return;
    _wordRepo.removeFromNovel(_selectedIds.toList());
    _exitSelectMode();
    _loadEntries();
  }

  void _showWordSheet(WordEntry entry) {
    // Dismiss keyboard before opening the sheet.
    _pinnedSearchFocus.unfocus();

    final colors = NikkiColors.of(context);
    final explanationProvider = context.read<ExplanationProvider>();
    explanationProvider.showCachedExplanation(entry.selectedText, entry.explanationJson);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: colors.dialogBg,
      barrierColor: Colors.black54,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => HandleDraggableSheet(
        initialFraction: 0.75,
        maxFraction: 0.75,
        child: ExplanationSheet(
          mode: ExplanationSheetMode.novelDetail,
          onRemove: () {
            _wordRepo.delete(entry.id!);
            // Don't pop here — _RemoveButton already pops the sheet.
            _loadEntries();
          },
          notesWidget: _NotesArea(
            initialNotes: entry.notes,
            onSave: (notes) => _wordRepo.updateNotes(entry.id!, notes),
          ),
        ),
      ),
    ).whenComplete(() {
      // Reload entries so notes changes are reflected in the list.
      if (mounted) _loadEntries();
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = NikkiColors.of(context);
    final sticky = _showStickyBar;

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top bar — back arrow + novel title (fades in) + select controls
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
                    child: AnimatedOpacity(
                      opacity: sticky ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 200),
                      child: Text(
                        widget.novel.name,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: colors.textPrimary,
                        ),
                        overflow: TextOverflow.ellipsis,
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
                        if (value == 'remove_from_novel') {
                          _removeSelectedFromNovel();
                        } else if (value == 'delete') {
                          _deleteSelected();
                        }
                      },
                      itemBuilder: (ctx) => [
                        const PopupMenuItem(
                          value: 'remove_from_novel',
                          child: Text('Remove from novel', style: TextStyle(fontSize: 14, color: CameraColors.darkTeal, fontWeight: FontWeight.w500)),
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
                      onTap: _entries.isNotEmpty ? _enterSelectMode : null,
                      child: Text(
                        'Select',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: _entries.isNotEmpty
                              ? CameraColors.teal
                              : CameraColors.teal.withOpacity(0.3),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Scrollable content + pinned bar overlay
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: CameraColors.teal))
                  : Stack(
                      children: [
                        CustomScrollView(
                      controller: _scrollController,
                      slivers: [
                        // Header slivers — hidden during active search
                        if (!_searchActive) ...[
                          // "You're reading" label
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.only(left: 24, right: 16, bottom: 12),
                              child: Text(
                                "You're reading",
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: colors.textPrimary,
                                ),
                              ),
                            ),
                          ),

                          // Novel info card
                          SliverToBoxAdapter(
                            child: _NovelInfoBox(novel: widget.novel),
                          ),

                          // Start Reading button (full width, scrolls away)
                          if (widget.onStartReading != null)
                            SliverToBoxAdapter(
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                                child: GestureDetector(
                                  onTap: widget.onStartReading,
                                  child: Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                    decoration: BoxDecoration(
                                      color: CameraColors.darkTeal,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Center(
                                      child: Text(
                                        'Start Reading',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),

                          // Search bar placeholder — tapping scrolls up and focuses the pinned bar
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                              child: GestureDetector(
                                onTap: _onInlineSearchTap,
                                child: Container(
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: colors.inputFill,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: colors.inputBorder),
                                  ),
                                  child: Row(
                                    children: [
                                      const SizedBox(width: 12),
                                      Icon(Icons.search, color: colors.textSecondary),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Search words...',
                                        style: TextStyle(color: colors.textSecondary, fontSize: 15),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),

                          // "Words Learnt" heading
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(24, 8, 24, 4),
                              child: Text(
                                'Words Learnt',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 1,
                                  color: colors.textSecondary,
                                ),
                              ),
                            ),
                          ),
                        ],

                        // Selection count
                        if (_selectMode && _selectedIds.isNotEmpty)
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.only(left: 24, top: 8),
                              child: Text(
                                '${_selectedIds.length} selected',
                                style: const TextStyle(fontSize: 13, color: CameraColors.teal, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ),

                        // Word list
                        if (_entries.isEmpty)
                          SliverFillRemaining(
                            hasScrollBody: false,
                            child: Center(
                              child: Text(
                                _searchActive
                                    ? 'No results found.'
                                    : 'No words saved yet.\nStart reading to add words.',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 15, color: colors.textSecondary),
                              ),
                            ),
                          )
                        else
                          SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (context, index) {
                                final entry = _entries[index];
                                final isSelected = _selectedIds.contains(entry.id);
                                final showDateHeader = index == 0 ||
                                    !DateSectionHeader.sameDay(
                                        _entries[index - 1].createdAt, entry.createdAt);
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (showDateHeader)
                                      DateSectionHeader(timestamp: entry.createdAt),
                                    _WordItem(
                                      entry: entry,
                                      selectMode: _selectMode,
                                      isSelected: isSelected,
                                      onTap: _selectMode
                                          ? () => _toggleSelection(entry.id!)
                                          : () => _showWordSheet(entry),
                                      onDelete: () {
                                        _wordRepo.delete(entry.id!);
                                        _loadEntries();
                                      },
                                      onRemoveFromNovel: () {
                                        _wordRepo.removeFromNovel([entry.id!]);
                                        _loadEntries();
                                      },
                                    ),
                                  ],
                                );
                              },
                              childCount: _entries.length,
                            ),
                          ),
                      ],
                    ),
                        // Pinned search + Read bar overlay
                        Positioned(
                          top: 0,
                          left: 0,
                          right: 0,
                          child: IgnorePointer(
                            ignoring: !sticky,
                            child: AnimatedOpacity(
                              opacity: sticky ? 1.0 : 0.0,
                              duration: const Duration(milliseconds: 200),
                              child: Container(
                                color: colors.background,
                                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                                child: Row(
                                  children: [
                                    Expanded(
                                      flex: 3,
                                      child: SizedBox(
                                        height: 44,
                                        child: TextField(
                                          controller: _searchController,
                                          focusNode: _pinnedSearchFocus,
                                          onChanged: _onSearchChanged,
                                          scribbleEnabled: false,
                                          style: TextStyle(color: colors.textPrimary, fontSize: 15),
                                          cursorColor: CameraColors.teal,
                                          decoration: InputDecoration(
                                            hintText: 'Search words...',
                                            hintStyle: TextStyle(color: colors.textSecondary),
                                            prefixIcon: Icon(Icons.search, color: colors.textSecondary, size: 20),
                                            suffixIcon: _searchQuery.isNotEmpty
                                                ? GestureDetector(
                                                    onTap: () {
                                                      _searchController.clear();
                                                      _onSearchChanged('');
                                                      _pinnedSearchFocus.unfocus();
                                                    },
                                                    child: Container(
                                                      width: 20,
                                                      height: 20,
                                                      margin: const EdgeInsets.all(10),
                                                      decoration: BoxDecoration(
                                                        shape: BoxShape.circle,
                                                        color: colors.textSecondary.withOpacity(0.3),
                                                      ),
                                                      child: Icon(Icons.close, size: 14, color: colors.textPrimary),
                                                    ),
                                                  )
                                                : null,
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
                                            contentPadding: const EdgeInsets.only(left: 0, right: 12, top: 0, bottom: 0),
                                          ),
                                        ),
                                      ),
                                    ),
                                    if (widget.onStartReading != null) ...[
                                      const SizedBox(width: 8),
                                      Expanded(
                                        flex: 1,
                                        child: GestureDetector(
                                          onTap: widget.onStartReading,
                                          child: Container(
                                            height: 44,
                                            decoration: BoxDecoration(
                                              color: CameraColors.darkTeal,
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: const Center(
                                              child: Text(
                                                'Read',
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    ),
    );
  }
}

// ── Novel info box ──

class _NovelInfoBox extends StatelessWidget {
  final Novel novel;

  const _NovelInfoBox({required this.novel});

  @override
  Widget build(BuildContext context) {
    final colors = NikkiColors.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: colors.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: CameraColors.teal, width: 1.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              novel.name,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: colors.textPrimary,
              ),
            ),
            if (novel.description.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                novel.description,
                style: TextStyle(fontSize: 14, color: colors.textPrimary),
              ),
            ],
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.language, size: 14, color: CameraColors.teal),
                const SizedBox(width: 4),
                Text(
                  '${novel.sourceLanguage} → ${novel.targetLanguage}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: CameraColors.teal,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Created on ${_formatDate(novel.createdAt)}',
              style: TextStyle(fontSize: 12, color: colors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  static String _formatDate(int millis) {
    final date = DateTime.fromMillisecondsSinceEpoch(millis);
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }
}

// ── Word list item with swipe actions + selection support ──

class _WordItem extends StatefulWidget {
  final WordEntry entry;
  final bool selectMode;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback onRemoveFromNovel;

  const _WordItem({
    required this.entry,
    required this.selectMode,
    required this.isSelected,
    required this.onTap,
    required this.onDelete,
    required this.onRemoveFromNovel,
  });

  @override
  State<_WordItem> createState() => _WordItemState();
}

class _WordItemState extends State<_WordItem>
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
  void didUpdateWidget(covariant _WordItem old) {
    super.didUpdateWidget(old);
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
                        widget.onRemoveFromNovel();
                      },
                      child: Container(
                        width: _actionWidth,
                        margin: const EdgeInsets.symmetric(vertical: 2),
                        decoration: BoxDecoration(
                          color: CameraColors.teal,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Center(
                          child: Icon(Icons.link_off, color: Colors.white, size: 24),
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
                      if (widget.entry.notes.isNotEmpty && !widget.selectMode)
                        Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: Icon(Icons.sticky_note_2_outlined, size: 16, color: colors.divider),
                        ),
                      const SizedBox(width: 8),
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
      if (map['is_comparison'] == true) {
        return map['difference'] as String? ?? '';
      }
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

// ── Notes area (auto-saves on close, expands sheet when focused) ──

class _NotesArea extends StatefulWidget {
  final String initialNotes;
  final Future<void> Function(String notes) onSave;

  const _NotesArea({required this.initialNotes, required this.onSave});

  @override
  State<_NotesArea> createState() => _NotesAreaState();
}

class _NotesAreaState extends State<_NotesArea> {
  late TextEditingController _controller;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialNotes);
    _focusNode.addListener(_onFocusChange);
  }

  void _onFocusChange() {
    if (_focusNode.hasFocus) {
      // When notes are tapped, expand the sheet to full page
      // by finding the HandleDraggableSheet ancestor and snapping to max.
      // We do this by scrolling the sheet — the Scaffold will resize.
    }
    if (!_focusNode.hasFocus) {
      // Auto-save when focus is lost.
      _save();
    }
  }

  void _save() {
    final text = _controller.text.trim();
    if (text != widget.initialNotes) {
      widget.onSave(text);
    }
  }

  @override
  void dispose() {
    _save();
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = NikkiColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: colors.inputFill,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: colors.inputBorder),
        ),
        child: TextField(
          controller: _controller,
          focusNode: _focusNode,
          maxLines: null,
          minLines: 3,
          style: TextStyle(fontSize: 14, color: colors.textPrimary, fontFamily: 'Georgia'),
          cursorColor: CameraColors.teal,
          decoration: InputDecoration(
            hintText: 'Add notes...',
            hintStyle: TextStyle(color: colors.textSecondary.withOpacity(0.4)),
            border: InputBorder.none,
            isDense: true,
            contentPadding: EdgeInsets.zero,
          ),
        ),
      ),
    );
  }
}
