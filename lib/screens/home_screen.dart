import 'package:flutter/material.dart';
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
    return PageView(
      controller: _pageController,
      children: [
        const CameraScreen(),
        ReadListScreen(
          onCamera: () => _animateTo(0),
          onSettings: () => _animateTo(2),
        ),
        SettingsScreen(onBack: () => _animateTo(1)),
      ],
    );
  }
}
