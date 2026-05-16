import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import 'package:collega_app/core/theme/app_theme.dart';
import 'package:collega_app/core/utils/logger.dart';
import 'package:collega_app/features/colleges/colleges_detail_providers.dart';
import 'package:collega_app/features/colleges/colleges_import_providers.dart';
import 'package:collega_app/features/colleges/colleges_providers.dart';
import 'package:collega_app/features/colleges/domain/college_detail_models.dart';
import 'package:collega_app/features/colleges/domain/college_models.dart';
import 'package:collega_app/features/colleges/domain/import_models.dart';
import 'package:collega_app/features/colleges/presentation/widgets/item_progress_bar.dart';
import 'package:collega_app/features/colleges/presentation/widgets/ocr_confidence_badge.dart';

class CollegeDetailScreen extends ConsumerWidget {
  const CollegeDetailScreen({super.key, required this.refId});

  final int refId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final collegesAsync = ref.watch(collegesProvider);
    return collegesAsync.when(
      loading: () => const Scaffold(body: LinearProgressIndicator()),
      error: (e, _) => Scaffold(
        body: Center(child: Text(e.toString())),
      ),
      data: (colleges) {
        final byRefId = {for (final e in colleges) e.catalog.refId: e};
        final entry = byRefId[refId];

        if (entry == null || !entry.isImported) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) context.go('/colleges/$refId/import');
          });
          return const Scaffold(body: SizedBox.shrink());
        }

        if (!entry.isGenerationComplete) {
          return _LoadingView(collegeName: entry.catalog.name);
        }

        final collegeId = entry.userStatus?.collegeId;
        if (collegeId == null) {
          return const Scaffold(body: SizedBox.shrink());
        }
        return _CollegeDetailView(entry: entry, collegeId: collegeId);
      },
    );
  }
}

class _LoadingView extends StatelessWidget {
  const _LoadingView({required this.collegeName});

  final String collegeName;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(collegeName.toUpperCase()),
        centerTitle: false,
      ),
      body: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            LinearProgressIndicator(),
            SizedBox(height: 16),
            Text('Tes fiches arrivent...'),
          ],
        ),
      ),
    );
  }
}

class _CollegeDetailView extends ConsumerStatefulWidget {
  const _CollegeDetailView({
    required this.entry,
    required this.collegeId,
  });

  final CollegeListEntry entry;
  final String collegeId;

  @override
  ConsumerState<_CollegeDetailView> createState() => _CollegeDetailViewState();
}

class _CollegeDetailViewState extends ConsumerState<_CollegeDetailView> {
  bool _isLoadingLimits = false;

  Future<void> _handleReimport() async {
    setState(() => _isLoadingLimits = true);
    try {
      final repo = ref.read(collegeImportRepositoryProvider);
      final limits = await repo.getReloadLimits(widget.entry.catalog.refId);
      if (!mounted) return;
      setState(() => _isLoadingLimits = false);
      await _showReimportDialog(limits);
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoadingLimits = false);
      ShadToaster.of(context).show(
        const ShadToast.destructive(
          title: Text('Impossible de vérifier les limites'),
        ),
      );
    }
  }

  Future<void> _showReimportDialog(ReloadLimits limits) async {
    if (!mounted) return;

    if (limits.isCollegeLimitReached) {
      return _showBlockedDialog(
        title: 'Ce collège ne peut plus être retraité',
        body: 'Tes fiches existantes sont toujours accessibles.\n\n'
            'Tu as utilisé ${limits.collegeReloadCount}/${limits.collegeReloadMax} reimports pour ce collège.',
      );
    }

    if (limits.isMonthlyLimitReached) {
      final resetDate = _formatResetDate(limits.monthlyResetAt);
      return _showBlockedDialog(
        title: 'Limite mensuelle atteinte · Réinitialisation le $resetDate',
        body: 'Tes fiches existantes sont toujours accessibles.\n\n'
            'Tu as utilisé ${limits.monthlyReloads}/${limits.monthlyMax} reimports ce mois.',
      );
    }

    final confirmed = await showShadDialog<bool>(
      context: context,
      builder: (context) => ShadDialog.alert(
        title: const Text('Recharger le PDF ?'),
        description: Text(
          'Reimport ${limits.collegeReloadCount}/${limits.collegeReloadMax} pour ce collège · '
          '${limits.monthlyReloads}/${limits.monthlyMax} ce mois\n\n'
          'Les nouvelles fiches remplaceront les fiches existantes.',
        ),
        actions: [
          ShadButton.outline(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuler'),
          ),
          ShadButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Confirmer'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      context.push('/colleges/${widget.entry.catalog.refId}/import');
    }
  }

  Future<void> _showBlockedDialog({required String title, required String body}) async {
    if (!mounted) return;
    await showShadDialog<void>(
      context: context,
      builder: (context) => ShadDialog.alert(
        title: Text(title),
        description: Text(body),
        actions: [
          ShadButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Continuer à réviser'),
          ),
        ],
      ),
    );
  }

  String _formatResetDate(String isoDate) {
    try {
      final dt = DateTime.parse(isoDate).toLocal();
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}';
    } catch (_) {
      return isoDate;
    }
  }

  @override
  Widget build(BuildContext context) {
    final detailAsync = ref.watch(collegeDetailProvider(widget.collegeId));

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.entry.catalog.name.toUpperCase()),
        centerTitle: false,
        actions: [
          if (_isLoadingLimits)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Recharger le PDF',
              onPressed: _handleReimport,
            ),
        ],
      ),
      body: detailAsync.when(
        loading: () => const Center(child: LinearProgressIndicator()),
        error: (e, _) {
          AppLogger.error('CollegeDetailView error', tag: 'CollegeDetailScreen', error: e);
          return Center(child: Text(e.toString()));
        },
        data: (state) => switch (state) {
          CollegeDetailLoading() => const Center(
              child: LinearProgressIndicator(),
            ),
          CollegeDetailEmpty() => const Center(
              child: Text('Aucune fiche disponible.'),
            ),
          CollegeDetailError(message: final msg) =>
            Center(child: Text(msg)),
          CollegeDetailLoaded() => _LoadedBody(
              entry: widget.entry,
              state: state,
              refId: widget.entry.catalog.refId,
              onRangFilter: (rang) =>
                  ref.read(collegeDetailProvider(widget.collegeId).notifier).filterByRang(rang),
              selectedRang: state.selectedRang,
            ),
        },
      ),
    );
  }
}

