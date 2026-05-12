import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import 'package:collega_app/core/theme/app_theme.dart';
import 'package:collega_app/core/utils/logger.dart';
import 'package:collega_app/features/colleges/colleges_detail_providers.dart';
import 'package:collega_app/features/colleges/colleges_providers.dart';
import 'package:collega_app/features/colleges/domain/college_detail_models.dart';
import 'package:collega_app/features/colleges/presentation/widgets/ocr_confidence_badge.dart';

class ItemDetailScreen extends ConsumerWidget {
  const ItemDetailScreen({
    super.key,
    required this.refId,
    required this.itemId,
  });

  final int refId;
  final String itemId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final collegesAsync = ref.watch(collegesProvider);
    return collegesAsync.when(
      loading: () => const Scaffold(body: LinearProgressIndicator()),
      error: (e, _) => Scaffold(body: Center(child: Text(e.toString()))),
      data: (colleges) {
        final byRefId = {for (final e in colleges) e.catalog.refId: e};
        final entry = byRefId[refId];

        if (entry == null || !entry.isImported) {
          return const Scaffold(
            body: Center(child: LinearProgressIndicator()),
          );
        }

        final collegeId = entry.userStatus?.collegeId;
        if (collegeId == null) {
          return const Scaffold(body: Center(child: LinearProgressIndicator()));
        }
        final compositeKey = '$collegeId:$itemId';
        final cardsAsync = ref.watch(itemDetailProvider(compositeKey));

        return cardsAsync.when(
          loading: () => const Scaffold(body: LinearProgressIndicator()),
          error: (e, _) {
            AppLogger.error('ItemDetailScreen error', tag: 'ItemDetailScreen', error: e);
            return Scaffold(body: Center(child: Text(e.toString())));
          },
          data: (cards) {
            final detailState =
                ref.watch(collegeDetailProvider(collegeId)).valueOrNull;
            ItemModel? currentItem;
            if (detailState is CollegeDetailLoaded) {
              currentItem = detailState.items
                  .where((i) => i.id == itemId)
                  .firstOrNull;
            }

            return Scaffold(
              appBar: AppBar(
                title: Text(
                  currentItem != null
                      ? 'Item ${currentItem.itemNumber}${currentItem.chapterTitle != null ? ' · ${currentItem.chapterTitle}' : ''}'
                      : 'Détail item',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                centerTitle: false,
                actions: const [
                  Icon(Icons.bookmark_outline),
                  SizedBox(width: 8),
                ],
              ),
              bottomNavigationBar: DrillLaunchBar(cardCount: cards.length),
              body: _ItemDetailBody(
                cards: cards,
                collegeId: collegeId,
                compositeKey: compositeKey,
              ),
            );
          },
        );
      },
    );
  }

}

class _ItemDetailBody extends ConsumerStatefulWidget {
  const _ItemDetailBody({
    required this.cards,
    required this.collegeId,
    required this.compositeKey,
  });

  final List<FlashCardModel> cards;
  final String collegeId;
  final String compositeKey;

  @override
  ConsumerState<_ItemDetailBody> createState() => _ItemDetailBodyState();
}

