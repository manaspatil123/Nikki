import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:nikki/core/constants/camera_colors.dart';
import 'package:nikki/models/explanation.dart';
import 'package:nikki/providers/explanation_provider.dart';
import 'package:nikki/providers/settings_provider.dart';
import 'package:nikki/widgets/shimmer_box.dart';

class ExplanationSheet extends StatelessWidget {
  const ExplanationSheet({super.key});

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
    );
  }
}

class _SaveButton extends StatelessWidget {
  const _SaveButton();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: Padding(
        padding: const EdgeInsets.only(right: 20, top: 10),
        child: GestureDetector(
          onTap: () {
            // TODO: manual save action
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: CameraColors.darkTeal, width: 1.5),
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Text(
              'Save',
              style: TextStyle(
                color: CameraColors.darkTeal,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ExplanationBody extends StatelessWidget {
  final String selectedText;
  final Explanation explanation;

  const _ExplanationBody({
    required this.selectedText,
    required this.explanation,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SaveButton(),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  selectedText,
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                if (explanation.reading != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    explanation.reading!,
                    style: const TextStyle(
                      fontSize: 17,
                      color: CameraColors.brown,
                    ),
                  ),
                ],
                const Divider(height: 24, color: CameraColors.brown),
                if (explanation.meaning != null)
                  _Section(title: 'MEANING', child: Text(explanation.meaning!, style: const TextStyle(fontSize: 15, color: Colors.black))),
                if (explanation.context != null)
                  _Section(title: 'CONTEXT', child: Text(explanation.context!, style: const TextStyle(fontSize: 15, color: Colors.black))),
                if (explanation.breakdown != null)
                  _Section(title: 'BREAKDOWN', child: Text(explanation.breakdown!, style: const TextStyle(fontSize: 15, color: Colors.black))),
                if (explanation.formality != null)
                  _Section(title: 'FORMALITY', child: Text(explanation.formality!, style: const TextStyle(fontSize: 15, color: Colors.black))),
                if (explanation.examples != null && explanation.examples!.isNotEmpty)
                  _Section(
                    title: 'EXAMPLES',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: explanation.examples!
                          .map((e) => Padding(
                                padding: const EdgeInsets.symmetric(vertical: 2),
                                child: Text('\u2022  $e', style: const TextStyle(fontSize: 15, color: Colors.black)),
                              ))
                          .toList(),
                    ),
                  ),
                if (explanation.similarWords != null && explanation.similarWords!.isNotEmpty)
                  _SimilarWordsSection(
                    selectedText: selectedText,
                    similarWords: explanation.similarWords!,
                  ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ],
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
