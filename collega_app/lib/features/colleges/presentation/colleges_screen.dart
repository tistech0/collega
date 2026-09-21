import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import 'package:collega_app/core/theme/app_theme.dart';
import 'package:collega_app/features/colleges/colleges_import_providers.dart';
import 'package:collega_app/features/colleges/colleges_providers.dart';
import 'package:collega_app/features/colleges/domain/college_models.dart';
import 'package:collega_app/features/colleges/widgets/college_progress_tile.dart';
import 'package:collega_app/shared/widgets/error_view.dart';

enum CollegeFilter { tous, importes, nonImportes }

class CollegesScreen extends ConsumerStatefulWidget {
  const CollegesScreen({super.key});

  @override
  ConsumerState<CollegesScreen> createState() => _CollegesScreenState();
}

class _CollegesScreenState extends ConsumerState<CollegesScreen> {
  CollegeFilter _filter = CollegeFilter.tous;
  late final AppLifecycleListener _lifecycleListener;

  @override
  void initState() {
    super.initState();
    // Story 7.11 : reprend un upload par morceaux interrompu (app tuée pendant l'envoi)
    // au démarrage et à chaque retour au premier plan.
    WidgetsBinding.instance.addPostFrameCallback((_) => _resumePendingUpload());
    _lifecycleListener = AppLifecycleListener(onResume: _resumePendingUpload);
  }

  @override
  void dispose() {
    _lifecycleListener.dispose();
    super.dispose();
  }

  void _resumePendingUpload() {
    if (!mounted) return;
    ref.read(collegeImportProvider.notifier).resumePendingUpload();
  }

  List<CollegeListEntry> _applyFilter(List<CollegeListEntry> all) {
    return switch (_filter) {
      CollegeFilter.importes => all.where((e) => e.isImported).toList(),
      CollegeFilter.nonImportes => all.where((e) => !e.isImported).toList(),
      CollegeFilter.tous => all,
    };
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(collegesProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Collèges'),
        centerTitle: false,
      ),
      body: SafeArea(
        child: Column(
          children: [
            _FilterBar(
              current: _filter,
              onSelect: (f) => setState(() => _filter = f),
            ),
            Expanded(
              child: async.when(
                loading: () => const _SkeletonGrid(),
                error: (e, _) => ErrorView(message: e.toString()),
                data: (all) {
                  final filtered = _applyFilter(all);
                  if (filtered.isEmpty && _filter == CollegeFilter.importes) {
                    return _EmptyImportedState(
                      onReset: () => setState(() => _filter = CollegeFilter.tous),
                    );
                  }
                  if (filtered.isEmpty && _filter == CollegeFilter.nonImportes) {
                    return _EmptyNonImportedState(
                      onReset: () => setState(() => _filter = CollegeFilter.tous),
                    );
                  }
                  return LayoutBuilder(
                    builder: (ctx, constraints) {
                      final isTwoColumns = constraints.maxWidth >= 600;
                      if (isTwoColumns) {
                        return GridView.builder(
                          padding: const EdgeInsets.all(AppSpacing.screenMargin),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: AppSpacing.baseUnit,
                            mainAxisSpacing: AppSpacing.baseUnit,
                            mainAxisExtent: 160,
                          ),
                          itemCount: filtered.length,
                          itemBuilder: (ctx, i) => _buildTile(filtered[i]),
                        );
                      }
                      return ListView.separated(
                        padding: const EdgeInsets.all(AppSpacing.screenMargin),
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.baseUnit),
                        itemBuilder: (ctx, i) => _buildTile(filtered[i]),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTile(CollegeListEntry entry) {
    return CollegeProgressTile(
      entry: entry,
      onTap: entry.isImported
          ? () => context.push('/colleges/${entry.catalog.refId}')
          : () => context.push('/colleges/${entry.catalog.refId}/import'),
    );
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({required this.current, required this.onSelect});
  final CollegeFilter current;
  final void Function(CollegeFilter) onSelect;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.screenMargin,
        vertical: AppSpacing.baseUnit,
      ),
      child: Row(
        children: [
          _Chip(label: 'Tous', selected: current == CollegeFilter.tous, onTap: () => onSelect(CollegeFilter.tous)),
          const SizedBox(width: AppSpacing.baseUnit),
          _Chip(label: 'Importés', selected: current == CollegeFilter.importes, onTap: () => onSelect(CollegeFilter.importes)),
          const SizedBox(width: AppSpacing.baseUnit),
          _Chip(label: 'Non-importés', selected: current == CollegeFilter.nonImportes, onTap: () => onSelect(CollegeFilter.nonImportes)),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return selected
        ? ShadButton(onPressed: onTap, child: Text(label))
        : ShadButton.outline(onPressed: onTap, child: Text(label));
  }
}

class _EmptyNonImportedState extends StatelessWidget {
  const _EmptyNonImportedState({required this.onReset});
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sectionSpacing),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Tu as importé tous les collèges disponibles !',
              style: AppTypography.bodyMedium(),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.baseUnit * 2),
            ShadButton.outline(
              onPressed: onReset,
              child: const Text('Voir tous les collèges'),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyImportedState extends StatelessWidget {
  const _EmptyImportedState({required this.onReset});
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sectionSpacing),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Sélectionne un collège dans les 40 disponibles →',
              style: AppTypography.bodyMedium(),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.baseUnit * 2),
            ShadButton.outline(
              onPressed: onReset,
              child: const Text('Voir tous les collèges'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SkeletonGrid extends StatelessWidget {
  const _SkeletonGrid();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(AppSpacing.screenMargin),
      itemCount: 6,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.baseUnit),
      itemBuilder: (_, i) => _SkeletonTile(key: ValueKey('skeleton-tile-$i')),
    );
  }
}

class _SkeletonTile extends StatelessWidget {
  const _SkeletonTile({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 90,
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F2),
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
      ),
    );
  }
}
