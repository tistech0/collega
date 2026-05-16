# Story 4.2 : Mode Drill — Session de Révision

Status: done

## Story

En tant qu'**étudiant**,
je veux lancer une session de révision en Mode Drill et évaluer mes fiches en spaced repetition, entièrement hors-ligne,
afin d'ancrer mes connaissances par rang (A→B→C) avec un feedback immédiat sur ma progression.

## Acceptance Criteria

1. **Session offline-first (AC1 — FR24, FR28)**
   - Étant donné un étudiant avec des fiches synchronisées localement
   - Quand il lance une session depuis la `DrillLaunchBar` (ItemDetailScreen)
   - Alors la session démarre sans aucun appel réseau — toutes les données viennent de Drift
   - Et le temps de réponse entre taps est < 100ms (NFR3)

2. **Spaced repetition — ordre de présentation (AC2 — FR25)**
   - Étant donné une session de drill en cours
   - Quand les fiches sont présentées
   - Alors les fiches "À revoir" reviennent plus fréquemment que "Bien"
   - Et "Maîtrisé" ne revient pas dans la session courante
   - Et la ProgressBar "X / total" avance à chaque fiche évaluée (total = nb initial de fiches)

3. **Évaluation → mise à jour Drift immédiate (AC3 — FR26, FR27)**
   - Étant donné l'évaluation d'une fiche
   - Quand je tape "À revoir", "Bien" ou "Maîtrisé"
   - Alors `drillLevel` + `nextReviewAt` de la fiche sont mis à jour dans Drift immédiatement
   - Et "À revoir" → fiche réinsérée dans la session courante (position currentIndex + 3)
   - Et "Bien" → retirée de la session courante, `nextReviewAt = now + 1 jour`
   - Et "Maîtrisé" → retirée de la session courante, `nextReviewAt = now + 7 jours`

4. **Mode définition — évaluation sémantique Claude (AC4 — FR29)**
   - Étant donné une fiche `cardType == 'definition'`
   - Quand la card est au recto (terme médical visible)
   - Alors un champ de saisie s'affiche sous la card à la place du hint "Tapoter"
   - Et le bouton "Évaluer" soumet la réponse à `POST /v1/flash-cards/{id}/evaluate-semantic`
   - Et le résultat (correct / partiel / incorrect) + feedback qualitatif s'affiche
   - Et si hors-ligne (DioException), la card se retourne (auto-évaluation recto/verso classique)
   - Dans les deux cas, la `DrillEvaluationBar` s'affiche pour l'auto-évaluation finale

5. **Fin de session — écran récapitulatif (AC5)**
   - Étant donné la fin d'une session (queue épuisée)
   - Quand l'écran de fin s'affiche
   - Alors un donut `MasteryCircle` (`CustomPaint`) affiche le % maîtrise global
   - Et 3 cartes `StatsBento` (ShadCard) montrent les comptes Maîtrisé / Bien / À revoir
   - Et le CTA "Recommencer les erreurs" (primary) relance une session avec uniquement les fiches "À revoir" de la session précédente
   - Et le CTA "Retour à l'accueil" (outline) navigue vers `/home`

6. **Navigation — bottom nav masqué (AC6)**
   - Étant donné le mode drill actif
   - Quand l'écran est affiché
   - Alors le bottom nav est masqué — la route `/drill` est hors du ShellRoute
   - Et la sortie se fait uniquement via le bouton ✕ dans le `DrillHeader`
   - Et le bouton ✕ navigue avec `context.pop()` (retour à ItemDetailScreen)

---

## Tasks / Subtasks

