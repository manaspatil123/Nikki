import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:nikki/core/constants/camera_colors.dart';
import 'package:nikki/theme/nikki_colors.dart';
import 'package:nikki/models/explanation.dart';
import 'package:nikki/providers/explanation_provider.dart';
import 'package:nikki/providers/settings_provider.dart';
import 'package:nikki/widgets/shimmer_box.dart';

enum ExplanationSheetMode { camera, history, novelDetail }

class ExplanationSheet extends StatelessWidget {
  final ExplanationSheetMode mode;
  final VoidCallback? onRemove;
  final VoidCallback? onAddToNovel;
  final Widget? notesWidget;

  const ExplanationSheet({
    super.key,
    this.mode = ExplanationSheetMode.camera,
    this.onRemove,
    this.onAddToNovel,
    this.notesWidget,
  });

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ExplanationProvider>();

    if (provider.showComparison) {
      return _ComparisonContent(provider: provider);
    }

    if (provider.isLoading) {
      return const ShimmerContent();
    }

    if (provider.error != null) {
      return _ErrorContent(error: provider.error!);
    }

    final explanation = provider.explanation;
    if (explanation == null) {
      return const SizedBox.shrink();
    }

    return _ExplanationBody(
      selectedText: provider.selectedText,
      explanation: explanation,
      mode: mode,
      onRemove: onRemove,
      onAddToNovel: onAddToNovel,
      notesWidget: notesWidget,
    );
  }
}

class _SaveButton extends StatelessWidget {
  const _SaveButton();

