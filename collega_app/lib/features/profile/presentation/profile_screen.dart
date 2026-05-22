import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import 'package:collega_app/core/notifications/notifications_service.dart';
import 'package:collega_app/core/theme/app_theme.dart';
import 'package:collega_app/core/utils/logger.dart';
import 'package:collega_app/features/auth/auth_providers.dart';
import 'package:collega_app/features/auth/domain/auth_state.dart';
import 'package:collega_app/features/auth/data/revenuecat_service.dart';
import 'package:collega_app/features/auth/paywall_providers.dart';
import 'package:collega_app/features/home/home_providers.dart';
import 'package:collega_app/features/profile/domain/revision_prefs.dart';
import 'package:collega_app/features/profile/profile_providers.dart';

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
            const _RevisionPrefsCard(),
            const SizedBox(height: 16),
            const _NotifCard(),
            const SizedBox(height: 16),
            _AppCard(
              onLogout: () async {
                await ref.read(authProvider.notifier).logout();
              },
              isSubscribed: user.isSubscribed,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── IdentityCard ─────────────────────────────────────────────────────────────

class _IdentityCard extends ConsumerStatefulWidget {
  const _IdentityCard({required this.user});
  final AuthUser user;

  @override
  ConsumerState<_IdentityCard> createState() => _IdentityCardState();
}

class _IdentityCardState extends ConsumerState<_IdentityCard> {
  bool _editing = false;
  bool _saving = false;
  late final TextEditingController _firstNameCtrl;
  late final TextEditingController _yearGroupCtrl;
  late final TextEditingController _facultyCtrl;

  @override
  void initState() {
    super.initState();
    _firstNameCtrl = TextEditingController(text: widget.user.firstName ?? '');
    _yearGroupCtrl = TextEditingController(text: widget.user.yearGroup ?? '');
    _facultyCtrl = TextEditingController(text: widget.user.faculty ?? '');
  }

  @override
  void didUpdateWidget(_IdentityCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_editing) {
      if (widget.user.firstName != oldWidget.user.firstName) {
        _firstNameCtrl.text = widget.user.firstName ?? '';
      }
      if (widget.user.yearGroup != oldWidget.user.yearGroup) {
        _yearGroupCtrl.text = widget.user.yearGroup ?? '';
      }
      if (widget.user.faculty != oldWidget.user.faculty) {
        _facultyCtrl.text = widget.user.faculty ?? '';
      }
    }
  }

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _yearGroupCtrl.dispose();
    _facultyCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_firstNameCtrl.text.trim().isEmpty) {
      ShadToaster.of(context).show(
        const ShadToast.destructive(
          title: Text('Champ requis'),
          description: Text('Le prénom est obligatoire.'),
        ),
      );
      return;
    }
    setState(() => _saving = true);
    String? error;
    try {
      error = await ref.read(authProvider.notifier).updateProfile(
            firstName: _firstNameCtrl.text.trim(),
            yearGroup: _yearGroupCtrl.text.trim(),
            faculty: _facultyCtrl.text.trim(),
          );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
    if (!mounted) return;
    if (error != null) {
      ShadToaster.of(context).show(
        ShadToast.destructive(
          title: const Text('Erreur de sauvegarde'),
          description: Text(error),
        ),
      );
    } else {
      setState(() => _editing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.user;
    return ShadCard(
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text('Compte', style: AppTypography.titleMedium())),
              if (user.isBeta) ShadBadge.secondary(child: const Text('Bêta')),
            ],
          ),
          const SizedBox(height: 8),
          Text(user.email, style: AppTypography.bodyMedium()),
          const SizedBox(height: 12),
          if (_editing) ...[
            TextField(
              controller: _firstNameCtrl,
              decoration: const InputDecoration(labelText: 'Prénom *'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _yearGroupCtrl,
              decoration: const InputDecoration(labelText: 'Année (facultatif)'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _facultyCtrl,
              decoration: const InputDecoration(labelText: 'Faculté (facultatif)'),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                ShadButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Sauvegarder'),
                ),
                const SizedBox(width: 8),
                ShadButton.outline(
                  onPressed: () => setState(() => _editing = false),
                  child: const Text('Annuler'),
                ),
              ],
            ),
          ] else ...[
            _ProfileRow(
              label: 'Prénom',
              value: user.firstName ?? '—',
            ),
            if (user.yearGroup != null) ...[
              const SizedBox(height: 4),
              _ProfileRow(label: 'Année', value: user.yearGroup!),
            ],
            if (user.faculty != null) ...[
              const SizedBox(height: 4),
              _ProfileRow(label: 'Faculté', value: user.faculty!),
            ],
            const SizedBox(height: 12),
            ShadButton.outline(
              size: ShadButtonSize.sm,
              onPressed: () => setState(() => _editing = true),
              child: const Text('Modifier'),
            ),
          ],
        ],
      ),
    );
  }
}

