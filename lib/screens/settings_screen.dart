import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:nikki/models/explanation_category.dart';
import 'package:nikki/providers/settings_provider.dart';
import 'package:nikki/providers/history_provider.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  static const _sourceLanguages = [
    'Japanese',
    'Korean',
    'Chinese (Simplified)',
    'Chinese (Traditional)',
    'French',
    'German',
    'Spanish',
    'Italian',
    'Portuguese',
    'Russian',
    'Arabic',
  ];

  static const _targetLanguages = [
    'English',
    'Japanese',
    'Korean',
    'Chinese',
    'Spanish',
    'French',
    'German',
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final settings = context.watch<SettingsProvider>();

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
                  const SizedBox(width: 12),
                  const Text(
                    'Settings',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),

            Expanded(
              child: ListView(
                children: [
                  _SectionHeader('EXPLANATION CATEGORIES'),
                  ...ExplanationCategory.values.map((cat) => _CategoryToggle(
                        category: cat,
                        isEnabled: settings.enabledCategories.contains(cat),
                        onToggle: () => settings.toggleCategory(cat),
                      )),

                  const SizedBox(height: 24),
                  _SectionHeader('DEFAULTS'),
                  _LanguageRow(
                    label: 'Source Language',
                    value: settings.sourceLanguage,
                    onTap: () => _showLanguageDialog(
                      context,
                      title: 'Source Language',
                      languages: _sourceLanguages,
                      selected: settings.sourceLanguage,
                      onSelect: (lang) => settings.setSourceLanguage(lang),
                    ),
                  ),
                  _buildDivider(theme),
                  _LanguageRow(
                    label: 'Target Language',
                    value: settings.targetLanguage,
                    onTap: () => _showLanguageDialog(
                      context,
                      title: 'Target Language',
                      languages: _targetLanguages,
                      selected: settings.targetLanguage,
                      onSelect: (lang) => settings.setTargetLanguage(lang),
                    ),
                  ),

                  const SizedBox(height: 24),
                  _SectionHeader('API KEY'),
                  _ApiKeyRow(
                    apiKey: settings.apiKey,
                    showApiKey: settings.showApiKey,
                    onToggleVisibility: settings.toggleShowApiKey,
                    onTap: () => _showApiKeyDialog(context, settings),
                  ),

                  const SizedBox(height: 24),
                  _SectionHeader('DATA'),
                  _ActionRow(
                    label: 'Export History',
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Coming soon')),
                      );
                    },
                  ),
                  _buildDivider(theme),
                  _ActionRow(
                    label: 'Clear All History',
                    isDestructive: true,
                    onTap: () => _showClearConfirmation(context),
                  ),

                  const SizedBox(height: 24),
                  _SectionHeader('ABOUT'),
                  _InfoRow(label: 'Version', value: '1.0.0'),

                  const SizedBox(height: 40),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDivider(ThemeData theme) {
    return Divider(height: 1, indent: 20, endIndent: 20, color: theme.dividerColor);
  }

  void _showLanguageDialog(
    BuildContext context, {
    required String title,
    required List<String> languages,
    required String selected,
    required void Function(String) onSelect,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: languages.length,
            itemBuilder: (context, index) {
              final lang = languages[index];
              final isSelected = lang == selected;
              return ListTile(
                title: Text(lang),
                trailing: isSelected ? const Icon(Icons.check) : null,
                onTap: () {
                  onSelect(lang);
                  Navigator.pop(ctx);
                },
              );
            },
          ),
        ),
      ),
    );
  }

  void _showApiKeyDialog(BuildContext context, SettingsProvider settings) {
    final controller = TextEditingController(text: settings.apiKey);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('OpenAI API Key'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'sk-...'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              settings.setApiKey(controller.text.trim());
              Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showClearConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear All History'),
        content: const Text('Clear all history? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              context.read<HistoryProvider>().clearAllHistory();
              Navigator.pop(ctx);
            },
            child: const Text('Clear', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.5,
          color: theme.colorScheme.onSurface.withOpacity(0.5),
        ),
      ),
    );
  }
}

class _CategoryToggle extends StatelessWidget {
  final ExplanationCategory category;
  final bool isEnabled;
  final VoidCallback onToggle;

  const _CategoryToggle({
    required this.category,
    required this.isEnabled,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
      child: Row(
        children: [
          Expanded(
            child: Text(category.displayName, style: const TextStyle(fontSize: 14)),
          ),
          Switch(
            value: isEnabled,
            onChanged: (_) => onToggle(),
          ),
        ],
      ),
    );
  }
}

class _LanguageRow extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback onTap;

  const _LanguageRow({
    required this.label,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            Text(label, style: const TextStyle(fontSize: 14)),
            const Spacer(),
            Text(
              value,
              style: TextStyle(fontSize: 14, color: theme.colorScheme.onSurface.withOpacity(0.6)),
            ),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right, size: 20, color: theme.colorScheme.onSurface.withOpacity(0.4)),
          ],
        ),
      ),
    );
  }
}

class _ApiKeyRow extends StatelessWidget {
  final String apiKey;
  final bool showApiKey;
  final VoidCallback onToggleVisibility;
  final VoidCallback onTap;

  const _ApiKeyRow({
    required this.apiKey,
    required this.showApiKey,
    required this.onToggleVisibility,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    String displayKey;
    if (apiKey.isEmpty) {
      displayKey = 'Not set';
    } else if (showApiKey) {
      displayKey = apiKey;
    } else {
      displayKey = apiKey.length > 4
          ? '\u2022\u2022\u2022\u2022${apiKey.substring(apiKey.length - 4)}'
          : '\u2022\u2022\u2022\u2022';
    }

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Row(
          children: [
            const Text('OpenAI API Key', style: TextStyle(fontSize: 14)),
            const Spacer(),
            Text(
              displayKey,
              style: TextStyle(fontSize: 14, color: theme.colorScheme.onSurface.withOpacity(0.6)),
            ),
            const SizedBox(width: 4),
            IconButton(
              icon: Icon(
                showApiKey ? Icons.visibility_off : Icons.visibility,
                size: 20,
                color: theme.colorScheme.onSurface.withOpacity(0.4),
              ),
              onPressed: onToggleVisibility,
              constraints: const BoxConstraints(),
              padding: const EdgeInsets.all(4),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool isDestructive;

  const _ActionRow({
    required this.label,
    required this.onTap,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: isDestructive ? Colors.red : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        children: [
          Text(label, style: const TextStyle(fontSize: 14)),
          const Spacer(),
          Text(
            value,
            style: TextStyle(fontSize: 14, color: theme.colorScheme.onSurface.withOpacity(0.6)),
          ),
        ],
      ),
    );
  }
}
