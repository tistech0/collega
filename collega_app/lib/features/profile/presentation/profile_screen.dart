import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import 'package:collega_app/core/notifications/notifications_service.dart';
import 'package:collega_app/core/theme/app_theme.dart';
import 'package:collega_app/features/auth/auth_providers.dart';
import 'package:collega_app/features/auth/domain/auth_state.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider).valueOrNull ?? const AuthState();
    final user = authState.user;
    if (user == null) return const SizedBox.shrink();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profil'),
        centerTitle: false,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.screenMargin),
          children: [
            _IdentityCard(user: user),
            const SizedBox(height: 16),
            _SubscriptionCard(user: user),
            const SizedBox(height: 16),
            const _NotifCard(),
            const SizedBox(height: 16),
            _AppCard(
              onLogout: () async {
                await ref.read(authProvider.notifier).logout();
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _IdentityCard extends StatelessWidget {
  const _IdentityCard({required this.user});
  final AuthUser user;

  @override
  Widget build(BuildContext context) {
    return ShadCard(
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Compte', style: AppTypography.titleMedium()),
          const SizedBox(height: 8),
          Text(user.email, style: AppTypography.bodyMedium()),
          if (user.isBeta) ...[
            const SizedBox(height: 4),
            ShadBadge.secondary(child: const Text('Bêta')),
          ],
        ],
      ),
    );
  }
}

class _SubscriptionCard extends StatelessWidget {
  const _SubscriptionCard({required this.user});
  final AuthUser user;

  @override
  Widget build(BuildContext context) {
    return ShadCard(
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      child: Row(
        children: [
          Expanded(
            child: Text('Abonnement', style: AppTypography.titleMedium()),
          ),
          user.isSubscribed
              ? ShadBadge(child: const Text('Actif'))
              : ShadBadge.destructive(child: const Text('Inactif')),
        ],
      ),
    );
  }
}

class _NotifCard extends ConsumerStatefulWidget {
  const _NotifCard();

  @override
  ConsumerState<_NotifCard> createState() => _NotifCardState();
}

class _NotifCardState extends ConsumerState<_NotifCard> {
  bool _reminderEnabled = false;
  int _reminderHourUtc = 7;

  Future<void> _toggleReminder(bool value) async {
    setState(() => _reminderEnabled = value);
    if (value) {
      await _showTimePicker();
    } else {
      await _clearReminder();
    }
  }

  Future<void> _showTimePicker() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: _reminderHourUtc, minute: 0),
      helpText: 'Heure de rappel (UTC)',
    );
    if (!mounted) return;
    if (picked == null) {
      setState(() => _reminderEnabled = false);
      return;
    }
    setState(() => _reminderHourUtc = picked.hour);
    await _setReminder(picked.hour);
  }

  Future<void> _setReminder(int hourUtc) async {
    final svc = ref.read(notificationsServiceProvider);
    try {
      await svc.requestPermissionsAndRegister();
      await svc.setReminder(hourUtc);
    } catch (_) {
      if (!mounted) return;
      setState(() => _reminderEnabled = false);
      ShadToaster.of(context).show(
        const ShadToast.destructive(
          title: Text("Impossible d'activer le rappel"),
        ),
      );
    }
  }

  Future<void> _clearReminder() async {
    final svc = ref.read(notificationsServiceProvider);
    try {
      await svc.clearReminder();
    } catch (_) {
      if (!mounted) return;
      setState(() => _reminderEnabled = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ShadCard(
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Rappel quotidien', style: AppTypography.titleMedium()),
              ShadSwitch(
                value: _reminderEnabled,
                onChanged: _toggleReminder,
              ),
            ],
          ),
          if (_reminderEnabled) ...[
            const SizedBox(height: 8),
            Text(
              '${_reminderHourUtc}h00 UTC',
              style: AppTypography.bodyMedium(),
            ),
          ],
        ],
      ),
    );
  }
}

class _AppCard extends StatelessWidget {
  const _AppCard({required this.onLogout});
  final Future<void> Function() onLogout;

  @override
  Widget build(BuildContext context) {
    return ShadCard(
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Application', style: AppTypography.titleMedium()),
          const SizedBox(height: 4),
          Text('Version 1.0.0', style: AppTypography.bodyMedium()),
          const SizedBox(height: 12),
          ShadButton.destructive(
            onPressed: onLogout,
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.logout, size: 16),
                SizedBox(width: 8),
                Text('Se déconnecter'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