class _ProfileRow extends StatelessWidget {
  const _ProfileRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text('$label : ', style: AppTypography.labelMedium()),
        Text(value, style: AppTypography.bodyMedium()),
      ],
    );
  }
}

// ─── SubscriptionCard ─────────────────────────────────────────────────────────

class _SubscriptionCard extends ConsumerStatefulWidget {
  const _SubscriptionCard({required this.user});
  final AuthUser user;

  @override
  ConsumerState<_SubscriptionCard> createState() => _SubscriptionCardState();
}

class _SubscriptionCardState extends ConsumerState<_SubscriptionCard> {
  RevenueCatSubscriptionInfo? _subInfo;

  @override
  void initState() {
    super.initState();
    _loadSubInfo();
  }

  Future<void> _loadSubInfo() async {
    final info = await ref.read(revenueCatServiceProvider).getSubscriptionInfo();
    if (!mounted) return;
    setState(() => _subInfo = info);
  }

  String _formatDate(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.user;
    final willNotRenew = user.isSubscribed && _subInfo?.willRenew == false;
    final expirationDate = _subInfo?.expirationDate;

    return ShadCard(
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text('Abonnement', style: AppTypography.titleMedium())),
              user.isSubscribed
                  ? ShadBadge(child: const Text('Actif'))
                  : ShadBadge.secondary(child: const Text('Inactif')),
            ],
          ),
          if (willNotRenew && expirationDate != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Résiliation en cours — accès jusqu\'au ${_formatDate(expirationDate)}',
                style: AppTypography.bodyMedium(),
              ),
            ),
          ],
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: user.monthlyMax > 0
                ? (user.monthlyReloads / user.monthlyMax).clamp(0.0, 1.0)
                : 0.0,
          ),
          const SizedBox(height: 4),
          Text(
            '${user.monthlyReloads}/${user.monthlyMax} reimports utilisés ce mois',
            style: AppTypography.bodyMedium(),
          ),
          if (user.isSubscribed && expirationDate != null && !willNotRenew) ...[
            const SizedBox(height: 4),
            Text(
              'Renouvellement le ${_formatDate(expirationDate)}',
              style: AppTypography.bodyMedium(),
            ),
          ],
          const SizedBox(height: 12),
          ShadButton.outline(
            onPressed: () {
              ref.read(revenueCatServiceProvider).openSubscriptionManagement();
            },
            child: const Text('Gérer mon abonnement'),
          ),
        ],
      ),
    );
  }
}

// ─── RevisionPrefsCard ────────────────────────────────────────────────────────

class _RevisionPrefsCard extends ConsumerWidget {
  const _RevisionPrefsCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefsAsync = ref.watch(revisionPrefsProvider);
    return ShadCard(
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Préférences de révision', style: AppTypography.titleMedium()),
          const SizedBox(height: 12),
          prefsAsync.when(
            loading: () => const CircularProgressIndicator(),
            error: (_, __) => const Text('Erreur de chargement'),
            data: (prefs) => _RevisionPrefsContent(prefs: prefs),
          ),
        ],
      ),
    );
  }
}

class _RevisionPrefsContent extends ConsumerWidget {
  const _RevisionPrefsContent({required this.prefs});
  final RevisionPrefs prefs;

