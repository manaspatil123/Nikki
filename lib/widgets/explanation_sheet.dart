import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:nikki/core/constants/camera_colors.dart';
import 'package:nikki/models/explanation.dart';
import 'package:nikki/providers/explanation_provider.dart';
import 'package:nikki/providers/settings_provider.dart';
import 'package:nikki/widgets/shimmer_box.dart';

enum ExplanationSheetMode { camera, history }

class ExplanationSheet extends StatelessWidget {
  final ExplanationSheetMode mode;
  final VoidCallback? onRemove;

  const ExplanationSheet({
    super.key,
    this.mode = ExplanationSheetMode.camera,
    this.onRemove,
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
    );
  }
}

class _SaveButton extends StatelessWidget {
  const _SaveButton();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ExplanationProvider>();
    final saved = provider.isSaved;

    return GestureDetector(
      onTap: saved ? null : () => provider.saveToHistory(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
        decoration: BoxDecoration(
          color: saved ? CameraColors.darkTeal : Colors.white,
          border: Border.all(color: CameraColors.darkTeal, width: 1.5),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Text(
          saved ? 'Saved' : 'Save',
          style: TextStyle(
            color: saved ? Colors.white : CameraColors.darkTeal,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _AddToNovelButton extends StatelessWidget {
  const _AddToNovelButton();

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        // TODO: add to novel
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: CameraColors.darkTeal, width: 1.5),
          borderRadius: BorderRadius.circular(24),
        ),
        child: const Text(
          'Add to novel',
          style: TextStyle(
            color: CameraColors.darkTeal,
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
    return GestureDetector(
      onTap: () {
        onRemove?.call();
        Navigator.of(context).pop();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: CameraColors.dangerBorder, width: 2.0),
          borderRadius: BorderRadius.circular(24),
        ),
        child: const Text(
          'Remove from History',
          style: TextStyle(
            color: CameraColors.dangerBorder,
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

  const _ExplanationBody({
    required this.selectedText,
    required this.explanation,
    required this.mode,
    this.onRemove,
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

  @override
  Widget build(BuildContext context) {
    final isHistory = widget.mode == ExplanationSheetMode.history;
    final titleSize = _fontSize + 10;
    final readingSize = _fontSize + 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Top row: zoom controls + save/add button
        Padding(
          padding: const EdgeInsets.only(left: 16, right: 20, top: 10),
          child: Row(
            children: [
              // Font size controls
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
                const _AddToNovelButton()
              else
                const _SaveButton(),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.selectedText,
                  style: TextStyle(
                    fontSize: titleSize,
                    fontWeight: FontWeight.bold,
                    fontFamily: _fontFamily,
                    color: Colors.black,
                  ),
                ),
                if (widget.explanation.reading != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    widget.explanation.reading!,
                    style: TextStyle(
                      fontSize: readingSize,
                      fontFamily: _fontFamily,
                      color: CameraColors.brown,
                    ),
                  ),
                ],
                const Divider(height: 24, color: CameraColors.brown),
                if (widget.explanation.meaning != null)
                  _Section(title: 'MEANING', child: Text(widget.explanation.meaning!, style: _bodyStyle)),
                if (widget.explanation.context != null)
                  _Section(title: 'CONTEXT', child: Text(widget.explanation.context!, style: _bodyStyle)),
                if (widget.explanation.breakdown != null)
                  _Section(title: 'BREAKDOWN', child: Text(widget.explanation.breakdown!, style: _bodyStyle)),
                if (widget.explanation.formality != null)
                  _Section(title: 'FORMALITY', child: Text(widget.explanation.formality!, style: _bodyStyle)),
                if (widget.explanation.examples != null && widget.explanation.examples!.isNotEmpty)
                  _Section(
                    title: 'EXAMPLES',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: widget.explanation.examples!
                          .map((e) => Padding(
                                padding: const EdgeInsets.symmetric(vertical: 2),
                                child: Text('\u2022  $e', style: _bodyStyle),
                              ))
                          .toList(),
                    ),
                  ),
                if (!isHistory && widget.explanation.similarWords != null && widget.explanation.similarWords!.isNotEmpty)
                  _SimilarWordsSection(
                    selectedText: widget.selectedText,
                    similarWords: widget.explanation.similarWords!,
                  ),
                if (isHistory) ...[
                  const SizedBox(height: 24),
                  Center(child: _RemoveButton(onRemove: widget.onRemove)),
                ],
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ],
    );
  }

  TextStyle get _bodyStyle => TextStyle(
        fontSize: _fontSize,
        fontFamily: _fontFamily,
        color: Colors.black,
        height: 1.5,
      );
}

class _FontSizeControls extends StatelessWidget {
  final VoidCallback? onDecrease;
  final VoidCallback? onIncrease;

  const _FontSizeControls({this.onDecrease, this.onIncrease});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: CameraColors.brown, width: 1),
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
                color: onDecrease != null ? CameraColors.brown : CameraColors.brown.withOpacity(0.3),
              ),
            ),
          ),
          Container(width: 1, height: 20, color: CameraColors.brown),
          GestureDetector(
            onTap: onIncrease,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: Icon(
                Icons.add,
                size: 18,
                color: onIncrease != null ? CameraColors.brown : CameraColors.brown.withOpacity(0.3),
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
    final settings = context.read<SettingsProvider>();
    final explanationProvider = context.read<ExplanationProvider>();

    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Text(
              'SIMILAR WORDS',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.5,
                color: CameraColors.brown,
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
                        border: Border.all(color: CameraColors.brown),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(sw.word, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black)),
                          Text(
                            sw.reading,
                            style: const TextStyle(
                              fontSize: 12,
                              color: CameraColors.brown,
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
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.5,
                color: CameraColors.brown,
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
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: provider.dismissComparison,
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.arrow_back, size: 20, color: CameraColors.brown),
                SizedBox(width: 4),
                Text('Back', style: TextStyle(fontSize: 14, color: CameraColors.brown)),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(comparison.wordA.word, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black)),
                Text(
                  comparison.wordA.reading,
                  style: const TextStyle(fontSize: 14, color: CameraColors.brown),
                ),
              ],
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                'vs',
                style: TextStyle(fontSize: 16, color: CameraColors.brown),
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(comparison.wordB.word, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black)),
                Text(
                  comparison.wordB.reading,
                  style: const TextStyle(fontSize: 14, color: CameraColors.brown),
                ),
              ],
            ),
          ],
        ),
        const Divider(height: 24, color: CameraColors.brown),
        _Section(title: 'DIFFERENCE', child: Text(comparison.difference, style: const TextStyle(fontSize: 15, color: Colors.black))),
        _Section(title: 'NUANCE', child: Text(comparison.nuance, style: const TextStyle(fontSize: 15, color: Colors.black))),
        _Section(
          title: 'EXAMPLES',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${comparison.wordA.word}: ${comparison.exampleA}', style: const TextStyle(fontSize: 15, color: Colors.black)),
              const SizedBox(height: 8),
              Text('${comparison.wordB.word}: ${comparison.exampleB}', style: const TextStyle(fontSize: 15, color: Colors.black)),
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
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline,
              size: 48,
              color: CameraColors.brown,
            ),
            const SizedBox(height: 16),
            Text(
              error,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                color: CameraColors.brown,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
