import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import 'package:collega_app/core/theme/app_theme.dart';
import 'package:collega_app/features/colleges/colleges_providers.dart';
import 'package:collega_app/features/colleges/widgets/college_progress_tile.dart';
import 'package:collega_app/features/home/home_providers.dart';
import 'package:collega_app/features/home/presentation/widgets/session_config_sheet.dart';
import 'package:collega_app/features/home/presentation/widgets/session_hero_card.dart';
import 'package:collega_app/features/planning/planning_providers.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  void _openConfigSheet(BuildContext context, WidgetRef ref) {
    final colleges = ref.read(collegesProvider).valueOrNull ?? [];
    final generationComplete = colleges.where((e) => e.isGenerationComplete).toList();
    final config = ref.read(homeSessionConfigProvider);
    if (config == null || generationComplete.isEmpty) return;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => SessionConfigSheet(
        generationCompleteColleges: generationComplete,
        initialConfig: config,
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final homeAsync = ref.watch(homeProvider);

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(collegesProvider);
        ref.invalidate(homeProvider);
        await ref.read(homeProvider.future);
      },
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              // Le shell n'a pas de SafeArea et la Home n'a pas d'AppBar :
              // on absorbe la status bar ici.
              padding: EdgeInsets.fromLTRB(
                AppSpacing.screenMargin,
                AppSpacing.screenMargin + MediaQuery.paddingOf(context).top,
                AppSpacing.screenMargin,
                8,
              ),
              child: _HomeSearchBar(),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenMargin),
            sliver: SliverToBoxAdapter(
              child: homeAsync.when(
                data: (state) => SessionHeroCard(
                  homeState: state,
                  onModify: () => _openConfigSheet(context, ref),
                  onPostpone: state is HomeReady && state.todaySession != null
                      ? () => ref
                          .read(planningProvider.notifier)
                          .postponeToday()
                      : null,
                ),
                loading: () => const _HeroSkeleton(),
                error: (e, _) => Text(e.toString()),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.screenMargin,
            ),
            sliver: SliverToBoxAdapter(
              child: homeAsync.whenData((state) {
                if (state is! HomeReady) return const SizedBox.shrink();
                return _PlanningLinks(
                  hasPlanningConfig: state.hasPlanningConfig,
                );
              }).value ??
                  const SizedBox.shrink(),
            ),
          ),
          if (homeAsync.valueOrNull case final HomeReady ready) ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.screenMargin,
                  AppSpacing.sectionSpacing,
                  AppSpacing.screenMargin,
                  8,
                ),
                child: Text('Mes collèges récents', style: AppTypography.titleMedium()),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenMargin),
              sliver: SliverList.builder(
                itemCount: ready.recentColleges.length,
                itemBuilder: (ctx, i) {
                  final entry = ready.recentColleges[i];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: CollegeProgressTile(
                      entry: entry,
                      onTap: () => context.go('/colleges/${entry.catalog.refId}'),
                    ),
                  );
                },
              ),
            ),
          ],
          const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.sectionSpacing)),
        ],
      ),
    );
  }
}

// ─── _HomeSearchBar ───────────────────────────────────────────────────────────

class _HomeSearchBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.go('/search'),
      child: AbsorbPointer(
        child: ShadInput(
          placeholder: const Text('Rechercher un item, un signe, une dose...'),
        ),
      ),
    );
  }
}

// ─── _PlanningLinks ───────────────────────────────────────────────────────────

class _PlanningLinks extends StatelessWidget {
  const _PlanningLinks({required this.hasPlanningConfig});

  final bool hasPlanningConfig;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!hasPlanningConfig)
          TextButton(
            onPressed: () => context.push('/planning/config'),
            child: const Text('Configurer mon planning →'),
          )
        else
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF6B7C6E),
            ),
            onPressed: () => context.push('/planning/config'),
            child: const Text('Modifier le planning'),
          ),
      ],
    );
  }
}

// ─── _HeroSkeleton ────────────────────────────────────────────────────────────

class _HeroSkeleton extends StatelessWidget {
  const _HeroSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 160,
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
      ),
    );
  }
}
