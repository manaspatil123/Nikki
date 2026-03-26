import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:nikki/theme/nikki_theme.dart';
import 'package:nikki/providers/camera_provider.dart';
import 'package:nikki/providers/explanation_provider.dart';
import 'package:nikki/providers/history_provider.dart';
import 'package:nikki/providers/settings_provider.dart';
import 'package:nikki/data/novel_repository.dart';
import 'package:nikki/data/word_repository.dart';
import 'package:nikki/data/settings_repository.dart';
import 'package:nikki/services/openai_service.dart';
import 'package:nikki/screens/camera/camera_screen.dart';
import 'package:nikki/screens/history/history_screen.dart';
import 'package:nikki/screens/settings/settings_screen.dart';

class NikkiApp extends StatelessWidget {
  const NikkiApp({super.key});

  @override
  Widget build(BuildContext context) {
    final novelRepo = NovelRepository();
    final wordRepo = WordRepository();
    final settingsRepo = SettingsRepository();
    final openAiService = OpenAiService();

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => CameraProvider(novelRepo, settingsRepo)),
        ChangeNotifierProvider(create: (_) => ExplanationProvider(openAiService, wordRepo, settingsRepo)),
        ChangeNotifierProvider(create: (_) => HistoryProvider(wordRepo)),
        ChangeNotifierProvider(create: (_) => SettingsProvider(settingsRepo)),
      ],
      child: MaterialApp(
        title: 'Nikki',
        debugShowCheckedModeBanner: false,
        theme: NikkiTheme.light(),
        darkTheme: NikkiTheme.dark(),
        themeMode: ThemeMode.system,
        initialRoute: '/',
        routes: {
          '/': (context) => const CameraScreen(),
          '/history': (context) => const HistoryScreen(),
          '/settings': (context) => const SettingsScreen(),
        },
      ),
    );
  }
}
