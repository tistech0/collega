import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:collega_app/core/notifications/notifications_service.dart';
import 'package:collega_app/core/ui/collega_ui.dart';
import 'package:collega_app/core/utils/fr_dates.dart';
import 'package:collega_app/core/utils/logger.dart';
import 'package:collega_app/env.dart';
import 'package:collega_app/features/auth/auth_providers.dart';
import 'package:collega_app/features/auth/data/revenuecat_service.dart';
import 'package:collega_app/features/auth/domain/auth_state.dart';
import 'package:collega_app/features/auth/paywall_providers.dart';
import 'package:collega_app/features/profile/domain/reminder_time.dart';
import 'package:collega_app/features/profile/domain/revision_prefs.dart';
import 'package:collega_app/features/profile/profile_providers.dart';
import 'package:collega_app/features/shell/tab_reselect.dart';
import 'package:collega_app/features/today/today_providers.dart';

/// Renouvellement / fin de l'abonnement App Store (abonnés seulement).
final _subscriptionInfoProvider = FutureProvider.autoDispose<RevenueCatSubscriptionInfo?>(
  (ref) => ref.read(revenueCatServiceProvider).getSubscriptionInfo(),
);

const _rangs = ['A', 'B', 'C'];
const _maxCardsChoices = [0, 10, 20, 30, 50];
const _timerDurations = [15, 30, 60, 120];
const _rankBadgeWidth = 28.0;

