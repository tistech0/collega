# Story 4.5 : Progression par Collège/Rang & Rappels

Status: done

## Story

En tant qu'**étudiant**,
je veux consulter ma progression détaillée par collège et par rang, et configurer un rappel quotidien,
afin de rester motivé et de ne pas oublier de réviser.

## Acceptance Criteria

1. **Progression par item : drill levels avec chiffres exacts (AC1 — FR34)**
   - Étant donné l'écran de progression d'un collège (`/colleges/{ref_id}`)
   - Quand je l'ouvre
   - Alors le composant `ItemProgressBar` affiche pour chaque item la répartition **À revoir / Bien / Maîtrisé / Non vues** (drill levels de Drift) en barre segmentée 3 couleurs
   - Et les chiffres exacts (nombre de fiches par drill level) sont affichés sous la barre
   - Et les FilterChips Rang A / Rang B / Rang C filtrent toujours la vue des items
   - Et un résumé global **"X% maîtrisé"** est affiché dans la carte de résumé en haut (basé sur les données Drift, pas l'API)

2. **CollegeProgressTile temps réel Drift (AC2 — FR34)**
   - Étant donné le tab Collèges
   - Quand je consulte un `CollegeProgressTile` pour un collège importé
   - Alors la barre 4 segments (Maîtrisé / Bien / À revoir / Non vues) reflète les données Drift **en temps réel** après chaque session de drill
   - Et les données se mettent à jour sans action de l'utilisateur (reactive via Drift `.watch()`)

3. **Rappel quotidien configurable (AC3 — FR35)**
   - Étant donné l'écran Profil
   - Quand j'active le toggle "Rappel quotidien" et sélectionne une heure
   - Alors le token APNs et l'heure de rappel (UTC) sont enregistrés côté backend via `POST /v1/notifications/reminder`
   - Et le backend envoie une notification push chaque jour à l'heure configurée : "C'est l'heure de réviser !"

4. **Désactivation des rappels (AC4 — FR35)**
   - Étant donné que le rappel est activé
   - Quand je bascule le toggle "Rappel quotidien" sur OFF dans l'écran Profil
   - Alors `DELETE /v1/notifications/reminder` est appelé
   - Et les notifications quotidiennes s'arrêtent immédiatement (suppression de `reminder_hour_utc` en base)
   - Et les notifications "Fiches prêtes" (FR23 — `generation_complete`) restent actives indépendamment

5. **Écran Profil fonctionnel (nouveau)**
   - Étant donné l'onglet Profil (bottom nav index 3)
   - Quand je l'ouvre
   - Alors l'écran affiche : email de l'utilisateur, badge abonnement, `NotifCard` (toggle rappel + time picker), bouton "Se déconnecter"

---

## Tasks / Subtasks

- [x] **T1 — Backend : Migration Alembic #009 — `reminder_hour_utc` sur `users`** (AC: #3, #4)
  - [x] Créer `collega_backend/alembic/versions/009_add_reminder_hour_utc_to_users.py`
  - [x] `ALTER TABLE users ADD COLUMN reminder_hour_utc INTEGER NULL` (0–23, heure UTC)
  - [x] Mettre à jour `collega_backend/app/models/user.py` : ajouter `reminder_hour_utc: Mapped[int | None] = mapped_column(Integer, nullable=True)`
  - [x] **IMPORTANT** : ajouter `User` dans `app/models/__init__.py` si pas déjà là (règle de la Story 1.1 deferred)

- [x] **T2 — Backend : `send_daily_reminders` worker** (AC: #3, #4)
  - [ ] Créer `collega_backend/app/workers/daily_reminder_worker.py` :
    ```python
    import logging
    from datetime import datetime, timezone

    from sqlalchemy import select
    from sqlalchemy.ext.asyncio import AsyncSession

    from app.core.database import AsyncSessionFactory
    from app.models.user import User
    from app.services.notifications.apns_service import get_notification_service

    logger = logging.getLogger(__name__)


    async def send_daily_reminders(ctx: dict) -> None:
        """Envoyé à :00 de chaque heure — notifie les users avec reminder_hour_utc == heure courante UTC."""
        current_hour = datetime.now(timezone.utc).hour
        async with AsyncSessionFactory() as db:
            result = await db.execute(
                select(User).where(
                    User.reminder_hour_utc == current_hour,
                    User.apns_token.is_not(None),
                )
            )
            users = result.scalars().all()
            logger.info("send_daily_reminders hour=%d → %d users", current_hour, len(users))
            svc = get_notification_service()
            for user in users:
                try:
                    await svc.send_daily_reminder(user.apns_token)
                except Exception as e:  # noqa: BLE001
                    logger.warning("Reminder push échoué user=%s : %s", user.id, e)
    ```
  - [ ] **IMPORTANT** : Pour appeler `AsyncSessionFactory` depuis le worker ARQ, utiliser la même factory que `database.py`. Si elle n'existe pas, créer `AsyncSessionFactory = async_sessionmaker(engine, ...)` dans `database.py`.

- [x] **T3 — Backend : `APNsNotificationService.send_daily_reminder` + `NullNotificationService`** (AC: #3)
  - [ ] Dans `collega_backend/app/services/notifications/apns_service.py`, ajouter à la classe abstraite `NotificationService` :
    ```python
    @abstractmethod
    async def send_daily_reminder(self, apns_token: str | None) -> None: ...
    ```
  - [ ] Dans `NullNotificationService` :
    ```python
    async def send_daily_reminder(self, apns_token: str | None) -> None:
        logger.debug("NullNotificationService: rappel quotidien ignoré")
    ```
  - [ ] Dans `APNsNotificationService` :
    ```python
    async def send_daily_reminder(self, apns_token: str | None) -> None:
        if not apns_token:
            return
        from aioapns import NotificationRequest, PushType
        request = NotificationRequest(
            device_token=apns_token,
            message={
                "aps": {
                    "alert": {
                        "title": "AppMédecine",
                        "body": "C'est l'heure de réviser !",
                    },
                    "sound": "default",
                },
            },
            push_type=PushType.ALERT,
        )
        result = await self._apns.send_notification(request)
        if not result.is_successful:
            logger.warning("Rappel push échoué : %s", result.description)
    ```

- [x] **T4 — Backend : `workers/settings.py` — enregistrement cron daily_reminders** (AC: #3)
  - [ ] Modifier `collega_backend/app/workers/settings.py` :
    ```python
    from arq.cron import cron

    from app.core.redis import redis_settings
    from app.workers.cleanup_worker import cleanup_ocr_text
    from app.workers.daily_reminder_worker import send_daily_reminders
    from app.workers.generation_worker import generate_college_cards
    from app.workers.ocr_worker import process_college_ocr

    WORKER_SETTINGS = {
        "redis_settings": redis_settings,
        "functions": [process_college_ocr, generate_college_cards],
        "cron_jobs": [
            cron(cleanup_ocr_text, minute=0),
            cron(send_daily_reminders, minute=0),  # toutes les heures, à :00
        ],
        "max_jobs": 10,
        "job_timeout": 7200,
        "keep_result": 3600,
        "retry_jobs": True,
        "max_retries": 3,
    }
    ```

- [x] **T5 — Backend : endpoints reminder dans `notifications.py`** (AC: #3, #4)
  - [ ] Dans `collega_backend/app/api/v1/notifications.py`, ajouter :
    ```python
    class ReminderRequest(BaseModel):
        hour_utc: int

        @field_validator("hour_utc")
        @classmethod
        def validate_hour(cls, v: int) -> int:
            if not 0 <= v <= 23:
                raise ValueError("hour_utc doit être entre 0 et 23")
            return v


    @router.post("/notifications/reminder")
    async def set_reminder(
        body: ReminderRequest,
        current_user=Depends(get_current_user),
        db: AsyncSession = Depends(get_db),
    ):
        current_user.reminder_hour_utc = body.hour_utc
        await db.commit()
        return {"data": {"reminder_enabled": True, "hour_utc": body.hour_utc}}


    @router.delete("/notifications/reminder")
    async def clear_reminder(
        current_user=Depends(get_current_user),
        db: AsyncSession = Depends(get_db),
    ):
        current_user.reminder_hour_utc = None
        await db.commit()
        return {"data": {"reminder_enabled": False}}
    ```
  - [ ] **VÉRIFIER** que `notifications_router` est bien enregistré dans `main.py` (il l'est depuis Story 3.5)

- [x] **T6 — Backend : tests** (AC: #3, #4)
  - [ ] Créer `collega_backend/tests/api/test_reminder.py` :
    - `POST /v1/notifications/reminder` avec `{"hour_utc": 7}` → 200, `user.reminder_hour_utc == 7`
    - `POST /v1/notifications/reminder` avec `{"hour_utc": 25}` → 422 (validation)
    - `DELETE /v1/notifications/reminder` → 200, `user.reminder_hour_utc is None`
  - [ ] Créer `collega_backend/tests/workers/test_daily_reminder_worker.py` :
    - Mock `get_notification_service()` → `NullNotificationService`
    - Créer un user avec `apns_token="abc..."` et `reminder_hour_utc=current_hour`
    - Appeler `send_daily_reminders(ctx={})` → vérifier `send_daily_reminder` appelé 1 fois
    - Créer un user sans `apns_token` → vérifier `send_daily_reminder` NOT appelé

- [x] **T7 — Flutter : `DrillStats` model + `collegeDrillStatsProvider` (Drift StreamProvider)** (AC: #2)
  - [ ] Créer `collega_app/lib/features/colleges/domain/drill_stats.dart` :
    ```dart
    import 'package:flutter/foundation.dart';

    @immutable
    class DrillStats {
      const DrillStats({
        this.maitrise = 0,
        this.bien = 0,
        this.aRevoir = 0,
        this.notSeen = 0,
      });

      final int maitrise;
      final int bien;
      final int aRevoir;
      final int notSeen;

      int get total => maitrise + bien + aRevoir + notSeen;

      int get masteryPercent =>
          total == 0 ? 0 : ((maitrise / total) * 100).round();
    }
    ```
  - [ ] Dans `collega_app/lib/features/colleges/colleges_providers.dart`, ajouter :
    ```dart
    final collegeDrillStatsProvider =
        StreamProvider.family<DrillStats, String>((ref, collegeId) {
      final db = ref.watch(databaseProvider);
      return (db.select(db.flashCards)
            ..where((t) => t.collegeId.equals(collegeId)))
          .watch()
          .map((cards) {
        int maitrise = 0, bien = 0, aRevoir = 0, notSeen = 0;
        for (final c in cards) {
          switch (c.drillLevel) {
            case 'maitrise':
              maitrise++;
            case 'bien':
              bien++;
            case 'a_revoir':
              aRevoir++;
            default: // 'new' et toute valeur inconnue
              notSeen++;
          }
        }
        return DrillStats(
          maitrise: maitrise,
          bien: bien,
          aRevoir: aRevoir,
          notSeen: notSeen,
        );
      });
    });
    ```
  - [ ] Ajouter imports nécessaires : `DrillStats`, `databaseProvider`
  - [ ] **NOTE** : `StreamProvider.family` est réactif — il se met à jour automatiquement chaque fois que `flashCards` change dans Drift (après drill), sans invalidation manuelle

- [x] **T8 — Flutter : `CollegeProgressTile` — barre 4 segments Drift en temps réel** (AC: #2)
  - [ ] Modifier `collega_app/lib/features/colleges/widgets/college_progress_tile.dart` :
    - Convertir `_ImportedTile` de `StatelessWidget` en `ConsumerWidget`
    - Ajouter `final String collegeId;` dans `_ImportedTile`
    - Passer `collegeId: entry.userStatus!.collegeId` depuis `CollegeProgressTile.build`
    - Dans `_ImportedTile.build`, watch `collegeDrillStatsProvider(collegeId)` :
      ```dart
      final statsAsync = ref.watch(collegeDrillStatsProvider(collegeId));
      final stats = statsAsync.valueOrNull ?? const DrillStats();
      ```
    - Mettre à jour `_ProgressBar` avec les drill stats :
      ```dart
      _ProgressBar(
        mastered: stats.maitrise,   // vert primary
        well: stats.bien,           // teal secondary
        toReview: stats.aRevoir,    // rouge error
        notSeen: stats.notSeen,     // gris
      ),
      ```
  - [ ] **IMPORTANT** : `CollegeProgressTile` lui-même reste `StatelessWidget` — seul `_ImportedTile` devient `ConsumerWidget`. Aucun impact sur les call-sites de `CollegeProgressTile`.
  - [ ] **IMPORTANT** : si `stats.total == 0` (college importé mais aucune fiche en Drift), afficher la barre grise pleine pour indiquer "Non vues". Utiliser `notSeen: stats.total == 0 ? 1 : stats.notSeen`.

- [x] **T9 — Flutter : `ItemModel` — ajout drill level counts** (AC: #1)
  - [ ] Modifier `collega_app/lib/features/colleges/domain/college_detail_models.dart` :
    - Ajouter à `ItemModel` :
      ```dart
      class ItemModel {
        const ItemModel({
          // ... champs existants ...
          this.drillMaitrise = 0,   // NOUVEAU
          this.drillBien = 0,       // NOUVEAU
          this.drillARevoir = 0,    // NOUVEAU
          this.drillNotSeen = 0,    // NOUVEAU
        });
        // ...
        final int drillMaitrise;
        final int drillBien;
        final int drillARevoir;
        final int drillNotSeen;

        int get drillTotal => drillMaitrise + drillBien + drillARevoir + drillNotSeen;
        int get drillMasteryPercent =>
            drillTotal == 0 ? 0 : ((drillMaitrise / drillTotal) * 100).round();
      }
      ```
    - **CONSERVER** `cardCountA/B/C` existants (utilisés pour le filtrage par rang dans l'API) — ne pas les supprimer

- [x] **T10 — Flutter : `CollegeDetailRepository` — overlay drill-level data** (AC: #1)
  - [ ] Modifier `collega_app/lib/features/colleges/data/college_detail_repository.dart` :
    - Ajouter méthode `getDrillStatsByItem(String collegeId) → Future<Map<String, DrillStats>>` :
      ```dart
      Future<Map<String, DrillStats>> getDrillStatsByItem(String collegeId) async {
        final cards = await (db.select(db.flashCards)
              ..where((t) => t.collegeId.equals(collegeId)))
            .get();
        final map = <String, Map<String, int>>{};
        for (final c in cards) {
          map.putIfAbsent(c.itemId, () => {});
          map[c.itemId]![c.drillLevel] = (map[c.itemId]![c.drillLevel] ?? 0) + 1;
        }
        return map.map((itemId, counts) => MapEntry(
          itemId,
          DrillStats(
            maitrise: counts['maitrise'] ?? 0,
            bien: counts['bien'] ?? 0,
            aRevoir: counts['a_revoir'] ?? 0,
            notSeen: counts['new'] ?? 0,
          ),
        ));
      }
      ```
    - Ajouter import `DrillStats`

- [x] **T11 — Flutter : `CollegeDetailNotifier` — drill data overlay** (AC: #1)
  - [ ] Modifier `collega_app/lib/features/colleges/colleges_detail_providers.dart` :
    - Dans `CollegeDetailNotifier.build(String collegeId)`, après avoir obtenu les items (API ou Drift), overlay les drill stats :
      ```dart
      @override
      Future<CollegeDetailState> build(String collegeId) async {
        final repo = ref.read(collegeDetailRepositoryProvider);
        List<ItemModel> items;
        try {
          items = await repo.getItems(collegeId);
          if (items.isEmpty) return const CollegeDetailEmpty();
          unawaited(repo.syncItemsToDrift(collegeId, items).catchError(...));
        } on DioException {
          items = await repo.getItemsFromDrift(collegeId);
          if (items.isEmpty) return const CollegeDetailEmpty();
        }
        // NOUVEAU : overlay drill stats depuis Drift
        final drillByItem = await repo.getDrillStatsByItem(collegeId);
        items = items.map((item) {
          final drill = drillByItem[item.id] ?? const DrillStats();
          return ItemModel(
            id: item.id,
            collegeId: item.collegeId,
            itemNumber: item.itemNumber,
            rang: item.rang,
            chapterTitle: item.chapterTitle,
            ocrConfidenceScore: item.ocrConfidenceScore,
            lowConfidence: item.lowConfidence,
            cardCountA: item.cardCountA,
            cardCountB: item.cardCountB,
            cardCountC: item.cardCountC,
            drillMaitrise: drill.maitrise,
            drillBien: drill.bien,
            drillARevoir: drill.aRevoir,
            drillNotSeen: drill.notSeen,
          );
        }).toList();
        return CollegeDetailLoaded(items: items);
      }
      ```
  - [ ] **NOTE** : `collegeDetailProvider` n'est PAS un stream — la mise à jour des drill stats après drill nécessitera une invalidation manuelle (via D15 ou `ref.invalidate`). Pour ce MVP, la progression est visible au rechargement de l'écran (retour + réouverture). Une mise à jour temps réel du détail collège est un non-objectif pour cette story (seul `CollegeProgressTile` est temps réel via `StreamProvider.family`).

- [x] **T12 — Flutter : `ItemProgressBar` widget — drill levels avec chiffres** (AC: #1)
  - [ ] Modifier `collega_app/lib/features/colleges/presentation/widgets/item_progress_bar.dart` :
    - Renommer paramètres :
      ```dart
      class ItemProgressBar extends StatelessWidget {
        const ItemProgressBar({
          super.key,
          required this.countARevoir,    // remplace countA
          required this.countBien,       // remplace countB
          required this.countMaitrise,   // remplace countC
          this.countNotSeen = 0,         // NOUVEAU — 'new'
          this.showCounts = false,       // NOUVEAU — affiche chiffres
        });

        final int countARevoir;
        final int countBien;
        final int countMaitrise;
        final int countNotSeen;
        final bool showCounts;
      ```
    - Mettre à jour `build` pour utiliser les nouveaux paramètres
    - Quand `showCounts: true`, afficher sous la barre :
      ```dart
      if (showCounts) ...[
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            if (countARevoir > 0)
              Text('À revoir: $countARevoir', style: ...labelSmall...),
            if (countBien > 0)
              Text('Bien: $countBien', style: ...labelSmall...),
            if (countMaitrise > 0)
              Text('Maîtrisé: $countMaitrise', style: ...labelSmall...),
            if (countNotSeen > 0)
              Text('Non vues: $countNotSeen', style: ...labelSmall...),
          ],
        ),
      ]
      ```
    - Couleurs : `countARevoir` → `AppColors.error` (rouge), `countBien` → `AppColors.secondary` (teal), `countMaitrise` → `AppColors.primary` (vert), `countNotSeen` → `Colors.grey.shade300`
  - [ ] **IMPORTANT** : mettre à jour les appels à `ItemProgressBar` dans `college_detail_screen.dart` (tâche T13)

- [x] **T13 — Flutter : `CollegeDetailScreen` — global summary + drill-level display** (AC: #1)
  - [ ] Modifier `collega_app/lib/features/colleges/presentation/college_detail_screen.dart` :
    - Dans `_CollegeDetailBody.build`, remplacer le calcul `totalA/B/C` (rang counts) par un calcul drill-level :
      ```dart
      // NOUVEAU : calcul depuis les drill stats des items
      final totalMaitrise = filteredItems.fold(0, (s, i) => s + i.drillMaitrise);
      final totalBien = filteredItems.fold(0, (s, i) => s + i.drillBien);
      final totalARevoir = filteredItems.fold(0, (s, i) => s + i.drillARevoir);
      final totalNotSeen = filteredItems.fold(0, (s, i) => s + i.drillNotSeen);
      final totalCards = totalMaitrise + totalBien + totalARevoir + totalNotSeen;
      final masteryPct = totalCards == 0
          ? 0
          : ((totalMaitrise / totalCards) * 100).round();
      ```
    - Mettre à jour la `ProgressSummaryCard` pour afficher `'$masteryPct% maîtrisé'` :
      ```dart
      // Remplace le texte actuel '${totalA + totalB + totalC} fiches · Rang A: $totalA...'
      Text(
        '$masteryPct% maîtrisé · $totalCards fiches',
        style: AppTypography.bodyMedium(),
      ),
      ```
    - Mettre à jour `ItemProgressBar` dans `_ItemTile` :
      ```dart
      ItemProgressBar(
        countARevoir: item.drillARevoir,
        countBien: item.drillBien,
        countMaitrise: item.drillMaitrise,
        countNotSeen: item.drillNotSeen,
        showCounts: true,  // NOUVEAU — affiche chiffres exacts
      ),
      ```
    - Mettre à jour `ItemProgressBar` dans la ProgressSummaryCard (global summary) :
      ```dart
      ItemProgressBar(
        countARevoir: totalARevoir,
        countBien: totalBien,
        countMaitrise: totalMaitrise,
        countNotSeen: totalNotSeen,
      ),
      ```
    - Supprimer le texte `'${item.totalCards} fiches'` dans `_ItemTile` (redondant avec `showCounts: true`)
  - [ ] **IMPORTANT** : `filteredItems` est calculé **avant** cette modification — vérifier que la référence est à `loaded.filteredItems` et non `loaded.items`

- [x] **T14 — Flutter : `ProfileScreen` création** (AC: #3, #4, #5)
  - [ ] Créer `collega_app/lib/features/profile/presentation/profile_screen.dart`
  - [ ] `ProfileScreen` est un `ConsumerWidget`
  - [ ] Structure :
    ```dart
    Scaffold(
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.all(AppSpacing.screenMargin),
          children: [
            _IdentityCard(user: authState.user!),
            SizedBox(height: 16),
            _SubscriptionCard(user: authState.user!),
            SizedBox(height: 16),
            _NotifCard(...),         // toggle rappel + time picker
            SizedBox(height: 16),
            _AppCard(onLogout: ...),
          ],
        ),
      ),
    )
    ```
  - [ ] **`_IdentityCard`** :
    - Affiche l'email de l'utilisateur (`authState.user!.email`)
    - Badge beta si `user.isBeta`
  - [ ] **`_SubscriptionCard`** :
    - Badge "Actif" si `user.isSubscribed`, sinon "Inactif" (error color)
  - [ ] **`_NotifCard`** (ConsumerStatefulWidget pour état local du toggle + time picker) :
    ```dart
    class _NotifCard extends ConsumerStatefulWidget { ... }

    class _NotifCardState extends ConsumerState<_NotifCard> {
      bool _reminderEnabled = false;
      int _reminderHourUtc = 7; // défaut 7h UTC ≈ 9h Paris

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
          await svc.setReminder(hourUtc);
        } catch (e) {
          if (!mounted) return;
          setState(() => _reminderEnabled = false);
          ShadToaster.of(context).show(const ShadToast.destructive(
            title: Text('Impossible d'activer le rappel'),
          ));
        }
      }

      Future<void> _clearReminder() async {
        final svc = ref.read(notificationsServiceProvider);
        try {
          await svc.clearReminder();
        } catch (_) { /* silencieux */ }
      }

      @override
      Widget build(BuildContext context) {
        return ShadCard(
          child: Column(
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
                SizedBox(height: 8),
                Text('${_reminderHourUtc}h00 UTC', style: AppTypography.bodyMedium()),
              ],
            ],
          ),
        );
      }
    }
    ```
  - [ ] **`_AppCard`** :
    - Affiche la version de l'app (hardcodée `"1.0.0"` pour MVP)
    - Bouton "Se déconnecter" (error color + `Icons.logout`) → `ref.read(authProvider.notifier).logout()` → `context.go('/demo')`

- [x] **T15 — Flutter : `NotificationsService` — méthodes reminder** (AC: #3, #4)
  - [ ] Modifier `collega_app/lib/core/notifications/notifications_service.dart` :
    - Ajouter méthodes `setReminder(int hourUtc)` et `clearReminder()` :
      ```dart
      Future<void> setReminder(int hourUtc) async {
        try {
          await dio.post<void>(
            '/v1/notifications/reminder',
            data: {'hour_utc': hourUtc},
          );
          AppLogger.info('Rappel configuré à ${hourUtc}h UTC', tag: 'NotificationsService');
        } on DioException catch (e) {
          AppLogger.error('Échec setReminder', tag: 'NotificationsService', error: e);
          rethrow;
        }
      }

      Future<void> clearReminder() async {
        try {
          await dio.delete<void>('/v1/notifications/reminder');
          AppLogger.info('Rappel désactivé', tag: 'NotificationsService');
        } on DioException catch (e) {
          AppLogger.error('Échec clearReminder', tag: 'NotificationsService', error: e);
          rethrow;
        }
      }
      ```

- [x] **T16 — Flutter : Router — remplacer `_ProfileStub` par `ProfileScreen`** (AC: #5)
  - [ ] Modifier `collega_app/lib/core/router/app_router.dart` :
    - Ajouter import `profile_screen.dart`
    - Remplacer `GoRoute(path: '/profile', builder: (ctx, s) => const _ProfileStub())` par `GoRoute(path: '/profile', builder: (ctx, s) => const ProfileScreen())`
    - Supprimer la classe `_ProfileStub`

- [x] **T17 — Flutter : Tests** (AC: tous)
  - [ ] Créer `collega_app/test/features/colleges/drill_stats_test.dart` :
    - Test : `DrillStats.masteryPercent` = 0 si total == 0
    - Test : `DrillStats.masteryPercent` = 50 si maitrise=5, total=10
    - Test : `collegeDrillStatsProvider` émet `DrillStats` correct depuis cards Drift (mock db)
  - [ ] Créer `collega_app/test/features/colleges/college_progress_tile_test.dart` :
    - Test : `_ImportedTile` affiche la barre avec drill stats non-nulls
    - Test : `_ImportedTile` affiche barre grise complète si `total == 0`
  - [ ] Créer `collega_app/test/features/profile/profile_screen_test.dart` :
    - Test : `ProfileScreen` s'affiche avec email de l'utilisateur
    - Test : toggle rappel → affiche time picker (mock showTimePicker)
  - [ ] Modifier `collega_app/test/features/colleges/college_detail_test.dart` (s'il existe) :
    - Vérifier que `ItemProgressBar` utilise drill levels et non rang counts

- [x] **T18 — Validation finale** (AC: tous)
  - [ ] `cd collega_app && dart run build_runner build --delete-conflicting-outputs` (si tables Drift modifiées — ici NON, pas de changement de schéma Drift)
  - [ ] `cd collega_app && flutter analyze` → 0 nouvelle erreur
  - [ ] `cd collega_app && flutter test test/features/colleges/` → 0 régression
  - [ ] `cd collega_app && flutter test test/features/profile/` → tous verts
  - [ ] `cd collega_app && flutter test` (suite complète) → 0 nouvelle régression
  - [ ] `cd collega_backend && python -m pytest tests/api/test_reminder.py tests/workers/test_daily_reminder_worker.py -v` → tous verts

### Review Findings

- [x] [Review][Patch] APNs token non garanti avant setReminder — appeler `requestPermissionsAndRegister()` (ou équivalent) dans `_setReminder` avant `svc.setReminder(hourUtc)` pour garantir que le token est en base avant l'enregistrement du rappel. [`profile_screen.dart`]

- [x] [Review][Patch] `drillLevel` key inconsistency entre repository et stream provider — `getDrillStatsByItem` lit `counts['new']` ; `collegeDrillStatsProvider` utilise `default:` catch-all. Les valeurs inconnues sont perdues dans le repository (non comptées) mais ajoutées à `notSeen` dans le provider, créant des totaux divergents. Fix : ajouter `case 'new': notSeen++;` explicite dans le switch du provider et un `default: break;` explicite dans le repository. [`college_detail_repository.dart:63-88` / `colleges_providers.dart:43-54`]

- [x] [Review][Patch] `getDrillStatsByItem` appelé hors du bloc try/catch — si Drift lève une exception après le fallback offline, le provider crashe avec une erreur non typée. Fix : englober l'appel et le mapping dans un try/catch avec fallback sur `CollegeDetailLoaded(items: items)`. [`colleges_detail_providers.dart:26-64`]

- [x] [Review][Patch] `_bmad*` supprimé du .gitignore — les répertoires `_bmad/` et `_bmad-output/` (artefacts de planification AI non-tracés) sont désormais exposés à git. Fix : restaurer la ligne `_bmad*` dans `.gitignore`. [`.gitignore:1`]

- [x] [Review][Patch] Rate limiting manquant sur `POST/DELETE /v1/notifications/reminder` — les autres endpoints sensibles ont `@limiter.limit(...)`. Un attaquant authentifié peut spammer ces routes. Fix : ajouter `@limiter.limit("10/minute")` sur les deux endpoints. [`notifications.py:47-65`]

- [x] [Review][Patch] `ItemProgressBar` — `MainAxisAlignment.spaceBetween` avec enfants conditionnels — quand un seul bucket est non-nul, le `Row` n'a qu'un `Text` qui reste collé à gauche. Fix : remplacer par `MainAxisAlignment.start` avec `SizedBox` de séparation fixe, ou utiliser `Wrap`. [`item_progress_bar.dart:69-89`]

- [x] [Review][Patch] `_clearReminder` avale silencieusement les erreurs réseau — en cas d'échec du DELETE, le toggle affiche OFF visuellement mais le rappel reste actif côté backend. Fix : ajouter `setState(() => _reminderEnabled = true)` dans le catch, à l'instar de `_setReminder`. [`profile_screen.dart`]

- [x] [Review][Patch] `_toggleReminder` état optimiste sans rollback si widget disposé — `setState(() => _reminderEnabled = value)` est appelé avant le time picker et le réseau ; si le widget est disposé pendant l'attente, `_reminderEnabled` reste `true` sans rappel actif. Fix : vérifier `mounted` avant chaque `setState` dans `_showTimePicker` et réinitialiser `_reminderEnabled = false` si non mounted. [`profile_screen.dart`]

- [x] [Review][Defer] Clock skew ARQ à la frontière d'heure — `datetime.now(timezone.utc).hour` au moment du cron ; décalage de quelques secondes peut faire rater ou doubler la notification. Limitation ARQ pré-existante sans déduplication guard. [`daily_reminder_worker.py:15`] — deferred, pre-existing

- [x] [Review][Defer] `getDrillStatsByItem` charge toutes les flashcards en mémoire — performance concern pour grands collèges, pas de pagination. Acceptable MVP. [`college_detail_repository.dart:63-88`] — deferred, pre-existing

---

## Dev Notes

### Structure des fichiers

```
collega_app/lib/
├── core/
│   ├── notifications/
│   │   └── notifications_service.dart        # MODIFIER — T15 (setReminder, clearReminder)
│   └── router/
│       └── app_router.dart                   # MODIFIER — T16 (ProfileScreen)
├── features/
│   ├── colleges/
│   │   ├── colleges_providers.dart           # MODIFIER — T7 (collegeDrillStatsProvider)
│   │   ├── colleges_detail_providers.dart    # MODIFIER — T11 (drill overlay)
│   │   ├── domain/
│   │   │   ├── college_detail_models.dart    # MODIFIER — T9 (drill counts sur ItemModel)
│   │   │   └── drill_stats.dart             # CRÉER — T7
│   │   ├── data/
│   │   │   └── college_detail_repository.dart # MODIFIER — T10 (getDrillStatsByItem)
│   │   ├── presentation/
│   │   │   ├── college_detail_screen.dart   # MODIFIER — T13 (global summary + drill display)
│   │   │   └── widgets/
│   │   │       └── item_progress_bar.dart   # MODIFIER — T12 (drill levels + counts)
│   │   └── widgets/
│   │       └── college_progress_tile.dart   # MODIFIER — T8 (Drift StreamProvider)
│   └── profile/
│       └── presentation/
│           └── profile_screen.dart          # CRÉER — T14

collega_backend/
├── alembic/versions/
│   └── 009_add_reminder_hour_utc_to_users.py  # CRÉER — T1
├── app/
│   ├── models/
│   │   └── user.py                           # MODIFIER — T1
│   ├── api/v1/
│   │   └── notifications.py                  # MODIFIER — T5
│   ├── services/notifications/
│   │   └── apns_service.py                   # MODIFIER — T3
│   └── workers/
│       ├── daily_reminder_worker.py          # CRÉER — T2
│       └── settings.py                       # MODIFIER — T4
└── tests/
    ├── api/
    │   └── test_reminder.py                  # CRÉER — T6
    └── workers/
        └── test_daily_reminder_worker.py     # CRÉER — T6

collega_app/test/features/
├── colleges/
│   ├── drill_stats_test.dart                 # CRÉER — T17
│   └── college_progress_tile_test.dart       # CRÉER — T17
└── profile/
    └── profile_screen_test.dart              # CRÉER — T17
```

### Drift `flashCards.drillLevel` — valeurs attendues

- `'new'` = jamais révisée (valeur par défaut — T9 Story 4.4)
- `'a_revoir'` = évaluée mais pas encore maîtrisée
- `'bien'` = bonne maîtrise
- `'maitrise'` = maîtrise complète

Le champ `drillLevel` est mis à jour dans `DrillRepository.updateCardDrillLevel` après chaque évaluation. La valeur par défaut `'new'` est `drillLevel: 'new'` (Stories 4.1-4.4).

### Drift `StreamProvider.family` — réactivité temps réel

`collegeDrillStatsProvider` utilise Drift `.watch()` qui retourne un `Stream<List<FlashCard>>`. Chaque écriture en DB (après drill) déclenche automatiquement une nouvelle émission. Pas besoin d'invalidation manuelle.

```dart
// Pattern correct (T7) — .watch() = reactive
(db.select(db.flashCards)..where(...)).watch().map(...)

// ANTI-PATTERN — .get() = one-shot, pas réactif
(db.select(db.flashCards)..where(...)).get()
```

### `CollegeProgressTile` — conversion en ConsumerWidget partiel

Seul `_ImportedTile` devient `ConsumerWidget`. `CollegeProgressTile` lui-même reste `StatelessWidget`. Pattern identique à `_DrillEndScreen` dans Story 4.4 (widget parent inchangé, widget enfant privé converti).

Call-sites dans `colleges_screen.dart` : `CollegeProgressTile(entry: ..., onTap: ...)` — aucun changement.

### `ItemProgressBar` — mise à jour des call-sites

Le widget est UNIQUEMENT appelé depuis `college_detail_screen.dart` (2 endroits). Aucun autre call-site identifié dans le codebase. Les paramètres `countA/B/C` doivent être remplacés par `countARevoir/countBien/countMaitrise`.

Vérifier avec `grep -r "ItemProgressBar" lib/` avant modification pour confirmer.

### Backend — `AsyncSessionFactory`

Le worker daily_reminder a besoin d'une `AsyncSession` en dehors du contexte FastAPI. Dans `database.py`, vérifier s'il existe déjà un `async_sessionmaker`. Pattern des workers existants (`generation_worker.py`, `ocr_worker.py`) pour référence :

```python
# Pattern à suivre (checker dans generation_worker.py)
async with async_session() as db:
    # queries
```

Si `AsyncSessionFactory` n'existe pas encore dans `database.py`, l'ajouter :
```python
from sqlalchemy.ext.asyncio import async_sessionmaker
AsyncSessionFactory = async_sessionmaker(engine, expire_on_commit=False)
```

### Backend — `models/__init__.py` doit importer User

Règle établie (deferred Story 1.1) : chaque nouveau modèle doit être importé dans `app/models/__init__.py`. Vérifier que `User` y est bien présent. Si la migration Alembic échoue avec "Table users not found", c'est souvent la cause.

### `NotifCard` — ShadSwitch vs ShadCheckbox

Utiliser `ShadSwitch` (toggle iOS-style) plutôt que `ShadCheckbox`. Vérifier que `ShadSwitch` est disponible dans `shadcn_ui: ^0.19.0`. Si absent, utiliser `Switch` Material (Flutter natif) avec le style thème.

### `ProfileScreen` — état du toggle rappel au démarrage

Pour MVP : le toggle est initialisé à `false` au démarrage (`_reminderEnabled = false`). L'état persistant du rappel n'est pas chargé depuis le backend au démarrage (pas d'endpoint GET pour l'état du reminder). C'est acceptable pour ce MVP — l'utilisateur doit reconfigurer le rappel si il réinstalle l'app.

Un endpoint `GET /v1/notifications/reminder` pour charger l'état persistant est une amélioration future (hors scope de cette story).

### `_AppCard` — Logout flow

Après `ref.read(authProvider.notifier).logout()`, le router redirige automatiquement vers `/demo` via le guard GoRouter (l'état `isAuthenticated` passe à `false`). Pas besoin d'appeler `context.go('/demo')` manuellement — le router le fait. Mais ajouter un guard `if (!mounted) return` après l'appel async.

### Alembic — Migration pattern

Pattern à suivre (voir migrations 007 et 008 pour référence) :
```python
def upgrade() -> None:
    op.add_column("users", sa.Column("reminder_hour_utc", sa.Integer(), nullable=True))

def downgrade() -> None:
    op.drop_column("users", "reminder_hour_utc")
```

Ne pas oublier le `revision` et `down_revision` dans le fichier de migration.

### Anti-patterns à éviter

- **NE PAS** créer un provider séparé pour l'état du toggle rappel — `_NotifCardState` local suffit pour ce MVP
- **NE PAS** utiliser `ref.read` dans `build()` pour `collegeDrillStatsProvider` — utiliser `ref.watch` pour la réactivité
- **NE PAS** supprimer `cardCountA/B/C` de `ItemModel` — ils sont toujours utilisés pour le filtrage par rang
- **NE PAS** ajouter `dart run build_runner build` dans T18 si aucune table Drift n'a changé (pas de schéma v6 dans cette story)
- **NE PAS** appeler `ref.invalidate(collegeDetailProvider)` depuis `CollegeProgressTile` — les deux providers sont indépendants
- **NE PAS** utiliser `print()` ou `debugPrint()` — utiliser `AppLogger`
- **NE PAS** modifier les autres onglets (search = stub reste acceptable)

### État du codebase au début de cette story

| Composant | État | Chemin |
|---|---|---|
| `features/profile/` | 🚫 Dossier vide | `lib/features/profile/` |
| `_ProfileStub` | ✅ Stub actif | `core/router/app_router.dart` |
| `ItemProgressBar` | ✅ Existe (paramètres à renommer) | `presentation/widgets/item_progress_bar.dart` |
| `CollegeProgressTile._ImportedTile` | ✅ Existe — StatelessWidget | `widgets/college_progress_tile.dart` |
| `collegeDrillStatsProvider` | 🚫 Absent | à créer — T7 |
| `DrillStats` model | 🚫 Absent | à créer — T7 |
| `ItemModel.drillMaitrise` etc. | 🚫 Absent | à ajouter — T9 |
| `getDrillStatsByItem` | 🚫 Absent | à créer — T10 |
| `NotificationsService.setReminder` | 🚫 Absent | à ajouter — T15 |
| `users.reminder_hour_utc` (DB) | 🚫 Absent | à créer — T1 |
| `send_daily_reminders` worker | 🚫 Absent | à créer — T2 |
| `POST /v1/notifications/reminder` | 🚫 Absent | à créer — T5 |

### Intelligence git (patterns établis)

- `ConsumerWidget` ou `ConsumerStatefulWidget` pour état local + Riverpod simultanés
- `StreamProvider.family` pour données réactives depuis Drift `.watch()`
- `AsyncNotifier<T>` pour état async, `Provider<T>` pour dépendances sans état
- `unawaited(...)` pour fire-and-forget (ne pas changer dans `CollegeDetailNotifier`)
- `if (!mounted) return` dans tous les callbacks async `State`/`ConsumerState`
- `AppLogger.info/warning/error` — jamais `print()` ou `debugPrint()`
- Pattern test : `AppDatabase.forTesting(NativeDatabase.memory())` + `addTearDown(db.close)`
- `flutter analyze` → 0 erreur avant marquage done

### Références

- Epic 4, Story 4.5 spec : `_bmad-output/planning-artifacts/epics.md` L.900–927
- UX Détail collège : `_bmad-output/planning-artifacts/ux-design-specification.md` L.842–861
- UX Profil : `_bmad-output/planning-artifacts/ux-design-specification.md` L.935–953
- Architecture push notifications : `_bmad-output/planning-artifacts/architecture.md` L.150–152
- `CollegeProgressTile` existant : `collega_app/lib/features/colleges/widgets/college_progress_tile.dart`
- `ItemProgressBar` existant : `collega_app/lib/features/colleges/presentation/widgets/item_progress_bar.dart`
- `CollegeDetailScreen` (à modifier) : `collega_app/lib/features/colleges/presentation/college_detail_screen.dart`
- `CollegeDetailNotifier` (à modifier) : `collega_app/lib/features/colleges/colleges_detail_providers.dart`
- `NotificationsService` (à modifier) : `collega_app/lib/core/notifications/notifications_service.dart`
- `APNsNotificationService` (à modifier) : `collega_backend/app/services/notifications/apns_service.dart`
- `workers/settings.py` (à modifier) : `collega_backend/app/workers/settings.py`
- Modèle User (à modifier) : `collega_backend/app/models/user.py`
- `notifications.py` router (à modifier) : `collega_backend/app/api/v1/notifications.py`
- Deferred D15 (homeProvider au retour drill) : `_bmad-output/implementation-artifacts/deferred-work.md` L.25`
- Pattern existing workers : `collega_backend/app/workers/generation_worker.py`

---

## Dev Agent Record

### Agent Model Used

claude-sonnet-4-6

### Debug Log References

- T17 `college_progress_tile_test.dart` : timer pending avec Drift StreamProvider — corrigé en overridant `collegeDrillStatsProvider` avec `Stream.value(...)` dans les tests widget

### Completion Notes List

- **T1–T6 (Backend)** : Migration Alembic #009 (`reminder_hour_utc`), worker `send_daily_reminders`, méthode `send_daily_reminder` dans APNsService + NullService, cron registré dans `settings.py`, endpoints `POST/DELETE /v1/notifications/reminder`, 9 tests backend (tous verts)
- **T7–T8 (Drift StreamProvider)** : `DrillStats` model créé, `collegeDrillStatsProvider` StreamProvider.family ajouté dans `colleges_providers.dart`, `_ImportedTile` converti en ConsumerWidget avec watch réactif
- **T9–T11 (ItemModel overlay)** : `ItemModel` enrichi avec `drillMaitrise/Bien/ARevoir/NotSeen`, `getDrillStatsByItem()` ajouté dans `CollegeDetailRepository`, overlay appliqué dans `CollegeDetailNotifier.build()`
- **T12–T13 (UI)** : `ItemProgressBar` revu (paramètres drill + `showCounts`), `CollegeDetailScreen` met à jour le résumé global (`masteryPct%`) et les items (`showCounts: true`)
- **T14–T16 (ProfileScreen)** : `ProfileScreen` créé (IdentityCard, SubscriptionCard, NotifCard avec ShadSwitch + TimePicker, AppCard + logout), `NotificationsService.setReminder/clearReminder` ajoutés, `_ProfileStub` remplacé dans le router
- **T17–T18 (Tests)** : 13 nouveaux tests Flutter (drill_stats 5/5, college_progress_tile 3/3, profile_screen 5/5), 0 régression dans les suites existantes

### File List

**Backend — nouveaux fichiers :**
- `collega_backend/alembic/versions/009_add_reminder_hour_utc_to_users.py`
- `collega_backend/app/workers/daily_reminder_worker.py`
- `collega_backend/tests/api/test_reminder.py`
- `collega_backend/tests/workers/test_daily_reminder_worker.py`

**Backend — fichiers modifiés :**
- `collega_backend/app/models/user.py`
- `collega_backend/app/services/notifications/apns_service.py`
- `collega_backend/app/workers/settings.py`
- `collega_backend/app/api/v1/notifications.py`

**Flutter — nouveaux fichiers :**
- `collega_app/lib/features/colleges/domain/drill_stats.dart`
- `collega_app/lib/features/profile/presentation/profile_screen.dart`
- `collega_app/test/features/colleges/drill_stats_test.dart`
- `collega_app/test/features/colleges/college_progress_tile_test.dart`
- `collega_app/test/features/profile/profile_screen_test.dart`

**Flutter — fichiers modifiés :**
- `collega_app/lib/features/colleges/colleges_providers.dart`
- `collega_app/lib/features/colleges/domain/college_detail_models.dart`
- `collega_app/lib/features/colleges/data/college_detail_repository.dart`
- `collega_app/lib/features/colleges/colleges_detail_providers.dart`
- `collega_app/lib/features/colleges/widgets/college_progress_tile.dart`
- `collega_app/lib/features/colleges/presentation/widgets/item_progress_bar.dart`
- `collega_app/lib/features/colleges/presentation/college_detail_screen.dart`
- `collega_app/lib/core/notifications/notifications_service.dart`
- `collega_app/lib/core/router/app_router.dart`

## Change Log

- 2026-05-16 — Story 4.5 créée par create-story. Analyse exhaustive : Story 4.4 (patterns Drift, DrillStats, PlanningNotifier, CollegeProgressTile), codebase (NotificationsService, APNsService, CollegeDetailRepository, ItemProgressBar, College detail screen, Router stub), epics FR34–35, UX Profil + Détail collège, architecture push notifications. Statut → ready-for-dev.
- 2026-05-16 — Implémentation complète T1–T18. Backend : migration Alembic, worker cron, endpoints reminder, 9 tests. Flutter : DrillStats model, collegeDrillStatsProvider (Drift reactive), CollegeProgressTile ConsumerWidget, ItemModel drill overlay, ItemProgressBar redesign, CollegeDetailScreen summary drill, ProfileScreen (NotifCard + ShadSwitch), router stub remplacé. 13 nouveaux tests Flutter, 0 régression. Statut → review.