- [x] **T1 — Drift schema v4 : colonnes spaced repetition** (AC: #3)
  - [x] Modifier `collega_app/lib/core/database/tables/flash_cards_table.dart` : ajouter 3 colonnes
    ```dart
    TextColumn get drillLevel =>
        text().withDefault(const Constant('new'))();       // 'new'|'a_revoir'|'bien'|'maitrise'
    IntColumn get nextReviewAt =>
        integer().nullable()();                           // epoch ms UTC, null = jamais révisée
    IntColumn get reviewCount =>
        integer().withDefault(const Constant(0))();
    ```
  - [x] Modifier `collega_app/lib/core/database/app_database.dart` : `schemaVersion = 4` + migration
    ```dart
    if (from < 4) {
      await m.addColumn(flashCards, flashCards.drillLevel);
      await m.addColumn(flashCards, flashCards.nextReviewAt);
      await m.addColumn(flashCards, flashCards.reviewCount);
    }
    ```
  - [x] Exécuter `cd collega_app && dart run build_runner build --delete-conflicting-outputs` pour régénérer `app_database.g.dart`
  - [x] Vérifier que les 3 colonnes apparaissent dans `app_database.g.dart`

- [x] **T2 — Domaine : DrillSessionState + DrillSessionParams** (AC: #2, #3, #5)
  - [x] Créer `collega_app/lib/features/drill/domain/drill_session_state.dart`
  - [x] Définir `DrillSessionParams` (clé du provider family) :
    ```dart
    @immutable
    class DrillSessionParams {
      const DrillSessionParams({
        required this.collegeId,
        required this.itemId,
        this.rangs,
        this.onlyARevoir = false,
      });
      final String collegeId;
      final String itemId;
      final List<String>? rangs; // null = tous les rangs
      final bool onlyARevoir;   // true = "Recommencer les erreurs"

      @override
      bool operator ==(Object other) =>
          other is DrillSessionParams &&
          other.collegeId == collegeId &&
          other.itemId == itemId &&
          const ListEquality<String>().equals(other.rangs, rangs) &&
          other.onlyARevoir == onlyARevoir;

      @override
      int get hashCode =>
          Object.hash(collegeId, itemId, Object.hashAll(rangs ?? []), onlyARevoir);
    }
    ```
    _(NB : `ListEquality` vient de `package:collection` — vérifier si disponible ; sinon, utiliser `rangs?.join(',')` dans hashCode et comparer en string)_
  - [x] Définir `DrillSessionState` :
    ```dart
    @immutable
    class DrillSessionState {
      const DrillSessionState({
        required this.cards,
        required this.queue,
        this.currentQueuePos = 0,
        this.evaluatedCount = 0,
        this.evaluations = const {},
        this.isFlipped = false,
        this.exitResult,
        this.semanticFeedback,
        this.isComplete = false,
      });

      final List<FlashCardModel> cards;
      final List<int> queue;           // indices dans cards[], peut contenir des doublons
      final int currentQueuePos;
      final int evaluatedCount;
      final Map<String, DrillEvaluationResult> evaluations; // cardId → résultat
      final bool isFlipped;
      final DrillEvaluationResult? exitResult;
      final SemanticFeedback? semanticFeedback; // résultat éval définition
      final bool isComplete;

      int get totalInitial => cards.length;
      FlashCardModel? get currentCard =>
          queue.isEmpty || currentQueuePos >= queue.length
              ? null
              : cards[queue[currentQueuePos]];

      DrillSessionState copyWith({...});
    }
    ```
  - [x] Définir `SemanticFeedback` :
    ```dart
    @immutable
    class SemanticFeedback {
      const SemanticFeedback({required this.result, required this.feedback});
      final String result;   // 'correct' | 'partial' | 'incorrect'
      final String feedback;
    }
    ```
  - [x] Définir `DrillSessionSummary` (pour l'écran de fin) :
    ```dart
    @immutable
    class DrillSessionSummary {
      const DrillSessionSummary({
        required this.maîtriseCount,
        required this.bienCount,
        required this.aRevoirCount,
      });
      final int maîtriseCount;
      final int bienCount;
      final int aRevoirCount;

      int get total => maîtriseCount + bienCount + aRevoirCount;
      double get masteryRatio => total == 0 ? 0 : maîtriseCount / total;

      factory DrillSessionSummary.fromEvaluations(
          Map<String, DrillEvaluationResult> evaluations) {
        return DrillSessionSummary(
          maîtriseCount: evaluations.values
              .where((v) => v == DrillEvaluationResult.maitrise)
              .length,
          bienCount: evaluations.values
              .where((v) => v == DrillEvaluationResult.bien)
              .length,
          aRevoirCount: evaluations.values
              .where((v) => v == DrillEvaluationResult.aRevoir)
              .length,
        );
      }
    }
    ```

- [x] **T3 — DrillRepository** (AC: #1, #3, #4)
  - [x] Créer `collega_app/lib/features/drill/data/drill_repository.dart`
  - [x] Implémentation :
    ```dart
    class DrillRepository {
      const DrillRepository({required this.dio, required this.db});

      final Dio dio;
      final AppDatabase db;

      // Charge les fiches depuis Drift (offline-first — jamais de réseau ici)
      Future<List<FlashCardModel>> getCardsForDrill({
        required String itemId,
        List<String>? rangs,
        bool onlyARevoir = false,
      }) async {
        final query = db.select(db.flashCards)
          ..where((t) => t.itemId.equals(itemId));
        if (rangs != null && rangs.isNotEmpty) {
          query.where((t) => t.rang.isIn(rangs));
        }
        if (onlyARevoir) {
          query.where((t) => t.drillLevel.equals('a_revoir'));
        }
        final rows = await query.get();
        return rows.map(_rowToModel).toList();
      }

      // Mise à jour Drift immédiate après évaluation
      Future<void> updateCardDrillLevel(
          String cardId, DrillEvaluationResult result) async {
        final nowMs = DateTime.now().toUtc().millisecondsSinceEpoch;
        final level = switch (result) {
          DrillEvaluationResult.aRevoir => 'a_revoir',
          DrillEvaluationResult.bien    => 'bien',
          DrillEvaluationResult.maitrise => 'maitrise',
        };
        final nextReview = switch (result) {
          DrillEvaluationResult.aRevoir  => nowMs,                       // maintenant
          DrillEvaluationResult.bien     => nowMs + 86400000,            // +1 jour
          DrillEvaluationResult.maitrise => nowMs + 7 * 86400000,       // +7 jours
        };
        await (db.update(db.flashCards)
              ..where((t) => t.id.equals(cardId)))
            .write(FlashCardsCompanion(
          drillLevel: Value(level),
          nextReviewAt: Value(nextReview),
          reviewCount: const Value.absent(), // incrémenté séparément si besoin
        ));
      }

      // Évaluation sémantique Claude (peut lancer DioException si offline)
      Future<SemanticFeedback> evaluateSemantic(
          String cardId, String userAnswer) async {
        final response = await dio.post<Map<String, dynamic>>(
          '/v1/flash-cards/$cardId/evaluate-semantic',
          data: {'user_answer': userAnswer},
        );
        final data = response.data?['data'] as Map<String, dynamic>;
        return SemanticFeedback(
          result: data['result'] as String,
          feedback: data['feedback'] as String,
        );
      }

      FlashCardModel _rowToModel(FlashCard row) => FlashCardModel(
            id: row.id,
            itemId: row.itemId,
            collegeId: row.collegeId,
            cardType: row.cardType,
            rang: row.rang,
            recto: row.recto,
            verso: row.verso,
            ocrConfidenceScore: row.ocrConfidenceScore,
            lowConfidence: row.lowConfidence,
            userFeedback: row.userFeedback,
          );
    }
    ```

- [x] **T4 — DrillSessionNotifier + providers** (AC: #2, #3, #5)
  - [x] Créer `collega_app/lib/features/drill/drill_providers.dart`
  - [x] `drillRepositoryProvider`, `drillSessionProvider` (family) + `DrillSessionNotifier`
  - [x] Algorithme de queue initiale :
    - Charger les fiches depuis Drift (via `DrillRepository.getCardsForDrill`)
    - Trier : `drillLevel == 'a_revoir'` en premier, puis `'new'`, puis `'bien'`/'maitrise'`
    - Au sein de chaque groupe, trier par rang A→B→C
    - Si `onlyARevoir == true`, ne garder que `drillLevel == 'a_revoir'`
    - Queue initiale = `List<int>` des indices (0..n-1) dans cet ordre
  - [x] Méthode `evaluate(DrillEvaluationResult result)` :
    ```dart
    Future<void> evaluate(DrillEvaluationResult result) async {
      final s = state.value;
      if (s == null || s.currentCard == null) return;

      final card = s.currentCard!;
      final repo = ref.read(drillRepositoryProvider);

      // 1. Mettre à jour Drift (fire-and-forget en prod, await pour les tests)
      unawaited(repo.updateCardDrillLevel(card.id, result).catchError(
        (Object e) => AppLogger.error('updateCardDrillLevel failed', error: e),
      ));

      // 2. Mettre à jour la queue en mémoire
      final newQueue = List<int>.from(s.queue);
      if (result == DrillEvaluationResult.aRevoir) {
        // Réinsérer 3 positions plus loin (ou en fin si trop court)
        final insertPos = (s.currentQueuePos + 3).clamp(
            s.currentQueuePos + 1, newQueue.length);
        newQueue.insert(insertPos, newQueue[s.currentQueuePos]);
      }

      // 3. Mettre à jour les évaluations (garde la dernière évaluation par cardId)
      final newEvals = Map<String, DrillEvaluationResult>.from(s.evaluations)
        ..[card.id] = result;

      // 4. Déclencher animation de sortie (FlashCardWidget.onExitComplete appellera advanceToNext)
      state = AsyncValue.data(s.copyWith(
        queue: newQueue,
        evaluations: newEvals,
        evaluatedCount: s.evaluations.containsKey(card.id)
            ? s.evaluatedCount   // carte déjà comptée (repasse après "À revoir")
            : s.evaluatedCount + 1,
        exitResult: result,
      ));
    }
    ```
  - [x] Méthode `advanceToNext()` — appelée par `FlashCardWidget.onExitComplete` :
    ```dart
    void advanceToNext() {
      final s = state.value;
      if (s == null) return;
      final nextPos = s.currentQueuePos + 1;
      final isComplete = nextPos >= s.queue.length;
      state = AsyncValue.data(s.copyWith(
        currentQueuePos: nextPos,
        isFlipped: false,
        exitResult: null,
        semanticFeedback: null,
        isComplete: isComplete,
      ));
    }
    ```
  - [x] Méthode `flip()`, `setSemanticFeedback(SemanticFeedback)`, `restartWithErrors()`
  - [x] `restartWithErrors()` — réinitialise depuis les cartes "À revoir" de la session précédente :
    ```dart
    void restartWithErrors() {
      final s = state.value;
      if (s == null) return;
      final errorCardIds = s.evaluations.entries
          .where((e) => e.value == DrillEvaluationResult.aRevoir)
          .map((e) => e.key)
          .toSet();
      final errorIndices = s.cards
          .asMap()
          .entries
          .where((e) => errorCardIds.contains(e.value.id))
          .map((e) => e.key)
          .toList();
      if (errorIndices.isEmpty) return;
      state = AsyncValue.data(DrillSessionState(
        cards: s.cards,
        queue: errorIndices,
        evaluatedCount: 0,
        evaluations: {},
        isFlipped: false,
        isComplete: false,
      ));
    }
    ```

- [x] **T5 — Route GoRouter `/drill`** (AC: #6)
  - [x] Modifier `collega_app/lib/core/router/app_router.dart` :
    - Ajouter route `/drill` **avant** le `ShellRoute` (pour masquer le bottom nav)
    - La route reçoit `DrillSessionParams` via `extra`
    ```dart
    GoRoute(
      path: '/drill',
      builder: (ctx, s) {
        final params = s.extra as DrillSessionParams?;
        if (params == null) return const Scaffold(body: Center(child: Text('Paramètres manquants')));
        return DrillScreen(params: params);
      },
    ),
    ```
  - [x] Ajouter `/drill` dans la liste des routes protégées (redirect si non auth)
    ```dart
    final isProtected = state.matchedLocation.startsWith('/home') ||
        state.matchedLocation.startsWith('/colleges') ||
        state.matchedLocation.startsWith('/search') ||
        state.matchedLocation.startsWith('/profile') ||
        state.matchedLocation.startsWith('/drill');   // AJOUTER
    ```

- [x] **T6 — DrillScreen** (AC: #1, #2, #3, #4, #6)
  - [x] Créer `collega_app/lib/features/drill/presentation/drill_screen.dart`
  - [x] `DrillScreen` — `ConsumerStatefulWidget` (besoin du BuildContext pour navigation)
  - [x] Structure de l'écran :
    ```dart
    Scaffold(
      // PAS de bottomNavigationBar
      body: SafeArea(
        child: drillSessionAsync.when(
          loading: () => const LinearProgressIndicator(),
          error: (e, _) => Center(child: Text(e.toString())),
          data: (session) => session.isComplete
              ? _DrillEndScreen(session: session, notifier: notifier)
              : _DrillActiveView(session: session, notifier: notifier, context: context),
        ),
      ),
    )
    ```
  - [x] `_DrillHeader` widget inline :
    ```dart
    Row(children: [
      IconButton(icon: const Icon(Icons.close), onPressed: () => context.pop()),
      Expanded(child: Text(title, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center)),
      ShadBadge(backgroundColor: _rangColor(currentCard.rang),
                child: Text('Rang ${currentCard.rang}', style: TextStyle(color: Colors.white))),
    ])
    ```
  - [x] ProgressBar avec compteur texte :
    ```dart
    Column(children: [
      Text('${session.evaluatedCount} / ${session.totalInitial} fiches',
           style: AppTypography.labelMedium()),
      const SizedBox(height: 4),
      ShadProgress(value: session.totalInitial == 0 ? 0
          : session.evaluatedCount / session.totalInitial),
    ])
    ```
  - [x] Utiliser `FlashCardWidget` de Story 4.1 avec `exitResult` et `onExitComplete: notifier.advanceToNext`
  - [x] Pour les fiches définition (`card.cardType == 'definition'` ET `!session.isFlipped`) :
    - Afficher `ShadInput` (contrôleur local) + bouton "Évaluer"
    - Masquer le hint "Tapoter pour voir la réponse"
    - `_handleDefinitionSubmit(String answer)` :
      ```dart
      Future<void> _handleDefinitionSubmit(String answer) async {
        if (answer.trim().isEmpty) return;
        try {
          final repo = ref.read(drillRepositoryProvider);
          final feedback = await repo.evaluateSemantic(card.id, answer.trim());
          notifier.setSemanticFeedback(feedback);
          notifier.flip();  // retourner la card
        } on DioException {
          // Offline → auto-évaluation classique
          notifier.flip();
        }
      }
      ```
    - Afficher `session.semanticFeedback` si non null (bandeau résultat entre card et DrillEvaluationBar)
  - [x] Utiliser `DrillEvaluationBar` de Story 4.1 avec `isVisible: session.isFlipped`

- [x] **T7 — DrillEndScreen** (AC: #5)
  - [x] Widget `_DrillEndScreen` dans `drill_screen.dart` (même fichier pour simplicité)
  - [x] `MasteryCircle` — `CustomPaint` :
    ```dart
    class _MasteryCircle extends StatelessWidget {
      const _MasteryCircle({required this.ratio});
      final double ratio;

      @override
      Widget build(BuildContext context) {
        return CustomPaint(
          size: const Size(160, 160),
          painter: _DonutPainter(ratio: ratio),
          child: Center(
            child: Text(
              '${(ratio * 100).round()}%',
              style: AppTypography.titleLarge()
                  .copyWith(fontWeight: FontWeight.bold),
            ),
          ),
        );
      }
    }

    class _DonutPainter extends CustomPainter {
      const _DonutPainter({required this.ratio});
      final double ratio;

      @override
      void paint(Canvas canvas, Size size) {
        final center = Offset(size.width / 2, size.height / 2);
        final radius = size.width / 2 - 10;
        const strokeWidth = 20.0;
        final rect = Rect.fromCircle(center: center, radius: radius);

        // Fond gris
        canvas.drawArc(rect, -pi / 2, 2 * pi, false,
            Paint()..color = const Color(0xFFE8F5EC)
                   ..style = PaintingStyle.stroke
                   ..strokeWidth = strokeWidth);

        // Arc maîtrise (vert primary)
        if (ratio > 0) {
          canvas.drawArc(rect, -pi / 2, 2 * pi * ratio, false,
              Paint()..color = AppColors.primary
                     ..style = PaintingStyle.stroke
                     ..strokeWidth = strokeWidth
                     ..strokeCap = StrokeCap.round);
        }
      }

      @override
      bool shouldRepaint(_DonutPainter old) => old.ratio != ratio;
    }
    ```
  - [x] `_StatsBento` — 3 `ShadCard` en `Row` :
    ```dart
    Row(children: [
      _StatCard(label: 'Maîtrisé', count: summary.maîtriseCount, color: AppColors.primary),
      _StatCard(label: 'Bien',     count: summary.bienCount,     color: AppColors.secondary),
      _StatCard(label: 'À revoir', count: summary.aRevoirCount,  color: AppColors.error),
    ])
    ```
  - [x] CTAs :
    ```dart
    ShadButton(
      onPressed: summary.aRevoirCount > 0 ? notifier.restartWithErrors : null,
      width: double.infinity,
      child: const Text('Recommencer les erreurs'),
    ),
    ShadButton.outline(
      onPressed: () => context.go('/home'),
      width: double.infinity,
      child: const Text('Retour à l\'accueil'),
    ),
    ```

- [x] **T8 — Connexion DrillLaunchBar → route `/drill`** (AC: #1, #6)
  - [x] Modifier `collega_app/lib/features/colleges/presentation/item_detail_screen.dart`
  - [x] Ajouter `collegeId` et `itemId` à `DrillLaunchBar` :
    ```dart
    class DrillLaunchBar extends StatelessWidget {
      const DrillLaunchBar({
        super.key,
        required this.cardCount,
        required this.collegeId,
        required this.itemId,
      });
      final int cardCount;
      final String collegeId;
      final String itemId;

      @override
      Widget build(BuildContext context) {
        return Container(
          color: Theme.of(context).scaffoldBackgroundColor,
          padding: const EdgeInsets.fromLTRB(AppSpacing.screenMargin, 8, AppSpacing.screenMargin, 8),
          child: ShadButton(
            onPressed: cardCount == 0 ? null : () => context.push(
              '/drill',
              extra: DrillSessionParams(collegeId: collegeId, itemId: itemId),
            ),
            width: double.infinity,
            child: Text('Lancer le drill · $cardCount fiches'),
          ),
        );
      }
    }
    ```
  - [x] Mettre à jour l'appel dans `ItemDetailScreen.build()` :
    ```dart
    bottomNavigationBar: DrillLaunchBar(
      cardCount: cards.length,
      collegeId: collegeId,
      itemId: itemId,
    ),
    ```

- [x] **T9 — Endpoint backend évaluation sémantique** (AC: #4)
  - [x] Créer `collega_backend/app/api/v1/drill.py` :
    ```python
    """Évaluation sémantique des fiches définition via Claude — FR29."""
    from __future__ import annotations
    import uuid
    from fastapi import APIRouter, Depends, HTTPException
    from pydantic import BaseModel
    from sqlalchemy.ext.asyncio import AsyncSession
    from app.core.database import get_db
    from app.deps import require_subscription
    from app.models.flash_card import FlashCard
    from app.services.generation.claude_client import ClaudeClient

    router = APIRouter(tags=["drill"])

    class SemanticEvalRequest(BaseModel):
        user_answer: str

    class SemanticEvalResult(BaseModel):
        result: str    # 'correct' | 'partial' | 'incorrect'
        feedback: str

    @router.post("/flash-cards/{card_id}/evaluate-semantic")
    async def evaluate_semantic(
        card_id: uuid.UUID,
        body: SemanticEvalRequest,
        current_user=Depends(require_subscription),
        db: AsyncSession = Depends(get_db),
    ):
        card = await db.get(FlashCard, card_id)
        if card is None or card.user_id != current_user.id:
            raise HTTPException(404, detail={"code": "CARD_NOT_FOUND"})
        if card.card_type != 'definition':
            raise HTTPException(422, detail={"code": "NOT_DEFINITION_CARD"})

        claude = ClaudeClient()
        prompt = (
            f"Terme : {card.recto}\n"
            f"Définition attendue : {card.verso}\n"
            f"Réponse de l'étudiant : {body.user_answer}\n\n"
            "Évalue la proximité sémantique entre la réponse de l'étudiant et la définition attendue.\n"
            "Réponds en JSON strict : {\"result\": \"correct\"|\"partial\"|\"incorrect\", \"feedback\": \"...\"}\n"
            "- correct : la réponse capture l'essentiel du concept\n"
            "- partial : la réponse est incomplète ou partiellement inexacte\n"
            "- incorrect : la réponse est incorrecte ou hors sujet\n"
            "Le feedback doit être une phrase courte (≤ 30 mots) en français."
        )
        result_json = await claude.ask_json(prompt)
        return {"data": SemanticEvalResult(**result_json).model_dump()}
    ```
  - [x] Enregistrer le router dans `collega_backend/app/main.py` :
    ```python
    from app.api.v1 import drill
    app.include_router(drill.router, prefix="/v1")
    ```
  - [x] Ajouter `ask_json()` à `ClaudeClient` si absent (retourne `dict` parsé depuis JSON)
    - Pattern : appeler `client.messages.create(...)` avec `stop_sequences=['}']` ou parser le JSON de la réponse text

- [x] **T10 — Tests widget et provider** (AC: #1, #2, #3, #5)
  - [x] Créer `collega_app/test/features/drill/drill_session_notifier_test.dart`
    - Test : chargement initial → queue dans le bon ordre (a_revoir en premier)
    - Test : `evaluate(aRevoir)` → carte réinsérée dans queue, evaluatedCount correct
    - Test : `evaluate(bien)` → evaluatedCount + 1, carte non réinsérée
    - Test : `evaluate(maitrise)` → evaluatedCount + 1
    - Test : `advanceToNext()` après évaluation → currentQueuePos avance, isFlipped = false
    - Test : session complète → `isComplete == true`
    - Test : `restartWithErrors()` → queue = indices des cartes "À revoir" uniquement
  - [x] Créer `collega_app/test/features/drill/drill_repository_test.dart` (avec DB en mémoire)
    - Test : `getCardsForDrill(itemId: ...)` → retourne les fiches Drift sans réseau
    - Test : `updateCardDrillLevel(id, bien)` → `drillLevel == 'bien'`, `nextReviewAt ≈ now + 86400000`
    - Test : `updateCardDrillLevel(id, maitrise)` → `nextReviewAt ≈ now + 604800000`
  - [x] Créer `collega_app/test/features/drill/drill_screen_test.dart`
    - Test : widget affiche DrillHeader + ProgressBar + FlashCardWidget
    - Test : `isComplete == true` → `_DrillEndScreen` visible (chercher 'Session terminée')
    - Test : bottom nav absent (ne pas trouver `BottomNavBar`)

- [x] **T11 — Validation finale**
  - [x] `cd collega_app && flutter analyze` → 0 nouvelle erreur (max les 2 infos pré-existantes dans `colleges_detail_providers.dart`)
  - [x] `cd collega_app && flutter test test/features/drill/` → tous verts, 0 régression
  - [x] `cd collega_app && flutter test` (suite complète) → 0 nouvelle régression

---

## Dev Notes

### Structure des fichiers

```
collega_app/lib/
├── core/
│   └── database/
│       ├── app_database.dart              # MODIFIER : schemaVersion 4, migration
│       ├── app_database.g.dart            # RÉGÉNÉRER via build_runner
│       └── tables/
│           └── flash_cards_table.dart     # MODIFIER : +drillLevel, +nextReviewAt, +reviewCount
├── features/
│   └── drill/
│       ├── data/
│       │   └── drill_repository.dart      # CRÉER — T3
│       ├── domain/
│       │   ├── drill_state.dart           # EXISTANT — DrillEvaluationResult (ne pas modifier)
│       │   └── drill_session_state.dart   # CRÉER — T2
│       ├── presentation/
│       │   ├── drill_screen.dart          # CRÉER — T6 + T7
│       │   └── widgets/
│       │       └── drill_evaluation_bar.dart  # EXISTANT (Story 4.1 — ne pas modifier)
│       └── drill_providers.dart           # CRÉER — T4
└── ...
collega_backend/
└── app/
    └── api/
        └── v1/
            └── drill.py                   # CRÉER — T9
```

### Composants Story 4.1 à RÉUTILISER sans modification

| Composant | Chemin | Usage dans DrillScreen |
|---|---|---|
| `FlashCardWidget` | `features/generation/widgets/flash_card_widget.dart` | Card principale (recto/verso + animation sortie) |
| `DrillEvaluationBar` | `features/drill/widgets/drill_evaluation_bar.dart` | Boutons À revoir / Bien / Maîtrisé |
| `DrillEvaluationResult` | `features/drill/domain/drill_state.dart` | Enum partagé entre notifier et widgets |

**IMPORTANT** : Ne pas modifier ces fichiers — ils ont été validés en review Story 4.1.

### Problème F14 (différé Story 4.1) — à résoudre dans cette story

La review 4.1 a identifié (F14) que `DrillEvaluationBar` utilise simultanément `AnimatedOpacity` et `IgnorePointer`, deux sources de vérité pour la visibilité. La solution :

- Dans `DrillScreen`, contrôler `isVisible` depuis `session.isFlipped` (source unique dans le notifier)
- Laisser `DrillEvaluationBar` tel quel (son comportement existant est correct pour le cas d'usage)
- Si une incohérence est observée en intégration, documenter dans les Dev Notes et différer à 4.5

### Paramètre `DrillSessionParams` dans GoRouter

GoRouter 14.x passe `extra` comme `Object?`. Pour naviguer :
```dart
context.push('/drill', extra: DrillSessionParams(collegeId: ..., itemId: ...));
```
Pour récupérer :
```dart
final params = state.extra as DrillSessionParams?;
```
**NE PAS** utiliser `queryParameters` pour les objets complexes — cela force la sérialisation/désérialisation manuelle.

### AsyncNotifier pattern pour DrillSessionNotifier

```dart
// drill_providers.dart
final drillRepositoryProvider = Provider<DrillRepository>((ref) => DrillRepository(
  dio: ref.read(apiClientProvider).dio,
  db: ref.read(databaseProvider),
));

final drillSessionProvider = AsyncNotifierProvider.family<
    DrillSessionNotifier, DrillSessionState, DrillSessionParams>(
  DrillSessionNotifier.new,
);

class DrillSessionNotifier
    extends FamilyAsyncNotifier<DrillSessionState, DrillSessionParams> {
  @override
  Future<DrillSessionState> build(DrillSessionParams arg) async {
    final repo = ref.read(drillRepositoryProvider);
    final cards = await repo.getCardsForDrill(
      itemId: arg.itemId,
      rangs: arg.rangs,
      onlyARevoir: arg.onlyARevoir,
    );

    // Tri initial : a_revoir → new → bien/maitrise, puis A→B→C dans chaque groupe
    final sorted = _sortCards(cards);
    final queue = List.generate(sorted.length, (i) => i);

    return DrillSessionState(cards: sorted, queue: queue);
  }

  List<FlashCardModel> _sortCards(List<FlashCardModel> cards) {
    const levelOrder = {'a_revoir': 0, 'new': 1, 'bien': 2, 'maitrise': 3};
    const rangOrder = {'A': 0, 'B': 1, 'C': 2};
    return [...cards]..sort((a, b) {
        // NB: drillLevel n'est pas dans FlashCardModel — utiliser la valeur Drift directement
        // Simplification : charger drillLevel séparément ou l'ajouter à FlashCardModel
        // Voir note ci-dessous
        final lA = levelOrder['new']!;  // par défaut 'new' si absent de FlashCardModel
        final lB = levelOrder['new']!;
        if (lA != lB) return lA.compareTo(lB);
        return (rangOrder[a.rang] ?? 3).compareTo(rangOrder[b.rang] ?? 3);
      });
  }
  // ... evaluate(), advanceToNext(), flip(), etc.
}
```

**NOTE CRITIQUE — drillLevel dans FlashCardModel** : Le modèle `FlashCardModel` (Story 3) n'a pas de champ `drillLevel`. Deux options :
- **Option A (recommandée)** : Ajouter `drillLevel` à `FlashCardModel` (modèle local) + `_rowToModel` dans `DrillRepository`. Le champ n'est utilisé QUE pour le tri initial → pas d'impact sur les endpoints backend.
- **Option B** : Faire le tri en Drift directement (`.orderBy(...)`) dans `getCardsForDrill`. Plus propre architecturalement.

→ Utiliser **Option B** : ajouter `.orderBy([...])` dans `DrillRepository.getCardsForDrill` :
```dart
query
  ..orderBy([
    (t) => OrderingTerm(
      expression: t.drillLevel,  // 'a_revoir' < 'bien' < 'maitrise' < 'new' alphabétiquement — NON
    ),
  ]);
```
**Attention** : l'ordre alphabétique de drillLevel n'est pas 'a_revoir' < 'new' < 'bien' < 'maitrise'. Il faut utiliser un tri avec `CASE WHEN` ou trier en Dart après récupération.

→ **Solution finale** : Trier en Dart dans `DrillRepository.getCardsForDrill` avec la logique ci-dessus (pas en SQL).

### ClaudeClient — méthode ask_json()

Si `ClaudeClient` n'a pas de méthode `ask_json()`, implémenter :
```python
async def ask_json(self, prompt: str) -> dict:
    import json
    message = await self.client.messages.create(
        model="claude-haiku-4-5-20251001",  # modèle léger suffisant pour éval simple
        max_tokens=256,
        messages=[{"role": "user", "content": prompt}],
    )
    text = message.content[0].text
    # Extraire le JSON (la réponse peut contenir du texte autour)
    start = text.find('{')
    end = text.rfind('}') + 1
    return json.loads(text[start:end])
```

### Pattern de test pour les providers Riverpod (sans mocks)

```dart
// Utiliser un ProviderContainer avec override du repository
final container = ProviderContainer(
  overrides: [
    drillRepositoryProvider.overrideWith((ref) => FakeDrillRepository(cards: fixtures)),
  ],
);
addTearDown(container.dispose);

final notifier = container.read(drillSessionProvider(params).notifier);
await container.read(drillSessionProvider(params).future); // attendre le build

notifier.evaluate(DrillEvaluationResult.aRevoir);
final state = container.read(drillSessionProvider(params)).value!;
expect(state.queue.length, greaterThan(params.initialQueueLength));
```

### MasteryCircle — CustomPaint détail

- Utiliser `dart:math` pour `pi`
- `arc` commence à `-pi/2` (haut de cercle, 12h)
- Sweep angle = `2 * pi * ratio`
- `StrokeCap.round` pour des bords arrondis
- Pas de librairie externe — CustomPaint est suffisant

### Anti-patterns à éviter

- **NE PAS** recréer `FlashCardWidget` ou `DrillEvaluationBar` — les utiliser tels quels
- **NE PAS** mettre la logique de queue dans `DrillScreen` — tout dans `DrillSessionNotifier`
- **NE PAS** appeler le réseau dans `DrillSessionNotifier.build()` — uniquement Drift
- **NE PAS** placer `DrillScreen` dans le `ShellRoute` GoRouter — sinon bottom nav visible
- **NE PAS** utiliser `ShadSkeleton` — absent de `shadcn_ui ^0.19.0`
- **NE PAS** utiliser `print()` / `debugPrint()` — utiliser `AppLogger`
- **NE PAS** créer un `drillLevel` en `String` dans `FlashCardModel` (modèle domain) — c'est une donnée de Drift, pas une donnée API

### État du codebase au début de cette story

| Composant | État | Chemin |
|---|---|---|
| `FlashCardWidget` | ✅ Existe et testé (Story 4.1) | `features/generation/widgets/flash_card_widget.dart` |
| `DrillEvaluationBar` | ✅ Existe et testé (Story 4.1) | `features/drill/widgets/drill_evaluation_bar.dart` |
| `DrillEvaluationResult` | ✅ Existe | `features/drill/domain/drill_state.dart` |
| `DrillLaunchBar` | ✅ Existe mais stub (`onPressed: null`) | `colleges/presentation/item_detail_screen.dart:429` |
| `FlashCards` Drift table | ✅ Existe — schema v3, SANS drillLevel | `core/database/tables/flash_cards_table.dart` |
| `AppDatabase` | ✅ Existe — schema version 3 | `core/database/app_database.dart` |
| `DrillScreen` | 🚫 À créer | `features/drill/presentation/drill_screen.dart` |
| `DrillSessionNotifier` | 🚫 À créer | `features/drill/drill_providers.dart` |
| `DrillRepository` | 🚫 À créer | `features/drill/data/drill_repository.dart` |
| Route `/drill` | 🚫 À ajouter | `core/router/app_router.dart` |
| Backend `drill.py` | 🚫 À créer | `collega_backend/app/api/v1/drill.py` |

### Intelligence git (patterns établis)

- `flutter analyze` → 0 erreur validé avant chaque merge (depuis Stories 2.x à 3.x)
- Pattern test : `ShadApp(theme: buildShadTheme(), home: Scaffold(body: ...))` avec `ProviderScope`
- `unawaited(...)` pour les opérations Drift fire-and-forget (pattern de `colleges_detail_providers.dart:70`)
- `if (!mounted) return` dans tous les callbacks async stateful
- `ConsumerStatefulWidget` pour les écrans qui ont à la fois du state local et du Riverpod

### Règles qualité héritées

- `flutter analyze` → 0 erreur avant marquage terminé
- `AsyncNotifier` pour tout état async Flutter (architecture spec)
- `ShadToast` pour les erreurs non-bloquantes (ex: éval sémantique offline)
- Logique métier dans les Notifiers, jamais dans les widgets
- Tap targets ≥ 44×44px (DrillHeader ✕ button)
- `Semantics` sur les composants custom interactifs

---

### Références

- `FlashCardWidget` (composant Story 4.1) : `collega_app/lib/features/generation/widgets/flash_card_widget.dart`
- `DrillEvaluationBar` (composant Story 4.1) : `collega_app/lib/features/drill/widgets/drill_evaluation_bar.dart`
- `DrillEvaluationResult` enum : `collega_app/lib/features/drill/domain/drill_state.dart`
- `DemoDrillScreen` (référence pattern UX) : `collega_app/lib/features/demo/presentation/demo_drill_screen.dart`
- `DemoDrillNotifier` (référence pattern notifier simple) : `collega_app/lib/features/demo/demo_providers.dart`
- `FlashCards` table Drift : `collega_app/lib/core/database/tables/flash_cards_table.dart`
- `AppDatabase` (migration pattern) : `collega_app/lib/core/database/app_database.dart`
- `CollegeDetailRepository` (pattern repository Drift) : `collega_app/lib/features/colleges/data/college_detail_repository.dart`
- `CollegeDetailNotifier` (pattern AsyncNotifier family) : `collega_app/lib/features/colleges/colleges_detail_providers.dart`
- `DrillLaunchBar` (stub à connecter) : `collega_app/lib/features/colleges/presentation/item_detail_screen.dart:429`
- Architecture drill structure : `_bmad-output/planning-artifacts/architecture.md#Structure Patterns`
- UX drill screens : `_bmad-output/planning-artifacts/ux-design-specification.md#Mode Drill, #Fin de session`
- FR24-FR29 : `_bmad-output/planning-artifacts/epics.md#Story 4.2`
- NFR3 quiz < 100ms : `_bmad-output/planning-artifacts/architecture.md#NFR3`

---

## Dev Agent Record

### Agent Model Used

claude-sonnet-4-6

### Debug Log References

### Completion Notes List

- T1 : Drift schema v4 — ajout drillLevel/nextReviewAt/reviewCount + migration `from < 4`, build_runner ok
- T2 : DrillSessionState, DrillSessionParams (ListEquality, collection ^1.18 ajouté pubspec), SemanticFeedback, DrillSessionSummary
- T3 : DrillRepository — getCardsForDrill (offline Drift, tri Dart a_revoir→new→bien→maitrise puis rang), updateCardDrillLevel (fire-and-forget), evaluateSemantic
- T4 : DrillSessionNotifier (FamilyAsyncNotifier) + drillRepositoryProvider + drillSessionProvider — flip/evaluate/advanceToNext/setSemanticFeedback/restartWithErrors
- T5 : Route `/drill` hors ShellRoute (bottom nav masqué), `/drill` dans isProtected
- T6+T7 : DrillScreen (ConsumerWidget + ConsumerStatefulWidget _DrillActiveView) — header✕, progressbar, FlashCardWidget, saisie définition, SemanticFeedbackBanner, DrillEvaluationBar ; DrillEndScreen (_MasteryCircle CustomPaint donut, _StatCard x3, CTAs)
- T8 : DrillLaunchBar connecté (collegeId+itemId params, context.push /drill)
- T9 : Backend drill.py (POST /v1/flash-cards/{id}/evaluate-semantic), ClaudeClient.ask_json(), drill_router inclus dans main.py
- T10 : 18 tests créés (notifier×7, repository×3, screen×3 + bar×5 existants) — tous verts
- T11 : flutter analyze → 2 infos pré-existantes seulement ; flutter test → 81/81 verts

### File List

- `collega_app/lib/core/database/tables/flash_cards_table.dart` (modifier)
- `collega_app/lib/core/database/app_database.dart` (modifier)
- `collega_app/lib/core/database/app_database.g.dart` (régénérer — build_runner)
- `collega_app/lib/features/drill/domain/drill_session_state.dart` (créer)
- `collega_app/lib/features/drill/data/drill_repository.dart` (créer)
- `collega_app/lib/features/drill/drill_providers.dart` (créer)
- `collega_app/lib/features/drill/presentation/drill_screen.dart` (créer)
- `collega_app/lib/core/router/app_router.dart` (modifier)
- `collega_app/lib/features/colleges/presentation/item_detail_screen.dart` (modifier DrillLaunchBar)
- `collega_backend/app/api/v1/drill.py` (créer)
- `collega_backend/app/main.py` (modifier — include router)
- `collega_app/test/features/drill/drill_session_notifier_test.dart` (créer)
- `collega_app/test/features/drill/drill_repository_test.dart` (créer)
- `collega_app/test/features/drill/drill_screen_test.dart` (créer)

### Review Findings

- [ ] [Review][Decision] F12 — "À revoir" clamp min +1 vs spec AC3 "+3 unconditionnels" — La spec AC3 dit "réinsérée position currentIndex + 3" sans exception. L'implémentation clamp le minimum à +1 pour les queues courtes. Ambiguïté : le comportement +1 est pragmatiquement correct si < 3 cartes restantes, mais dévie de l'AC. Décision requise : conserver le clamp ou ajouter une exception explicite dans la spec ?

- [x] [Review][Patch] F1 — `ask_json`: aucune garde si la réponse ne contient pas de JSON valide (find==-1, content vide, ou APIError Anthropic) [collega_backend/app/services/generation/claude_client.py:74-82]
- [x] [Review][Patch] F2 — Aucun try/except autour de `SemanticEvalResult(**result_json)` : une ValidationError Pydantic ou JSONDecodeError remonte en 500 [collega_backend/app/api/v1/drill.py:52-53]
- [x] [Review][Patch] F3 — Migration DB : `if (from < 4)` — faux positif confirmé, guard correct pour tous les chemins d'upgrade (v1/v2/v3→v4) [collega_app/lib/core/database/app_database.dart:41-45]
- [x] [Review][Patch] F4 — Injection de prompt via `body.user_answer` dans l'appel Claude : délimiteurs `<reponse>` ajoutés + instruction anti-injection [collega_backend/app/api/v1/drill.py:41-52]
- [x] [Review][Patch] F5 — Liste de cartes vide : `DrillSessionNotifier.build` crée un état `isComplete=false, queue=[]`, `_DrillActiveView` affiche un `CircularProgressIndicator` infini [collega_app/lib/features/drill/drill_providers.dart:27-36]
- [x] [Review][Patch] F6 — Header affiche `card.itemId` (ID technique) au lieu du nom lisible de l'item — `itemName` threadé via DrillSessionParams [collega_app/lib/features/drill/presentation/drill_screen.dart:119]
- [x] [Review][Patch] F7 — Double-tap race sur `evaluate()` : guard `if (s.exitResult != null) return;` ajouté [collega_app/lib/features/drill/drill_providers.dart:50]
- [x] [Review][Patch] F8 — `_handleDefinitionSubmit` ne catch que `DioException` → élargi à `catch (_)` [collega_app/lib/features/drill/presentation/drill_screen.dart:82]
- [x] [Review][Patch] F9 — `response.data?['data'] as Map<String, dynamic>` peut être null ou mauvais type → null safety ajoutée [collega_app/lib/features/drill/data/drill_repository.dart:72-75]
- [x] [Review][Patch] F10 — `advanceToNext()` : guard `if (s.isComplete) return;` ajouté [collega_app/lib/features/drill/drill_providers.dart:87]
- [x] [Review][Patch] F11 — GoRoute `/drill` : cast remplacé par `is!` pattern [collega_app/lib/core/router/app_router.dart:52]

- [x] [Review][Defer] D1 — HTTP 404 utilisé pour "non trouvé" ET "interdit" dans evaluate_semantic [collega_backend/app/api/v1/drill.py:35-36] — deferred, pattern pré-existant dans toute l'API
- [x] [Review][Defer] D2 — `evaluateSemantic` appelé directement depuis la couche widget (bypass notifier) — deferred, architecture intentionnelle documentée (fallback offline)
- [x] [Review][Defer] D3 — Model ID `claude-haiku-4-5-20251001` hardcodé dans `ask_json` — deferred, préoccupation de maintenance

## Change Log

- 2026-05-14 — Story 4.2 créée par create-story. Analyse complète des artifacts Story 4.1, Drift schema, router, UX spec, architecture. Statut → ready-for-dev.
- 2026-05-14 — Implémentation complète T1→T11 par claude-sonnet-4-6. 81/81 tests verts. Statut → review.
- 2026-05-14 — Code review (bmad-code-review) : 1 decision_needed (résolu → conserver clamp), 10 patch appliqués (F1-F11, F3 faux positif), 3 defer, 13 dismissed. Statut → done.