class _LoadedBody extends StatelessWidget {
  const _LoadedBody({
    required this.entry,
    required this.state,
    required this.refId,
    required this.onRangFilter,
    required this.selectedRang,
  });

  final CollegeListEntry entry;
  final CollegeDetailLoaded state;
  final int refId;
  final void Function(String?) onRangFilter;
  final String? selectedRang;

  @override
  Widget build(BuildContext context) {
    final filteredItems = state.filteredItems;

    final totalMaitrise = filteredItems.fold(0, (s, i) => s + i.drillMaitrise);
    final totalBien = filteredItems.fold(0, (s, i) => s + i.drillBien);
    final totalARevoir = filteredItems.fold(0, (s, i) => s + i.drillARevoir);
    final totalNotSeen = filteredItems.fold(0, (s, i) => s + i.drillNotSeen);
    final totalCards = totalMaitrise + totalBien + totalARevoir + totalNotSeen;
    final masteryPct =
        totalCards == 0 ? 0 : ((totalMaitrise / totalCards) * 100).round();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(AppSpacing.screenMargin),
          child: ShadCard(
            padding: const EdgeInsets.all(AppSpacing.cardPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Progression globale',
                  style: AppTypography.titleMedium(),
                ),
                const SizedBox(height: 8),
                ItemProgressBar(
                  countARevoir: totalARevoir,
                  countBien: totalBien,
                  countMaitrise: totalMaitrise,
                  countNotSeen: totalNotSeen,
                ),
                const SizedBox(height: 4),
                Text(
                  '$masteryPct% maîtrisé · $totalCards fiches',
                  style: AppTypography.bodyMedium(),
                ),
              ],
            ),
          ),
        ),
        _RangFilterChips(
          selected: selectedRang,
          onSelect: onRangFilter,
        ),
        Expanded(
          child: filteredItems.isEmpty
              ? const Center(child: Text('Aucun item pour ce filtre.'))
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.screenMargin,
                  ),
                  itemCount: filteredItems.length,
                  itemBuilder: (ctx, i) => _ItemTile(
                    item: filteredItems[i],
                    refId: refId,
                  )
                      .animate(
                          delay: Duration(milliseconds: i * 60))
                      .fadeIn(
                          duration: const Duration(milliseconds: 300))
                      .slideX(begin: 0.1, curve: Curves.easeOut),
                ),
        ),
      ],
    );
  }
}

class _RangFilterChips extends StatelessWidget {
  const _RangFilterChips({required this.selected, required this.onSelect});

  final String? selected;
  final void Function(String?) onSelect;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.screenMargin,
        vertical: 8,
      ),
      child: Row(
        children: [
          _Chip(label: 'Tous', active: selected == null, onTap: () => onSelect(null)),
          const SizedBox(width: 8),
          _Chip(label: 'Rang A', active: selected == 'A', onTap: () => onSelect('A')),
          const SizedBox(width: 8),
          _Chip(label: 'Rang B', active: selected == 'B', onTap: () => onSelect('B')),
          const SizedBox(width: 8),
          _Chip(label: 'Rang C', active: selected == 'C', onTap: () => onSelect('C')),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: active ? AppColors.primary : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          style: AppTypography.bodyMedium().copyWith(
            color: active ? Colors.white : null,
            fontWeight: active ? FontWeight.w600 : null,
          ),
        ),
      ),
    );
  }
}

class _RangBadge extends StatelessWidget {
  const _RangBadge({required this.rang});

  final String rang;

  Color get color => switch (rang) {
        'A' => AppColors.primary,
        'B' => AppColors.secondary,
        _ => AppColors.warning,
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        'R$rang',
        style: AppTypography.bodyMedium()
            .copyWith(color: Colors.white, fontSize: 11),
      ),
    );
  }
}

class _ItemTile extends StatelessWidget {
  const _ItemTile({required this.item, required this.refId});

  final ItemModel item;
  final int refId;

  @override
  Widget build(BuildContext context) {
    return ShadCard(
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      child: InkWell(
        onTap: () => context.push('/colleges/$refId/items/${item.id}'),
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _RangBadge(rang: item.rang),
                const SizedBox(width: 8),
                Text(
                  'Item ${item.itemNumber}',
                  style: AppTypography.bodyMedium()
                      .copyWith(fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                if (item.ocrConfidenceScore < 0.7)
                  OcrConfidenceBadge(score: item.ocrConfidenceScore),
                const Icon(Icons.chevron_right, size: 18),
              ],
            ),
            if (item.chapterTitle != null) ...[
              const SizedBox(height: 4),
              Text(
                item.chapterTitle!,
                style: AppTypography.titleMedium().copyWith(fontSize: 14),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 8),
            ItemProgressBar(
              countARevoir: item.drillARevoir,
              countBien: item.drillBien,
              countMaitrise: item.drillMaitrise,
              countNotSeen: item.drillNotSeen,
              showCounts: true,
            ),
          ],
        ),
      ),
    );
  }
}
