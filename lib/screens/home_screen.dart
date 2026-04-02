import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:nikki/providers/camera_provider.dart';
import 'package:nikki/screens/camera/camera_screen.dart';
import 'package:nikki/screens/read_list/read_list_screen.dart';
import 'package:nikki/screens/settings/settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 1);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _animateTo(int page) {
    _pageController.animateToPage(
      page,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<CameraProvider>(
      builder: (context, cameraProvider, _) {
        // Disable swiping entirely when camera has captured a photo
        // (prevents accidental swipe-back while zooming/selecting text).
        // Otherwise use clamping physics to prevent overscroll bounce
        // at the edges (no black area past the first/last page).
        final physics = cameraProvider.isCaptured
            ? const NeverScrollableScrollPhysics()
            : const ClampingScrollPhysics();

        return PageView(
          controller: _pageController,
          physics: physics,
          children: [
            CameraScreen(onBack: () => _animateTo(1)),
            ReadListScreen(
              onCamera: () => _animateTo(0),
              onSettings: () => _animateTo(2),
            ),
            SettingsScreen(onBack: () => _animateTo(1)),
          ],
        );
      },
    );
  }
}
