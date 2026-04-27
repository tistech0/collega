// Stub — implémenté en Story 2.1 avec shadcn_ui
// Bottom navigation 4 tabs : Accueil · Collèges · Recherche · Profil (UX-DR5)
import 'package:flutter/material.dart';

class BottomNavBar extends StatelessWidget {
  const BottomNavBar({super.key, required this.currentIndex, required this.onTap});

  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    throw UnimplementedError('BottomNavBar implémenté en Story 2.1');
  }
}