  /// Persiste les prefs et notifie l'utilisatrice en cas d'échec storage.
  ///
  /// Anti-pattern fire-and-forget noté dans la rétro MVP § Pattern #4 : sans
  /// await + catch, un échec `flutter_secure_storage.write` divergerait
  /// silencieusement l'UI (toggle apparent) de la storage (ancienne valeur).
  Future<void> _persist(
    BuildContext context,
    WidgetRef ref,
    RevisionPrefs updated, {
    String? errorLabel,
  }) async {
    try {
      await ref.read(revisionPrefsProvider.notifier).save(updated);
    } catch (e) {
      AppLogger.warning(
        'Échec persistance prefs révision : $e',
        tag: '_RevisionPrefsContent',
        error: e,
      );
      if (!context.mounted) return;
      ShadToaster.of(context).show(
        ShadToast.destructive(
          title: const Text('Préférence non sauvegardée'),
          description: Text(errorLabel ??
              'Impossible d\'enregistrer ta préférence — réessaie.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = prefs.defaultRangs ?? [];

    Future<void> updateRangs(String rang, bool on) async {
      final newList = on
          ? (selected.contains(rang) ? selected : [...selected, rang])
          : selected.where((r) => r != rang).toList();
      final updated = prefs.copyWith(
        defaultRangs: newList.isEmpty ? null : newList,
      );
      await _persist(context, ref, updated);
      if (!context.mounted) return;
      ref.read(homeSessionConfigProvider.notifier).reset();
      ref.invalidate(homeProvider);
    }

    Future<void> updateMaxCards(int value) async {
      await _persist(
        context,
        ref,
        prefs.copyWith(defaultMaxCards: value < 0 ? 0 : value),
      );
      if (!context.mounted) return;
      ref.read(homeSessionConfigProvider.notifier).reset();
      ref.invalidate(homeProvider);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Rangs par défaut', style: AppTypography.labelMedium()),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: ['A', 'B', 'C'].map((r) {
            final isSelected = selected.contains(r);
            return FilterChip(
              label: Text(r),
              selected: isSelected,
              onSelected: (on) => updateRangs(r, on),
            );
          }).toList(),
        ),
        const SizedBox(height: 12),
        Text('Fiches max par session', style: AppTypography.labelMedium()),
        const SizedBox(height: 8),
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.remove),
              onPressed: prefs.defaultMaxCards > 0
                  ? () => updateMaxCards(prefs.defaultMaxCards - 1)
                  : null,
            ),
            SizedBox(
              width: 64,
              child: Text(
                prefs.defaultMaxCards == 0 ? 'Toutes' : '${prefs.defaultMaxCards}',
                textAlign: TextAlign.center,
                style: AppTypography.bodyMedium(),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: () => updateMaxCards(prefs.defaultMaxCards + 1),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text('Chronomètre par carte', style: AppTypography.labelMedium()),
            ),
            ShadSwitch(
              value: prefs.timerEnabled,
              onChanged: (on) {
                _persist(
                  context,
                  ref,
                  prefs.copyWith(timerEnabled: on),
                );
              },
            ),
          ],
        ),
        if (prefs.timerEnabled) ...[
          const SizedBox(height: 8),
          Text('Durée par carte', style: AppTypography.labelMedium()),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [15, 30, 60, 120].map((seconds) {
              final isSelected = prefs.timerDurationSeconds == seconds;
              return FilterChip(
                label: Text('${seconds}s'),
                selected: isSelected,
                onSelected: (_) {
                  _persist(
                    context,
                    ref,
                    prefs.copyWith(timerDurationSeconds: seconds),
                  );
                },
              );
            }).toList(),
          ),
        ],
      ],
    );
  }
}

// ─── NotifCard (copié de Story 4.5, inchangé) ─────────────────────────────────

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

// ─── AppCard ──────────────────────────────────────────────────────────────────

class _AppCard extends ConsumerStatefulWidget {
  const _AppCard({required this.onLogout, required this.isSubscribed});
  final Future<void> Function() onLogout;
  final bool isSubscribed;

  @override
  ConsumerState<_AppCard> createState() => _AppCardState();
}

class _AppCardState extends ConsumerState<_AppCard> {
  bool _deleting = false;

  Future<void> _handleDeleteAccount() async {
    final description = widget.isSubscribed
        ? "Cette action est irréversible. Toutes tes fiches et données seront supprimées définitivement.\n\nSi tu as un abonnement actif, pense à l'annuler depuis les Réglages iOS pour éviter d'être débité."
        : "Cette action est irréversible. Toutes tes fiches et données seront supprimées définitivement.";

    final confirmed = await showShadDialog<bool>(
      context: context,
      builder: (ctx) => ShadDialog.alert(
        title: const Text('Supprimer mon compte ?'),
        description: Text(description),
        actionsAxis: Axis.vertical,
        actions: [
          ShadButton.destructive(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Supprimer définitivement'),
          ),
          ShadButton.outline(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Annuler'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _deleting = true);
    final error = await ref.read(authProvider.notifier).deleteAccount();
    if (!mounted) return;
    setState(() => _deleting = false);

    if (error != null) {
      ShadToaster.of(context).show(
        ShadToast.destructive(
          title: const Text('Erreur'),
          description: Text(error),
        ),
      );
    } else {
      if (!mounted) return;
      ShadToaster.of(context).show(
        const ShadToast(
          title: Text('Ton compte a été supprimé'),
        ),
      );
    }
  }

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
          const SizedBox(height: 8),
          ShadButton.link(
            onPressed: () => context.push('/legal/cgu'),
            child: const Text("Conditions générales d'utilisation"),
          ),
          ShadButton.link(
            onPressed: () => context.push('/legal/privacy'),
            child: const Text('Politique de confidentialité'),
          ),
          const SizedBox(height: 8),
          ShadButton.outline(
            onPressed: _deleting ? null : _handleDeleteAccount,
            child: _deleting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Supprimer mon compte'),
          ),
          const SizedBox(height: 8),
          ShadButton.destructive(
            onPressed: widget.onLogout,
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