class _ItemDetailBodyState extends ConsumerState<_ItemDetailBody>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  static const _rangs = ['A', 'B', 'C'];
  final _loadingCards = <String>{};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  bool _isLoadingCard(String id) => _loadingCards.contains(id);

  void _setCardLoading(String id, {required bool loading}) {
    setState(() {
      if (loading) {
        _loadingCards.add(id);
      } else {
        _loadingCards.remove(id);
      }
    });
  }

  List<FlashCardModel> _cardsForRang(String rang) =>
      widget.cards.where((c) => c.rang == rang).toList();

  Future<void> _handlePositiveFeedback(String cardId) async {
    if (!mounted) return;
    _setCardLoading(cardId, loading: true);
    try {
      await ref
          .read(itemDetailProvider(widget.compositeKey).notifier)
          .submitPositiveFeedback(cardId);
      if (!mounted) return;
      ShadToaster.of(context).show(
        const ShadToast(title: Text('Fiche signalée comme pertinente')),
      );
    } catch (_) {
      if (mounted) {
        ShadToaster.of(context).show(
          const ShadToast.destructive(
            title: Text("Erreur lors de l'enregistrement"),
          ),
        );
      }
    } finally {
      if (mounted) _setCardLoading(cardId, loading: false);
    }
  }

  Future<void> _handleNegativeFeedback(FlashCardModel card) async {
    // P6: enregistrer le feedback négatif dès le tap pouce bas (fire-and-forget)
    unawaited(
      ref
          .read(itemDetailProvider(widget.compositeKey).notifier)
          .submitNegativeFeedback(card.id)
          .catchError((_) {}),
    );

    // P13: ordre spec AC1 — Régénérer (primary) avant Supprimer (destructive)
    final action = await showShadDialog<String>(
      context: context,
      builder: (ctx) => ShadDialog.alert(
        title: const Text('Que faire de cette fiche ?'),
        description: const Text(
          'Régénérer avec votre feedback ou supprimer définitivement ?',
        ),
        actions: [
          ShadButton.outline(
            onPressed: () => Navigator.of(ctx).pop(null),
            child: const Text('Annuler'),
          ),
          ShadButton(
            onPressed: () => Navigator.of(ctx).pop('regenerate'),
            child: const Text('Régénérer'),
          ),
          ShadButton.destructive(
            onPressed: () => Navigator.of(ctx).pop('delete'),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );

    if (!mounted) return;
    if (action == 'delete') {
      await _deleteCard(card.id);
    } else if (action == 'regenerate') {
      await _showRegenerateDialog(card);
    }
  }

  Future<void> _showRegenerateDialog(FlashCardModel card) async {
    final controller = TextEditingController();
    final confirmed = await showShadDialog<bool>(
      context: context,
      builder: (ctx) => ShadDialog.alert(
        title: const Text('Régénérer avec votre feedback'),
        description: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Feedback (optionnel) :'),
            const SizedBox(height: 8),
            ShadInput(
              controller: controller,
              placeholder: const Text('Ex : la réponse est trop vague...'),
            ),
          ],
        ),
        actions: [
          ShadButton.outline(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Annuler'),
          ),
          ShadButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Régénérer'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      final note = controller.text.trim().isEmpty ? null : controller.text.trim();
      await _regenerateCard(card.id, userNote: note);
    }
    controller.dispose();
  }

  Future<void> _deleteCard(String cardId) async {
    _setCardLoading(cardId, loading: true);
    try {
      await ref
          .read(itemDetailProvider(widget.compositeKey).notifier)
          .deleteCard(cardId);
    } catch (_) {
      if (mounted) {
        ShadToaster.of(context).show(
          const ShadToast.destructive(title: Text('Erreur lors de la suppression')),
        );
      }
    } finally {
      if (mounted) _setCardLoading(cardId, loading: false);
    }
  }

  Future<void> _regenerateCard(String cardId, {String? userNote}) async {
    _setCardLoading(cardId, loading: true);
    try {
      await ref
          .read(itemDetailProvider(widget.compositeKey).notifier)
          .regenerateCard(cardId, userNote: userNote);
      if (mounted) {
        ShadToaster.of(context).show(
          const ShadToast(title: Text('Fiche régénérée avec succès')),
        );
      }
    } catch (_) {
      if (mounted) {
        ShadToaster.of(context).show(
          const ShadToast.destructive(title: Text('Régénération échouée')),
        );
      }
    } finally {
      if (mounted) _setCardLoading(cardId, loading: false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TabBar(
          controller: _tabController,
          tabs: _rangs.map((r) => Tab(text: 'Rang $r')).toList(),
        ),
        _FlashcardStrip(cards: widget.cards),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: _rangs.map((rang) {
              final rangCards = _cardsForRang(rang);
              if (rangCards.isEmpty) {
                return const Center(
                  child: Text('Aucune fiche pour ce rang.'),
                );
              }
              return ListView(
                padding: const EdgeInsets.all(AppSpacing.screenMargin),
                children: [
                  ShadAccordion<FlashCardModel>(
                    children: rangCards
                        .map(
                          (card) => ShadAccordionItem<FlashCardModel>(
                            value: card,
                            title: Text(
                              card.recto,
                              style: AppTypography.titleMedium(),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  card.verso,
                                  style: AppTypography.bodyLarge(),
                                ),
                                if (card.ocrConfidenceScore < 0.7) ...[
                                  const SizedBox(height: 8),
                                  OcrConfidenceBadge(
                                    score: card.ocrConfidenceScore,
                                  ),
                                ],
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    if (_isLoadingCard(card.id))
                                      const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(strokeWidth: 2),
                                      )
                                    else ...[
                                      IconButton(
                                        icon: Icon(
                                          Icons.thumb_up_outlined,
                                          size: 20,
                                          color: card.userFeedback == 'positive'
                                              ? AppColors.primary
                                              : null,
                                        ),
                                        onPressed: () =>
                                            _handlePositiveFeedback(card.id),
                                        tooltip: 'Fiche pertinente',
                                      ),
                                      IconButton(
                                        icon: const Icon(
                                          Icons.thumb_down_outlined,
                                          size: 20,
                                        ),
                                        onPressed: () =>
                                            _handleNegativeFeedback(card),
                                        tooltip: 'Fiche non pertinente',
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

class _FlashcardStrip extends StatelessWidget {
  const _FlashcardStrip({required this.cards});

  final List<FlashCardModel> cards;

  Color _rangColor(String rang) => switch (rang) {
        'A' => AppColors.primary,
        'B' => AppColors.secondary,
        _ => AppColors.warning,
      };

  @override
  Widget build(BuildContext context) {
    if (cards.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 80,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.screenMargin,
          vertical: 8,
        ),
        itemCount: cards.length,
        itemBuilder: (ctx, i) {
          final card = cards[i];
          return Container(
            width: 140,
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              border: Border(
                left: BorderSide(color: _rangColor(card.rang), width: 3),
              ),
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(4),
            ),
            padding: const EdgeInsets.all(8),
            child: Text(
              card.recto,
              style: AppTypography.bodyMedium(),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          );
        },
      ),
    );
  }
}

class DrillLaunchBar extends StatelessWidget {
  const DrillLaunchBar({super.key, required this.cardCount});

  final int cardCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenMargin,
        8,
        AppSpacing.screenMargin,
        8,
      ),
      child: ShadButton(
        onPressed: null,
        width: double.infinity,
        child: Text('Lancer le drill · $cardCount fiches'),
      ),
    );
  }
}