/// Profil (story 8.14, spec v2 § Profil) : compte, accès, révision, rappel,
/// application ; se déconnecter (neutre) et supprimer le compte (action sheet).
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  static const tabIndex = 3;

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> with TabReselectScrollMixin {
  final _scroll = ScrollController();

  /// Interrupteur du rappel pendant l'aller-retour serveur (choix d'heure, envoi).
  bool? _reminderPending;
  bool _deleting = false;

  @override
  int get tabIndex => ProfileScreen.tabIndex;
  @override
  ScrollController get scrollController => _scroll;
  @override
  Duration get reselectDuration => CgMotion.resolve(context, CgMotion.base);
  @override
  Curve get reselectCurve => CgMotion.out;

  @override
  void initState() {
    super.initState();
    // Quota du mois, rappel : relus à chaque ouverture (jamais ceux du login).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(authProvider.notifier).refreshProfile();
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    ref.invalidate(_subscriptionInfoProvider);
    await ref.read(authProvider.notifier).refreshProfile();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).valueOrNull?.user;
    if (user == null) return const SizedBox.shrink();
    final prefs = ref.watch(revisionPrefsProvider).valueOrNull;

    return CgPage(
      title: 'Profil',
      controller: _scroll,
      reserveTabBar: true,
      onRefresh: _refresh,
      children: [
        const CgSectionTitle('Compte'),
        CgListGroup(variant: CgListVariant.inset, children: [_accountRow(user)]),
        const CgSectionTitle('Accès'),
        CgListGroup(variant: CgListVariant.inset, children: [
          ..._accessRows(user),
          _quotaRow(user),
        ]),
        if (prefs == null)
          const Padding(padding: EdgeInsets.only(top: CgSpace.section), child: CgSkeletonList(rows: 4))
        else
          ..._revision(prefs),
        const CgSectionTitle('Rappel'),
        CgListGroup(variant: CgListVariant.inset, children: _reminderRows(user)),
        const CgSectionTitle('Application'),
        CgListGroup(variant: CgListVariant.inset, children: [
          CgListRow(
            title: 'Conditions générales d’utilisation',
            trailing: CgRowTrailing.chevron,
            onTap: () => context.push('/legal/cgu'),
          ),
          CgListRow(
            title: 'Politique de confidentialité',
            trailing: CgRowTrailing.chevron,
            onTap: () => context.push('/legal/privacy'),
          ),
          const CgListRow(title: 'Version', trailing: CgRowTrailing.value, value: kAppVersion),
        ]),
        const SizedBox(height: CgSpace.section),
        CgButton(
          label: 'Se déconnecter',
          variant: CgButtonVariant.secondary,
          icon: CgIcons.logout,
          onPressed: _deleting ? null : () => ref.read(authProvider.notifier).logout(),
        ),
        const SizedBox(height: CgSpace.s2),
        CgButton(
          label: 'Supprimer mon compte',
          variant: CgButtonVariant.quiet,
          loading: _deleting,
          onPressed: () => _askDelete(user),
        ),
        const SizedBox(height: CgSpace.section),
      ],
    );
  }

  // ─── Compte ────────────────────────────────────────────────────────────────

  Widget _accountRow(AuthUser user) {
    final name = user.firstName?.trim() ?? '';
    final details = [user.yearGroup, user.faculty, user.email].whereType<String>().where((s) => s.trim().isNotEmpty);
    return CgListRow(
      title: name.isEmpty ? 'Ajoute ton prénom' : name,
      subtitle: details.join(' · '),
      leading: _Initial(name: name),
      trailing: CgRowTrailing.chevron,
      onTap: () => showCgSheet<void>(
        context,
        title: 'Modifier le profil',
        detent: CgSheetDetent.full,
        builder: (_) => _ProfileEditBody(user: user),
      ),
    );
  }

  // ─── Accès ────────────────────────────────────────────────────────────────

  List<Widget> _accessRows(AuthUser user) {
    if (user.isSubscribed) {
      final info = ref.watch(_subscriptionInfoProvider).valueOrNull;
      final end = info?.expirationDate;
      final subtitle = end == null
          ? 'Actif'
          : info!.willRenew
              ? 'Se renouvelle le ${frShortDate(end.toLocal())}'
              : 'Résilié · accès jusqu’au ${frShortDate(end.toLocal())}';
      return [
        CgListRow(title: 'Collega Premium', subtitle: subtitle, leading: const CgRowIcon(CgIcons.sparkle)),
        CgListRow(
          title: 'Gérer mon abonnement',
          trailing: CgRowTrailing.chevron,
          onTap: () => ref.read(revenueCatServiceProvider).openSubscriptionManagement(),
        ),
      ];
    }
    return [
      const CgListRow(
        title: 'Beta privée',
        subtitle: 'Accès offert pendant la beta privée',
        leading: CgRowIcon(CgIcons.lock),
        trailing: CgRowTrailing.custom,
        trailingWidget: CgBadge.beta(),
      ),
    ];
  }

  Widget _quotaRow(AuthUser user) {
    final max = user.monthlyMax;
    final used = user.monthlyReloads.clamp(0, max);
    final reset = user.monthlyResetAt;
    return CgListRow(
      title: 'Réimports ce mois',
      subtitle: reset == null ? null : 'Se renouvelle le ${frShortDate(reset.toLocal())}',
      trailing: CgRowTrailing.value,
      value: '$used sur $max',
      progress: ProfileQuotaBar(fraction: max > 0 ? used / max : 0),
    );
  }

  // ─── Révision ─────────────────────────────────────────────────────────────

  List<Widget> _revision(RevisionPrefs prefs) {
    final active = prefs.defaultRangs ?? _rangs;
    return [
      const CgSectionTitle('Rangs par défaut'),
      CgListGroup(variant: CgListVariant.inset, children: [
        for (final r in _rangs)
          CgListRow(
            title: 'Rang $r',
            // Largeur commune : les titres restent alignés (A, B, C n'ont pas la même chasse).
            leading: ExcludeSemantics(
              child: ConstrainedBox(
                constraints: const BoxConstraints(minWidth: _rankBadgeWidth),
                child: Align(widthFactor: 1, child: CgBadge.rank(r, short: true)),
              ),
            ),
            trailing: CgRowTrailing.check,
            selected: active.contains(r),
            onTap: () => _toggleRang(prefs, r),
          ),
      ]),
      const _Footnote('Les sessions du jour ne proposent que ces rangs.'),
      const CgSectionTitle('Sessions'),
      CgListGroup(variant: CgListVariant.inset, children: [
        CgListRow(
          title: 'Fiches par session',
          trailing: CgRowTrailing.value,
          value: _maxCardsLabel(prefs.defaultMaxCards),
          onTap: () => _pickMaxCards(prefs),
        ),
      ]),
      const CgSectionTitle('Chronomètre par carte'),
      CgSegmented<TimerMode>(
        values: TimerMode.values,
        labelOf: (m) => switch (m) {
          TimerMode.off => 'Désactivé',
          TimerMode.on => 'Activé',
          TimerMode.ask => 'Demander',
        },
        selected: prefs.timerMode,
        onChanged: (m) => _save(prefs.copyWith(timerMode: m)),
      ),
      if (prefs.timerMode != TimerMode.off) ...[
        const CgSectionTitle('Durée par carte'),
        CgSegmented<int>(
          // Une durée hors liste (réglage ancien) reste choisie et visible.
          values: {..._timerDurations, prefs.timerDurationSeconds}.toList()..sort(),
          labelOf: (s) => s < 60 || s % 60 != 0 ? '$s s' : '${s ~/ 60} min',
          selected: prefs.timerDurationSeconds,
          onChanged: (s) => _save(prefs.copyWith(timerDurationSeconds: s)),
        ),
      ],
    ];
  }

  static String _maxCardsLabel(int n) => n <= 0 ? 'Toutes' : '$n';

  Future<void> _toggleRang(RevisionPrefs prefs, String rang) async {
    final active = {...(prefs.defaultRangs ?? _rangs)};
    if (active.contains(rang)) {
      if (active.length == 1) {
        showCgToast(context, 'Garde au moins un rang.');
        return;
      }
      active.remove(rang);
    } else {
      active.add(rang);
    }
    final ordered = _rangs.where(active.contains).toList();
    // Les trois = « tous » (aucun filtre enregistré).
    await _save(prefs.copyWith(defaultRangs: ordered.length == _rangs.length ? null : ordered));
    if (mounted) ref.invalidate(todayProvider);
  }

  Future<void> _pickMaxCards(RevisionPrefs prefs) async {
    final current = prefs.defaultMaxCards;
    final choices = [..._maxCardsChoices, if (!_maxCardsChoices.contains(current)) current]..sort((a, b) {
        if (a == 0) return -1;
        if (b == 0) return 1;
        return a.compareTo(b);
      });
    final picked = await showCgSheet<int>(
      context,
      title: 'Fiches par session',
      builder: (sheetContext) => SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: CgSpace.s4),
        child: CgListGroup(variant: CgListVariant.inset, children: [
          for (final n in choices)
            CgListRow(
              title: _maxCardsLabel(n),
              trailing: CgRowTrailing.check,
              selected: n == current,
              onTap: () => Navigator.of(sheetContext, rootNavigator: true).pop(n),
            ),
        ]),
      ),
    );
    if (picked == null || picked == current || !mounted) return;
    await _save(prefs.copyWith(defaultMaxCards: picked));
    if (mounted) ref.invalidate(todayProvider);
  }

  /// Une préférence non enregistrée se dit : l'écran ne ment pas sur l'état.
  Future<void> _save(RevisionPrefs updated) async {
    try {
      await ref.read(revisionPrefsProvider.notifier).save(updated);
    } catch (e) {
      AppLogger.warning('Préférence de révision non enregistrée', tag: 'ProfileScreen', error: e);
      if (mounted) showCgToast(context, 'Ta préférence n’a pas été enregistrée. Réessaie.');
    }
  }

  // ─── Rappel ───────────────────────────────────────────────────────────────

  List<Widget> _reminderRows(AuthUser user) {
    final serverHour = user.reminderHourUtc;
    final on = _reminderPending ?? serverHour != null;
    final busy = _reminderPending != null;
    return [
      CgListRow(
        title: 'Rappel quotidien',
        subtitle: on ? null : 'Une notification pour ta session du jour',
        trailing: CgRowTrailing.custom,
        trailingWidget: CupertinoSwitch(
          value: on,
          activeTrackColor: CgTheme.of(context).colors.accent,
          onChanged: busy ? null : (v) => _setReminder(user, v),
        ),
        onTap: busy ? null : () => _setReminder(user, !on),
      ),
      if (serverHour != null && !busy)
        CgListRow(
          title: 'Heure',
          trailing: CgRowTrailing.value,
          value: reminderLabel(reminderLocalHour(serverHour, DateTime.now())),
          onTap: () => _setReminder(user, true),
        ),
    ];
  }

  Future<void> _setReminder(AuthUser user, bool on) async {
    final notifications = ref.read(notificationsServiceProvider);
    final auth = ref.read(authProvider.notifier);
    if (!on) {
      setState(() => _reminderPending = false);
      try {
        await notifications.clearReminder();
        await auth.setReminderHour(null);
      } catch (_) {
        if (mounted) showCgToast(context, 'Le rappel n’a pas pu être désactivé. Réessaie dans un instant.');
      } finally {
        if (mounted) setState(() => _reminderPending = null);
      }
      return;
    }

    final now = DateTime.now();
    final current = user.reminderHourUtc;
    setState(() => _reminderPending = true);
    final localHour = await _pickHour(current == null ? _defaultReminderHour : reminderLocalHour(current, now));
    if (!mounted) return;
    if (localHour == null) {
      setState(() => _reminderPending = null);
      return;
    }
    final utc = reminderUtcHour(localHour, now);
    try {
      await notifications.requestPermissionsAndRegister();
      await notifications.setReminder(utc);
      await auth.setReminderHour(utc);
    } catch (e) {
      AppLogger.warning('Rappel non activé', tag: 'ProfileScreen', error: e);
      if (mounted) showCgToast(context, 'Le rappel n’a pas pu être activé. Réessaie dans un instant.');
    } finally {
      if (mounted) setState(() => _reminderPending = null);
    }
  }

  static const _defaultReminderHour = 8;

  Future<int?> _pickHour(int initial) {
    var picked = initial;
    final now = DateTime.now();
    return showCgSheet<int>(
      context,
      title: 'Heure du rappel',
      builder: (_) => SizedBox(
        height: _pickerHeight,
        child: CupertinoDatePicker(
          mode: CupertinoDatePickerMode.time,
          use24hFormat: true,
          minuteInterval: 60,
          initialDateTime: DateTime(now.year, now.month, now.day, initial),
          onDateTimeChanged: (d) => picked = d.hour,
        ),
      ),
      primary: Builder(
        builder: (sheetContext) => CgButton(
          label: 'Valider',
          onPressed: () => Navigator.of(sheetContext, rootNavigator: true).pop(picked),
        ),
      ),
    );
  }

  static const _pickerHeight = 216.0;

  // ─── Suppression ──────────────────────────────────────────────────────────

  Future<void> _askDelete(AuthUser user) => showCgActionSheet(
        context,
        title: 'Supprimer ton compte ?',
        message: 'Tes collèges, tes fiches et ta progression seront effacés. C’est définitif.'
            '${user.isSubscribed ? ' Ton abonnement continue tant que tu ne l’annules pas dans Réglages.' : ''}',
        actions: [CgSheetAction(label: 'Supprimer définitivement', destructive: true, onPressed: _delete)],
      );

  Future<void> _delete() async {
    if (_deleting) return;
    setState(() => _deleting = true);
    final error = await ref.read(authProvider.notifier).deleteAccount();
    if (!mounted) return;
    setState(() => _deleting = false);
    if (error != null) {
      showCgToast(context, 'La suppression n’a pas abouti. Ton compte est intact, réessaie dans un instant.');
    }
  }
}