  @override
  Widget build(BuildContext context) {
    final colors = NikkiColors.of(context);
    final provider = context.watch<ExplanationProvider>();
    final saved = provider.isSaved;

    return GestureDetector(
      onTap: saved ? null : () => provider.saveToHistory(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
        decoration: BoxDecoration(
          color: saved ? CameraColors.darkTeal : colors.card,
          border: Border.all(color: CameraColors.darkTeal, width: 1.5),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Text(
          saved ? 'Saved' : 'Save',
          style: TextStyle(
            color: saved ? Colors.white : colors.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _AddToNovelButton extends StatelessWidget {
  final VoidCallback? onTap;

  const _AddToNovelButton({this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
        decoration: BoxDecoration(
          color: isDark ? Colors.transparent : Colors.white,
          border: Border.all(color: isDark ? Colors.white : CameraColors.darkTeal, width: 1.5),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Text(
          'Add to novel',
          style: TextStyle(
            color: isDark ? Colors.white : CameraColors.darkTeal,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _RemoveButton extends StatelessWidget {
  final VoidCallback? onRemove;

  const _RemoveButton({required this.onRemove});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: () {
        onRemove?.call();
        Navigator.of(context).pop();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
        decoration: BoxDecoration(
          color: isDark ? CameraColors.dangerBorder : Colors.white,
          border: Border.all(color: CameraColors.dangerBorder, width: 2.0),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Text(
          'Remove from History',
          style: TextStyle(
            color: isDark ? Colors.white : CameraColors.dangerBorder,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _ExplanationBody extends StatefulWidget {
  final String selectedText;
  final Explanation explanation;
  final ExplanationSheetMode mode;
  final VoidCallback? onRemove;
  final VoidCallback? onAddToNovel;
  final Widget? notesWidget;

  const _ExplanationBody({
    required this.selectedText,
    required this.explanation,
    required this.mode,
    this.onRemove,
    this.onAddToNovel,
    this.notesWidget,
  });

  @override
  State<_ExplanationBody> createState() => _ExplanationBodyState();
}

class _ExplanationBodyState extends State<_ExplanationBody> {
  static const _minFontSize = 14.0;
  static const _maxFontSize = 24.0;
  static const _defaultFontSize = 17.0;
  static const _fontStep = 1.5;
  static const _fontFamily = 'Georgia';

  double _fontSize = _defaultFontSize;
  final ScrollController _scrollController = ScrollController();
  double _lastKeyboardHeight = 0;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = NikkiColors.of(context);
    final isHistory = widget.mode == ExplanationSheetMode.history;
    final isNovelDetail = widget.mode == ExplanationSheetMode.novelDetail;
    final hideSimWords = isHistory || isNovelDetail;
    final titleSize = _fontSize + 10;
    final readingSize = _fontSize + 1;

    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;

    // Auto-scroll to bottom when keyboard opens (so notes are visible).
    if (keyboardHeight > 0 && _lastKeyboardHeight == 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
          );
        }
      });
    }
    _lastKeyboardHeight = keyboardHeight;

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: SingleChildScrollView(
        controller: _scrollController,
        padding: EdgeInsets.fromLTRB(20, 10, 20, 20 + keyboardHeight),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top row: zoom controls + save/add button
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  _FontSizeControls(
                    onDecrease: _fontSize > _minFontSize
                        ? () => setState(() => _fontSize = (_fontSize - _fontStep).clamp(_minFontSize, _maxFontSize))
                        : null,
                    onIncrease: _fontSize < _maxFontSize
                        ? () => setState(() => _fontSize = (_fontSize + _fontStep).clamp(_minFontSize, _maxFontSize))
                        : null,
                  ),
                  const Spacer(),
                  if (isHistory)
                    _AddToNovelButton(onTap: widget.onAddToNovel)
                  else if (!isNovelDetail)
                    const _SaveButton(),
                ],
              ),
            ),
            Text(
                  widget.selectedText,
                  style: TextStyle(
                    fontSize: titleSize,
                    fontWeight: FontWeight.bold,
                    fontFamily: _fontFamily,
                    color: colors.textPrimary,
                  ),
                ),
                if (widget.explanation.reading != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    widget.explanation.reading!,
                    style: TextStyle(
                      fontSize: readingSize,
                      fontFamily: _fontFamily,
                      color: colors.textSecondary,
                    ),
                  ),
                ],
                Divider(height: 24, color: colors.divider),
                if (widget.explanation.meaning != null)
                  _Section(title: 'MEANING', child: Text(widget.explanation.meaning!, style: _bodyStyle(colors))),
                if (widget.explanation.context != null)
                  _Section(title: 'CONTEXT', child: Text(widget.explanation.context!, style: _bodyStyle(colors))),
                if (widget.explanation.breakdown != null)
                  _Section(title: 'BREAKDOWN', child: Text(widget.explanation.breakdown!, style: _bodyStyle(colors))),
                if (widget.explanation.formality != null)
                  _Section(title: 'FORMALITY', child: Text(widget.explanation.formality!, style: _bodyStyle(colors))),
                if (widget.explanation.examples != null && widget.explanation.examples!.isNotEmpty)
                  _Section(
                    title: 'EXAMPLES',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: widget.explanation.examples!
                          .map((e) => Padding(
                                padding: const EdgeInsets.symmetric(vertical: 2),
                                child: Text('\u2022  $e', style: _bodyStyle(colors)),
                              ))
                          .toList(),
                    ),
                  ),
                if (!hideSimWords && widget.explanation.similarWords != null && widget.explanation.similarWords!.isNotEmpty)
                  _SimilarWordsSection(
                    selectedText: widget.selectedText,
                    similarWords: widget.explanation.similarWords!,
                  ),
                if (widget.notesWidget != null)
                  widget.notesWidget!,
                if (isHistory || isNovelDetail) ...[
                  const SizedBox(height: 24),
                  Center(child: _RemoveButton(onRemove: widget.onRemove)),
                ],
                const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  TextStyle _bodyStyle(NikkiColors colors) => TextStyle(
        fontSize: _fontSize,
        fontFamily: _fontFamily,
        color: colors.textPrimary,
        height: 1.5,
      );
}

class _FontSizeControls extends StatelessWidget {
  final VoidCallback? onDecrease;
  final VoidCallback? onIncrease;

  const _FontSizeControls({this.onDecrease, this.onIncrease});

  @override
  Widget build(BuildContext context) {
    final colors = NikkiColors.of(context);
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: colors.textSecondary, width: 1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: onDecrease,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: Icon(
                Icons.remove,
                size: 18,
                color: onDecrease != null ? colors.textSecondary : colors.textSecondary.withOpacity(0.3),
              ),
            ),
          ),
          Container(width: 1, height: 20, color: colors.textSecondary),
          GestureDetector(
            onTap: onIncrease,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: Icon(
                Icons.add,
                size: 18,
                color: onIncrease != null ? colors.textSecondary : colors.textSecondary.withOpacity(0.3),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SimilarWordsSection extends StatelessWidget {
  final String selectedText;
  final List<SimilarWord> similarWords;

  const _SimilarWordsSection({
    required this.selectedText,
    required this.similarWords,
  });

  @override
  Widget build(BuildContext context) {
    final colors = NikkiColors.of(context);
    final settings = context.read<SettingsProvider>();
    final explanationProvider = context.read<ExplanationProvider>();

    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              'SIMILAR WORDS',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.5,
                color: colors.textSecondary,
              ),
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: similarWords.map((sw) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () {
                      explanationProvider.compare(
                        originalWord: selectedText,
                        similarWord: sw,
                        sourceLanguage: settings.sourceLanguage,
                        targetLanguage: settings.targetLanguage,
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        border: Border.all(color: colors.textSecondary),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(sw.word, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: colors.textPrimary)),
                          Text(
                            sw.reading,
                            style: TextStyle(
                              fontSize: 12,
                              color: colors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final Widget child;

  const _Section({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    final colors = NikkiColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              title,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.5,
                color: colors.textSecondary,
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }
}

class _ComparisonContent extends StatelessWidget {
  final ExplanationProvider provider;

  const _ComparisonContent({required this.provider});

  @override
  Widget build(BuildContext context) {
    final colors = NikkiColors.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: provider.dismissComparison,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.arrow_back, size: 20, color: colors.textSecondary),
                const SizedBox(width: 4),
                Text('Back', style: TextStyle(fontSize: 14, color: colors.textSecondary)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (provider.isComparisonLoading)
            const ShimmerContent()
          else if (provider.comparisonError != null)
            _ErrorContent(error: provider.comparisonError!)
          else if (provider.comparison != null)
            _ComparisonBody(comparison: provider.comparison!),
        ],
      ),
    );
  }
}

class _ComparisonBody extends StatelessWidget {
  final ComparisonResult comparison;

  const _ComparisonBody({required this.comparison});

  @override
  Widget build(BuildContext context) {
    final colors = NikkiColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(comparison.wordA.word, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: colors.textPrimary)),
                Text(
                  comparison.wordA.reading,
                  style: TextStyle(fontSize: 14, color: colors.textSecondary),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                'vs',
                style: TextStyle(fontSize: 16, color: colors.textSecondary),
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(comparison.wordB.word, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: colors.textPrimary)),
                Text(
                  comparison.wordB.reading,
                  style: TextStyle(fontSize: 14, color: colors.textSecondary),
                ),
              ],
            ),
          ],
        ),
        Divider(height: 24, color: colors.divider),
        _Section(title: 'DIFFERENCE', child: Text(comparison.difference, style: TextStyle(fontSize: 15, color: colors.textPrimary))),
        _Section(title: 'NUANCE', child: Text(comparison.nuance, style: TextStyle(fontSize: 15, color: colors.textPrimary))),
        _Section(
          title: 'EXAMPLES',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${comparison.wordA.word}: ${comparison.exampleA}', style: TextStyle(fontSize: 15, color: colors.textPrimary)),
              const SizedBox(height: 8),
              Text('${comparison.wordB.word}: ${comparison.exampleB}', style: TextStyle(fontSize: 15, color: colors.textPrimary)),
            ],
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }
}

class _ErrorContent extends StatelessWidget {
  final String error;

  const _ErrorContent({required this.error});

  @override
  Widget build(BuildContext context) {
    final colors = NikkiColors.of(context);
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              size: 48,
              color: colors.textSecondary,
            ),
            const SizedBox(height: 16),
            Text(
              error,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: colors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
