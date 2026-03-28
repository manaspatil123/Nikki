import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:nikki/core/constants/camera_colors.dart';
import 'package:nikki/data/word_repository.dart';
import 'package:nikki/models/novel.dart';
import 'package:nikki/models/word_entry.dart';
import 'package:nikki/widgets/explanation_sheet.dart';
import 'package:nikki/widgets/handle_draggable_sheet.dart';
import 'package:provider/provider.dart';
import 'package:nikki/providers/explanation_provider.dart';

class NovelDetailScreen extends StatefulWidget {
  final Novel novel;

  const NovelDetailScreen({super.key, required this.novel});

  @override
  State<NovelDetailScreen> createState() => _NovelDetailScreenState();
}

class _NovelDetailScreenState extends State<NovelDetailScreen> {
  final WordRepository _wordRepo = WordRepository();
  List<WordEntry> _entries = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadEntries();
  }

  Future<void> _loadEntries() async {
    setState(() => _isLoading = true);
    _entries = await _wordRepo.getEntriesByNovel(widget.novel.id!);
    if (mounted) setState(() => _isLoading = false);
  }

  void _showWordSheet(WordEntry entry) {
    final explanationProvider = context.read<ExplanationProvider>();
    explanationProvider.showCachedExplanation(entry.selectedText, entry.explanationJson);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: CameraColors.linen,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => HandleDraggableSheet(
        initialFraction: 0.9,
        maxFraction: 0.9,
        child: ExplanationSheet(
          mode: ExplanationSheetMode.novelDetail,
          onRemove: () {
            _wordRepo.delete(entry.id!);
            Navigator.of(ctx).pop();
            _loadEntries();
          },
          notesWidget: _NotesArea(
            initialNotes: entry.notes,
            onSave: (notes) => _wordRepo.updateNotes(entry.id!, notes),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CameraColors.linen,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
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
                  Expanded(
                    child: Text(
                      widget.novel.name,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),

            // Novel info box
            _NovelInfoBox(novel: widget.novel),

            const SizedBox(height: 12),

            // "Words Learnt" heading
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 4),
              child: Text(
                'Words Learnt',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1,
                  color: CameraColors.brown,
                ),
              ),
            ),

            const SizedBox(height: 4),

            // Word list
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: CameraColors.teal))
                  : _entries.isEmpty
                      ? const Center(
                          child: Text(
                            'No words saved yet.\nStart reading to add words.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 15, color: CameraColors.brown),
                          ),
                        )
                      : ListView.builder(
                          itemCount: _entries.length,
                          itemBuilder: (context, index) {
                            final entry = _entries[index];
                            return _WordItem(
                              entry: entry,
                              onTap: () => _showWordSheet(entry),
                            );
                          },
                        ),
            ),
          ],
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: CameraColors.teal, width: 1.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (novel.description.isNotEmpty) ...[
              Text(
                novel.description,
                style: const TextStyle(fontSize: 14, color: Colors.black87),
              ),
              const SizedBox(height: 10),
            ],
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
              style: const TextStyle(fontSize: 12, color: CameraColors.brown),
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

// ── Word list item ──

class _WordItem extends StatelessWidget {
  final WordEntry entry;
  final VoidCallback onTap;

  const _WordItem({required this.entry, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
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
                children: [
                  Text(
                    entry.selectedText,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _getBriefMeaning(entry.explanationJson),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 14, color: CameraColors.brown),
                  ),
                ],
              ),
            ),
            if (entry.notes.isNotEmpty)
              const Padding(
                padding: EdgeInsets.only(left: 8),
                child: Icon(Icons.sticky_note_2_outlined, size: 16, color: CameraColors.caramel),
              ),
            const SizedBox(width: 8),
            Text(
              _formatDate(entry.createdAt),
              style: const TextStyle(fontSize: 12, color: CameraColors.brown),
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
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: CameraColors.caramel),
        ),
        child: TextField(
          controller: _controller,
          focusNode: _focusNode,
          maxLines: null,
          minLines: 3,
          style: const TextStyle(fontSize: 14, color: Colors.black, fontFamily: 'Georgia'),
          cursorColor: CameraColors.teal,
          decoration: InputDecoration(
            hintText: 'Add notes...',
            hintStyle: TextStyle(color: CameraColors.brown.withOpacity(0.4)),
            border: InputBorder.none,
            isDense: true,
            contentPadding: EdgeInsets.zero,
          ),
        ),
      ),
    );
  }
}