/// Initiale du prénom (ou icône) : repère de la ligne de compte.
class _Initial extends StatelessWidget {
  const _Initial({required this.name});

  final String name;

  static const _size = 36.0;

  @override
  Widget build(BuildContext context) {
    final c = CgTheme.of(context).colors;
    if (name.isEmpty) return const CgRowIcon(CgIcons.profile);
    return ExcludeSemantics(
      child: Container(
        width: _size,
        height: _size,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: c.accentSoft, shape: BoxShape.circle),
        child: CgTextScaleCap(
          child: Text(name.characters.first.toUpperCase(), style: CgType.head.copyWith(color: c.accent)),
        ),
      ),
    );
  }
}

/// Quota de réimports : vide à 0, pleine à la limite (jamais l'inverse).
class ProfileQuotaBar extends StatelessWidget {
  const ProfileQuotaBar({super.key, required this.fraction});

  final double fraction;

  static const _height = 6.0;

  @override
  Widget build(BuildContext context) {
    final c = CgTheme.of(context).colors;
    return ExcludeSemantics(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(_height / 2),
        child: SizedBox(
          height: _height,
          child: Stack(fit: StackFit.expand, children: [
            ColoredBox(color: c.soft),
            FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: fraction.clamp(0.0, 1.0),
              child: ColoredBox(color: c.accent),
            ),
          ]),
        ),
      ),
    );
  }
}

