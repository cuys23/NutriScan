import 'package:flutter/material.dart';
import 'package:nutriscan/screens/main/slow_kitchen_home.dart';

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  @override
  Widget build(BuildContext context) {
    // Slow Kitchen redesign: the tab bar is embedded inside
    // SlowKitchenHome, so MainNavigation is a thin wrapper.
    return const SlowKitchenHome();
  }
}