/// Précision sous un groupe (spec v2 : `meta` `ink3`).
class _Footnote extends StatelessWidget {
  const _Footnote(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final c = CgTheme.of(context).colors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(CgSpace.rowInset, CgSpace.s2, CgSpace.rowInset, 0),
      child: Text(text, style: CgType.meta.copyWith(color: c.ink3)),
    );
  }
}

/// Sheet « Modifier le profil » : prénom requis, année et faculté facultatives ;
/// erreurs dites sous le champ ou dans la sheet, qui ne se ferme qu'une fois enregistré.
class _ProfileEditBody extends ConsumerStatefulWidget {
  const _ProfileEditBody({required this.user});

  final AuthUser user;

  @override
  ConsumerState<_ProfileEditBody> createState() => _ProfileEditBodyState();
}

class _ProfileEditBodyState extends ConsumerState<_ProfileEditBody> {
  late final _firstName = TextEditingController(text: widget.user.firstName ?? '');
  late final _yearGroup = TextEditingController(text: widget.user.yearGroup ?? '');
  late final _faculty = TextEditingController(text: widget.user.faculty ?? '');
  String? _nameError;
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _firstName.dispose();
    _yearGroup.dispose();
    _faculty.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final firstName = _firstName.text.trim();
    setState(() {
      _nameError = firstName.isEmpty ? 'Saisis ton prénom.' : null;
      _error = null;
    });
    if (firstName.isEmpty) return;
    setState(() => _saving = true);
    final error = await ref.read(authProvider.notifier).updateProfile(
          firstName: firstName,
          yearGroup: _yearGroup.text.trim(),
          faculty: _faculty.text.trim(),
        );
    if (!mounted) return;
    if (error != null) {
      setState(() {
        _saving = false;
        _error = 'Ton profil n’a pas pu être enregistré. Réessaie dans un instant.';
      });
      return;
    }
    CgHaptics.success();
    Navigator.of(context, rootNavigator: true).pop();
  }

  @override
  Widget build(BuildContext context) {
    final c = CgTheme.of(context).colors;
    return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Flexible(
        child: SingleChildScrollView(
          child: AutofillGroup(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              CgField(
                label: 'Prénom',
                controller: _firstName,
                error: _nameError,
                autofillHints: const [AutofillHints.givenName],
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: CgSpace.s4),
              CgField(
                label: 'Année (facultatif)',
                placeholder: 'DFASM2',
                controller: _yearGroup,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: CgSpace.s4),
              CgField(
                label: 'Faculté (facultatif)',
                controller: _faculty,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _submit(),
              ),
              if (_error != null) ...[
                const SizedBox(height: CgSpace.s4),
                Semantics(
                  liveRegion: true,
                  child: Text(_error!, style: CgType.bodyS.copyWith(color: c.danger)),
                ),
              ],
            ]),
          ),
        ),
      ),
      CgSheetFooter(primary: CgButton(label: 'Enregistrer', loading: _saving, onPressed: _submit)),
    ]);
  }
}
