# Story 3.5 : Feedback Fiches, Régénération & Notification Push

Status: done

## Story

En tant qu'**étudiant**,
je veux pouvoir signaler une fiche comme non pertinente, la régénérer avec mon feedback ou la supprimer, et être notifié quand mes fiches sont prêtes,
afin d'améliorer la qualité de mes fiches et savoir sans ouvrir l'app quand elles sont disponibles.

## Acceptance Criteria

1. **Feedback négatif (pouce bas) — AC1 (FR19)**
   - Étant donné une fiche affichée
   - Quand je tape sur le pouce bas (icône `Icons.thumb_down_outlined`)
   - Alors un `ShadDialog.alert` s'affiche avec deux options : "Régénérer avec mon feedback" (primary) et "Supprimer la fiche" (destructive)

2. **Régénération avec feedback — AC2 (FR20)**
   - Étant donné que je choisis "Régénérer"
   - Quand je saisis mon feedback (champ texte optionnel) et confirme
   - Alors une requête est envoyée au backend `POST /v1/flash-cards/{card_id}/regenerate` avec `{"user_note": "..."}`
   - Et le backend appelle Claude **de façon synchrone** pour régénérer uniquement cette fiche (pas d'ARQ — design decision justifiée dans Dev Notes)
   - Et la nouvelle fiche est retournée dans la réponse HTTP
   - Et la fiche est remplacée dans Drift local sans recharger l'écran
   - Et le `OcrConfidenceBadge` disparaît si le nouveau `ocr_confidence_score` >= 0.7

3. **Suppression fiche — AC3 (FR21)**
   - Étant donné que je choisis "Supprimer"
   - Quand je confirme la suppression
   - Alors `DELETE /v1/flash-cards/{card_id}` est appelé
   - Et la fiche est supprimée de Drift local (`db.delete(db.flashCards).where(t.id.equals(cardId))`)
   - Et les compteurs de l'item (cardCountA/B/C) sont mis à jour dans le `CollegeDetailNotifier`

4. **Feedback positif (pouce haut) — AC4 (FR19)**
   - Étant donné une fiche affichée
   - Quand je tape sur le pouce haut (`Icons.thumb_up_outlined`)
   - Alors `POST /v1/flash-cards/{card_id}/feedback` est appelé avec `{"feedback": "positive"}`
   - Et un `ShadToast` vert s'affiche : "Fiche signalée comme pertinente"
   - Et aucune autre action n'est requise

5. **Notification push en fin de génération — AC5 (FR23)**
   - Étant donné la fin de génération d'un collège
   - Quand le `generation_worker` ARQ termine avec `generation_complete`
   - Alors une notification push APNs est envoyée au device de l'utilisateur via `aioapns`
   - Et le payload inclut `college_ref_id` pour le deep linking
   - Et un tap sur la notification ouvre directement l'écran `/colleges/{college_ref_id}`
   - Et si l'`apns_token` de l'utilisateur est absent ou si APNs n'est pas configuré, la génération réussit quand même (notification silencieuse)

---

## Tasks / Subtasks

- [x] **T1 — Backend : migration Alembic #008** (AC: #1, #4)
  - [x] Créer `collega_backend/alembic/versions/008_add_user_feedback_to_flash_cards.py`
  - [x] `ALTER TABLE flash_cards ADD COLUMN user_feedback VARCHAR(20) NULL CHECK (user_feedback IN ('positive', 'negative'))`
  - [x] Mettre à jour `collega_backend/app/models/flash_card.py` : ajouter `user_feedback: Mapped[str | None]` avec `CheckConstraint`

- [x] **T2 — Backend : `apns_service.py`** (AC: #5)
  - [x] Créer `collega_backend/app/services/notifications/apns_service.py`
  - [x] Classe abstraite `NotificationService` avec méthode `send_generation_complete(apns_token, college_ref_id) -> None`
  - [x] Classe `APNsNotificationService` utilisant `aioapns` (token-based auth avec `.p8` key)
  - [x] Classe `NullNotificationService` (fallback silencieux quand APNs non configuré)
  - [x] Fonction `get_notification_service() -> NotificationService` : retourne `APNsNotificationService` si config complète, `NullNotificationService` sinon

- [x] **T3 — Backend : config APNs** (AC: #5)
  - [x] Dans `collega_backend/app/core/config.py`, ajouter (valeurs vides par défaut, aucun `model_validator` obligatoire) :
    - `apns_key_path: str = ""`
    - `apns_key_id: str = ""`
    - `apns_team_id: str = ""`
    - `apns_bundle_id: str = "com.lesurmatthis.collega"`
    - `apns_use_sandbox: bool = True`

- [x] **T4 — Backend : nouveaux schémas Pydantic** (AC: #1–5)
  - [x] Dans `collega_backend/app/schemas/college.py`, ajouter :
    - `FlashCardFeedbackRequest(feedback: Literal['positive', 'negative'])`
    - `FlashCardRegenerateRequest(user_note: str | None = None)`
    - `FlashCardResponseWrapped(data: FlashCardData)` — retourne la fiche régénérée

- [x] **T5 — Backend : `flash_cards.py` router** (AC: #1–4)
  - [x] Créer `collega_backend/app/api/v1/flash_cards.py`
  - [x] `POST /v1/flash-cards/{card_id}/feedback` → enregistre `user_feedback` sur la fiche, retourne `{"data": {"id": ..., "feedback": ...}}`
  - [x] `DELETE /v1/flash-cards/{card_id}` → supprime la fiche (scoping user_id), retourne 204
  - [x] `POST /v1/flash-cards/{card_id}/regenerate` → appel Claude synchrone sur la fiche avec `user_note` en contexte, remplace la fiche en DB, retourne la nouvelle `FlashCardData`
  - [x] Tous les endpoints : `require_subscription` + vérification `card.user_id == current_user.id` → 404 sinon
  - [x] Ajouter `ClaudeClient.regenerate_single_card(card, item, user_note)` dans `claude_client.py`

- [x] **T6 — Backend : notification push dans `generation_worker.py`** (AC: #5)
  - [x] Après `card_generator.generate_for_college()` avec succès
  - [x] Charger `user.apns_token` via `db.get(User, job.user_id)`
  - [x] Appeler `get_notification_service().send_generation_complete(user.apns_token, college.college_ref_id)` en `try/except` — une erreur APNs ne fait PAS échouer le job
  - [x] **NE PAS** modifier `card_generator.py` — la notification appartient au worker

- [x] **T7 — Backend : enregistrer `flash_cards_router` et `notifications_router` dans `main.py`** (AC: tous)
  - [x] `notifications_router` → `POST /v1/notifications/apns-token` (enregistre le token APNs de l'utilisateur courant)
  - [x] Créer `collega_backend/app/api/v1/notifications.py`
  - [x] Ajouter les deux routers dans `app/main.py`

- [x] **T8 — Backend : tests** (AC: #1–5)
  - [x] Créer `collega_backend/tests/api/test_flash_cards.py`
  - [x] `POST /v1/flash-cards/{id}/feedback` : 200 ok, 404 si card non trouvée, 404 si card appartient à autre user
  - [x] `DELETE /v1/flash-cards/{id}` : 204, 404 si non trouvée
  - [x] `POST /v1/flash-cards/{id}/regenerate` : mock `ClaudeClient.regenerate_single_card` → retourne FlashCardData
  - [x] `POST /v1/notifications/apns-token` : met à jour `user.apns_token`

- [x] **T9 — Flutter : ajouter `flutter_apns_only`** (AC: #5)
  - [x] Dans `pubspec.yaml`, ajouter `flutter_apns_only: ^1.0.0` (vérifier la dernière version sur pub.dev)
  - [x] Activer les capabilities push notifications dans Xcode (cible `Runner` → Signing & Capabilities → Push Notifications)

- [x] **T10 — Flutter : `NotificationsService`** (AC: #5)
  - [x] Créer `collega_app/lib/core/notifications/notifications_service.dart`
  - [x] Méthode `requestPermissionsAndRegister(Dio dio)` :
    1. `await apnsConnector.requestNotificationPermissions()`
    2. Écouter `apnsConnector.token.addListener(...)` → `POST /v1/notifications/apns-token`
  - [x] Configurer les callbacks `onLaunch`, `onResume`, `onMessage` pour lire `college_ref_id` et naviguer via GoRouter
  - [x] `notificationsServiceProvider` (Riverpod `Provider`)

- [x] **T11 — Flutter : Drift table `FlashCards` — ajout `userFeedback`** (AC: #1, #4)
  - [x] Dans `collega_app/lib/core/database/tables/flash_cards_table.dart`, ajouter :
    `TextColumn get userFeedback => text().nullable()();`
  - [x] Dans `collega_app/lib/core/database/app_database.dart` :
    - Bumper `schemaVersion` à `3`
    - Ajouter dans `onUpgrade` : `if (from < 3) { await m.addColumn(flashCards, flashCards.userFeedback); }`
  - [x] Régénérer `app_database.g.dart` : `dart run build_runner build --delete-conflicting-outputs`

- [x] **T12 — Flutter : `FlashCardModel` — ajout `userFeedback`** (AC: #1, #4)
  - [x] Dans `collega_app/lib/features/colleges/domain/college_detail_models.dart`
  - [x] Ajouter `final String? userFeedback;` à `FlashCardModel`
  - [x] Mettre à jour `fromJson` : `userFeedback: json['user_feedback'] as String?`
  - [x] Mettre à jour `getCardsFromDrift` dans `CollegeDetailRepository` : `userFeedback: r.userFeedback`
  - [x] Mettre à jour `syncCardsToDrift` : `userFeedback: Value(c.userFeedback)`

- [x] **T13 — Flutter : méthodes feedback/delete/régénération dans `CollegeDetailRepository`** (AC: #1–4)
  - [x] `submitPositiveFeedback(String cardId)` → `POST /v1/flash-cards/{cardId}/feedback {"feedback":"positive"}`
  - [x] `deleteCard(String cardId)` → `DELETE /v1/flash-cards/{cardId}` + `db.delete(db.flashCards).where(t.id.equals(cardId))`
  - [x] `regenerateCard(String cardId, {String? userNote})` → `POST /v1/flash-cards/{cardId}/regenerate {"user_note":userNote}` → parse `FlashCardData`, `syncCardsToDrift([newCard])`

- [x] **T14 — Flutter : méthodes notifier dans `ItemDetailNotifier`** (AC: #1–4)
  - [x] Dans `collega_app/lib/features/colleges/colleges_detail_providers.dart`
  - [x] `submitPositiveFeedback(String cardId)` : appelle repo, met à jour la card dans `state` (userFeedback='positive')
  - [x] `deleteCard(String cardId)` : appelle repo, retire la card de `state`, invalide `collegeDetailProvider` pour refresh des counts
  - [x] `regenerateCard(String cardId, {String? userNote})` : appelle repo, remplace la card dans `state`

- [x] **T15 — Flutter : UI feedback dans `ItemDetailScreen`** (AC: #1–4)
  - [x] Dans `collega_app/lib/features/colleges/presentation/item_detail_screen.dart`
  - [x] Dans chaque `ShadAccordionItem`, ajouter après le texte `verso` une `Row` avec deux `IconButton` : pouce haut + pouce bas
  - [x] Pouce haut : `_handlePositiveFeedback(cardId)` → appelle notifier + `ShadToaster.of(context).show(ShadToast(title: Text('Fiche signalée comme pertinente'), ...))`
  - [x] Pouce bas : `_handleNegativeFeedback(card)` → affiche `ShadDialog.alert` avec deux options
  - [x] Dialog "Régénérer" : champ texte optionnel `ShadInput` + bouton Confirmer → `_regenerateCard(cardId, userNote)`
  - [x] Dialog "Supprimer" : bouton destructive rouge → `_deleteCard(cardId)`
  - [x] Convertir `_ItemDetailBody` en `ConsumerStatefulWidget` pour gérer les états de chargement per-card

- [x] **T16 — Flutter : initialisation notifications après login** (AC: #5)
  - [x] Dans `collega_app/lib/app.dart` via `ref.listen(authProvider, ...)`
  - [x] Après authentication réussie (`authProvider` → `isAuthenticated = true`), appeler `NotificationsService.requestPermissionsAndRegister()`
  - [x] Deep link depuis notification : GoRouter navigate to `/colleges/{college_ref_id}`

- [x] **T17 — Flutter : tests** (AC: #1–4)
  - [x] Créer `collega_app/test/features/colleges/flash_card_feedback_test.dart`
  - [x] `submitPositiveFeedback` appelle le bon endpoint et met à jour state
  - [x] `deleteCard` retire la card de la liste
  - [x] `regenerateCard` remplace la card par la nouvelle
  - [x] `FlashCardModel.fromJson` parse `user_feedback` correctement

- [x] **T18 — Validation finale** (AC: tous)
  - [x] `flutter analyze` → 0 erreur (2 infos pré-existantes de lint Riverpod)
  - [x] `flutter test` → 55 tests passent, 0 régression
  - [x] `pytest collega_backend/tests/api/test_flash_cards.py` → 7 tests verts
  - [x] `pytest collega_backend/tests/api/` → 34 tests, 0 nouvelle régression

---

## Dev Notes

### Décision architecturale : régénération synchrone (pas ARQ)

L'AC épique dit "un job ARQ est créé". **Cette story implémente la régénération de façon synchrone** (réponse HTTP directe) pour les raisons suivantes :
- Une seule fiche = appel Claude ~2-5 secondes → acceptable en HTTP
- L'utilisateur attend le résultat pour voir la nouvelle fiche
- Évite la complexité SSE/polling pour connaître l'état du job
- L'ARQ n'est justifié que pour les traitements multi-minutes (génération complète d'un collège)

### État du codebase au début de cette story

**DÉJÀ IMPLÉMENTÉ — NE PAS RECRÉER :**

| Composant | État | Emplacement |
|---|---|---|
| `FlashCard` SQLAlchemy model | ✅ Existe — id, item_id, college_id, user_id, card_type, rang, recto, verso, ocr_confidence_score, low_confidence | `collega_backend/app/models/flash_card.py` |
| `User.apns_token: str \| None` | ✅ Existe, nullable | `collega_backend/app/models/user.py` |
| `ClaudeClient` + `GENERATION_PROMPT` | ✅ Existe — model `claude-sonnet-4-6`, génère JSON flashcards | `collega_backend/app/services/generation/claude_client.py` |
| `CardGenerator.generate_for_college()` | ✅ Existe | `collega_backend/app/services/generation/card_generator.py` |
| `generation_worker.generate_college_cards()` | ✅ Existe — ARQ function | `collega_backend/app/workers/generation_worker.py` |
| Schemas Pydantic college | ✅ Existe — `FlashCardData`, `CardsListResponseWrapped`, etc. | `collega_backend/app/schemas/college.py` |
| `aioapns = ">=3.0.0"` | ✅ Dans `pyproject.toml` — déjà installé | `collega_backend/pyproject.toml` |
| `require_subscription`, `get_current_user` | ✅ Existe | `collega_backend/app/deps.py` |
| `FlashCards` Drift table | ✅ Existe — version 2, sans `user_feedback` | `collega_app/lib/core/database/tables/flash_cards_table.dart` |
| `AppDatabase` schemaVersion 2 | ✅ Existe | `collega_app/lib/core/database/app_database.dart` |
| `FlashCardModel` | ✅ Existe — sans `userFeedback` | `collega_app/lib/features/colleges/domain/college_detail_models.dart` |
| `CollegeDetailRepository` | ✅ Existe — getCards, syncCardsToDrift, getCardsFromDrift | `collega_app/lib/features/colleges/data/college_detail_repository.dart` |
| `ItemDetailNotifier` | ✅ Existe — `AsyncNotifierProvider.family`, build charge les cards | `collega_app/lib/features/colleges/colleges_detail_providers.dart` |
| `ItemDetailScreen` + accordion | ✅ Existe — affiche recto/verso + OcrConfidenceBadge | `collega_app/lib/features/colleges/presentation/item_detail_screen.dart` |
| `_ItemDetailBody` | ✅ `StatefulWidget` avec `TabController` — PAS encore `ConsumerStatefulWidget` | `collega_app/lib/features/colleges/presentation/item_detail_screen.dart:90` |
| `shadcn_ui: ^0.19.0` | ✅ `ShadDialog.alert`, `ShadToast`, `ShadInput` disponibles | `pubspec.yaml` |

**CE QUI MANQUE (à implémenter dans cette story) :**
- `user_feedback` colonne sur `flash_cards` (migration #008 + modèle SQLAlchemy)
- `flash_cards.py` router (3 endpoints)
- `notifications.py` router (1 endpoint)
- `apns_service.py` (service notifications)
- APNs config dans `config.py`
- `ClaudeClient.regenerate_single_card()` méthode
- Push notification dans `generation_worker.py`
- `flutter_apns_only` dans `pubspec.yaml`
- `notifications_service.dart`
- `userFeedback` sur `FlashCards` Drift table + migration schemaVersion 3
- Méthodes feedback/delete/regenerate dans `CollegeDetailRepository`
- Méthodes notifier dans `ItemDetailNotifier`
- UI feedback (pouces) dans `ItemDetailScreen`

---

### Backend : Migration Alembic #008

```python
# collega_backend/alembic/versions/008_add_user_feedback_to_flash_cards.py
"""Add user_feedback to flash_cards

Revision ID: 008
Revises: 007
Create Date: 2026-05-12
"""
from alembic import op
import sqlalchemy as sa

revision = '008'
down_revision = '007'

def upgrade() -> None:
    op.add_column(
        'flash_cards',
        sa.Column(
            'user_feedback',
            sa.String(20),
            nullable=True,
        )
    )
    op.create_check_constraint(
        'ck_flash_cards_user_feedback',
        'flash_cards',
        "user_feedback IN ('positive', 'negative')",
    )

def downgrade() -> None:
    op.drop_constraint('ck_flash_cards_user_feedback', 'flash_cards', type_='check')
    op.drop_column('flash_cards', 'user_feedback')
```

**Vérifier le `down_revision`** : doit correspondre au `revision` ID exact de `007_add_monthly_reloads_reset_at.py`.

---

### Backend : Modèle FlashCard mis à jour

```python
# Dans collega_backend/app/models/flash_card.py — AJOUTER dans __table_args__
CheckConstraint(
    "user_feedback IN ('positive', 'negative')",
    name="ck_flash_cards_user_feedback"
),

# AJOUTER le champ après low_confidence
user_feedback: Mapped[str | None] = mapped_column(
    String(20),
    nullable=True,
)
```

---

### Backend : Config APNs

```python
# Dans collega_backend/app/core/config.py — AJOUTER dans la classe Settings
# APNs — token-based auth (fichier .p8 Apple Developer)
apns_key_path: str = ""       # chemin absolu vers le fichier .p8
apns_key_id: str = ""         # Key ID (10 chars)
apns_team_id: str = ""        # Team ID Apple Developer (10 chars)
apns_bundle_id: str = "com.lesurmatthis.collega"
apns_use_sandbox: bool = True  # False en production
```

**PAS de `model_validator` obligatoire** — si les champs sont vides, `NullNotificationService` est utilisé.

---

### Backend : `apns_service.py`

```python
# collega_backend/app/services/notifications/apns_service.py
from __future__ import annotations

import logging
from abc import ABC, abstractmethod

logger = logging.getLogger(__name__)


class NotificationService(ABC):
    @abstractmethod
    async def send_generation_complete(
        self, apns_token: str | None, college_ref_id: int
    ) -> None: ...


class NullNotificationService(NotificationService):
    async def send_generation_complete(
        self, apns_token: str | None, college_ref_id: int
    ) -> None:
        logger.debug(
            "NullNotificationService: génération complète collège %s (APNs non configuré)",
            college_ref_id,
        )


class APNsNotificationService(NotificationService):
    def __init__(self) -> None:
        from aioapns import APNs
        from app.core.config import settings
        self._apns = APNs(
            key=settings.apns_key_path,
            key_id=settings.apns_key_id,
            team_id=settings.apns_team_id,
            topic=settings.apns_bundle_id,
            use_sandbox=settings.apns_use_sandbox,
        )

    async def send_generation_complete(
        self, apns_token: str | None, college_ref_id: int
    ) -> None:
        if not apns_token:
            logger.info("APNs token absent pour collège %s — notification ignorée", college_ref_id)
            return
        from aioapns import NotificationRequest, PushType
        request = NotificationRequest(
            device_token=apns_token,
            message={
                "aps": {
                    "alert": {
                        "title": "Fiches prêtes !",
                        "body": "Tes fiches sont disponibles dans AppMédecine",
                    },
                    "sound": "default",
                    "badge": 1,
                },
                "college_ref_id": college_ref_id,
            },
            push_type=PushType.ALERT,
        )
        result = await self._apns.send_notification(request)
        if result.is_successful:
            logger.info("Push APNs envoyé (collège %s)", college_ref_id)
        else:
            logger.warning(
                "Push APNs échoué pour collège %s : %s", college_ref_id, result.description
            )


def get_notification_service() -> NotificationService:
    from app.core.config import settings
    if settings.apns_key_path and settings.apns_key_id and settings.apns_team_id:
        return APNsNotificationService()
    return NullNotificationService()
```

---

### Backend : `generation_worker.py` — ajout notification push

```python
# Dans generate_college_cards(), après l'appel generate_for_college() réussi :

# Envoyer notification push (erreur APNs ne fait PAS échouer le job)
try:
    from sqlalchemy import select
    from app.models.user import User
    from app.models.college import College
    from app.services.notifications.apns_service import get_notification_service

    async with async_session_factory() as notif_db:
        user_result = await notif_db.execute(
            select(User).where(User.id == job.user_id)
        )
        user = user_result.scalar_one_or_none()
        college_result = await notif_db.execute(
            select(College).where(College.id == uuid.UUID(college_id))
        )
        college = college_result.scalar_one_or_none()
        if user and college:
            await get_notification_service().send_generation_complete(
                user.apns_token, college.college_ref_id
            )
except Exception as notif_exc:
    logger.warning("Notification push ignorée (non-bloquant) : %s", notif_exc)
```

**Important** : ouvrir une **nouvelle session DB** (`async with async_session_factory()`) pour la notification — la session principale est déjà committée à ce stade. Ne pas modifier le `return result` existant.

---

### Backend : `ClaudeClient.regenerate_single_card()`

```python
# Dans collega_backend/app/services/generation/claude_client.py — AJOUTER

REGENERATION_PROMPT = """
Tu es un expert en fiches de révision médicale ECNi.
La fiche suivante a été jugée non pertinente par un étudiant.

Fiche originale :
- Type : {card_type}
- Recto : {recto}
- Verso : {verso}
- Item : {item_number} (Rang {rang})

Feedback de l'étudiant : {user_note}

Texte OCR source :
{ocr_text}

Régénère UNE fiche améliorée du même type (classique ou définition) en tenant compte du feedback.

Réponds UNIQUEMENT avec un objet JSON valide, sans markdown :
{{"type": "{card_type}", "recto": "Question améliorée ?", "verso": "Réponse améliorée"}}
"""


async def regenerate_single_card(
    self,
    card,          # FlashCard SQLAlchemy instance
    item,          # Item SQLAlchemy instance
    user_note: str | None,
) -> "FlashCardData | None":
    """Régénère une seule fiche avec le feedback utilisateur en contexte."""
    if not item.ocr_text:
        logger.warning("Item %s has no ocr_text — cannot regenerate card %s", item.id, card.id)
        return None

    safe_ocr_text = item.ocr_text.replace("{", "{{").replace("}", "}}")
    safe_note = (user_note or "Aucun commentaire spécifique").replace("{", "{{").replace("}", "}}")

    prompt = REGENERATION_PROMPT.format(
        card_type=card.card_type,
        recto=card.recto.replace("{", "{{").replace("}", "}}"),
        verso=card.verso.replace("{", "{{").replace("}", "}}"),
        item_number=item.item_number,
        rang=item.rang,
        user_note=safe_note,
        ocr_text=safe_ocr_text,
    )

    try:
        response = await self._client.messages.create(
            model="claude-sonnet-4-6",
            max_tokens=500,
            messages=[{"role": "user", "content": prompt}],
        )
        raw = response.content[0].text.strip()
        if raw.startswith("```"):
            raw = re.sub(r"^```[a-z]*\n?", "", raw)
            raw = re.sub(r"\n?```$", "", raw)
            raw = raw.strip()
        data = json.loads(raw)
    except (anthropic.APIError, json.JSONDecodeError, KeyError, IndexError) as exc:
        logger.error("Failed to regenerate card %s: %s", card.id, exc)
        return None

    card_type = data.get("type", card.card_type)
    recto = data.get("recto", "").strip()
    verso = data.get("verso", "").strip()
    if not recto or not verso:
        return None
    return FlashCardData(card_type=card_type, recto=recto, verso=verso)
```

---

### Backend : `flash_cards.py` router

```python
# collega_backend/app/api/v1/flash_cards.py
"""Endpoints de feedback, suppression et régénération de fiches — FR19, FR20, FR21."""
from __future__ import annotations

import logging
import uuid

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.deps import require_subscription
from app.models.flash_card import FlashCard
from app.models.item import Item
from app.schemas.college import (
    FlashCardData,
    FlashCardFeedbackRequest,
    FlashCardRegenerateRequest,
    FlashCardResponseWrapped,
)
from app.services.generation.claude_client import ClaudeClient

logger = logging.getLogger(__name__)
router = APIRouter(tags=["flash-cards"])


async def _get_card_for_user(
    card_id: uuid.UUID,
    current_user,
    db: AsyncSession,
) -> FlashCard:
    """Charge la fiche et vérifie le scoping user_id."""
    card = await db.get(FlashCard, card_id)
    if card is None or card.user_id != current_user.id:
        raise HTTPException(
            status_code=404,
            detail={"code": "CARD_NOT_FOUND", "message": "Fiche introuvable"},
        )
    return card


@router.post("/flash-cards/{card_id}/feedback")
async def submit_feedback(
    card_id: uuid.UUID,
    body: FlashCardFeedbackRequest,
    current_user=Depends(require_subscription),
    db: AsyncSession = Depends(get_db),
):
    card = await _get_card_for_user(card_id, current_user, db)
    card.user_feedback = body.feedback
    await db.commit()
    return {"data": {"id": str(card.id), "feedback": card.user_feedback}}


@router.delete("/flash-cards/{card_id}", status_code=204)
async def delete_card(
    card_id: uuid.UUID,
    current_user=Depends(require_subscription),
    db: AsyncSession = Depends(get_db),
):
    card = await _get_card_for_user(card_id, current_user, db)
    await db.delete(card)
    await db.commit()


@router.post("/flash-cards/{card_id}/regenerate", response_model=FlashCardResponseWrapped)
async def regenerate_card(
    card_id: uuid.UUID,
    body: FlashCardRegenerateRequest,
    current_user=Depends(require_subscription),
    db: AsyncSession = Depends(get_db),
) -> FlashCardResponseWrapped:
    card = await _get_card_for_user(card_id, current_user, db)

    # Charger l'item pour le contexte OCR
    item = await db.get(Item, card.item_id)
    if item is None:
        raise HTTPException(
            status_code=422,
            detail={"code": "ITEM_NOT_FOUND", "message": "Item source introuvable"},
        )

    claude = ClaudeClient()
    new_card_data = await claude.regenerate_single_card(card, item, body.user_note)
    if new_card_data is None:
        raise HTTPException(
            status_code=503,
            detail={"code": "REGENERATION_FAILED", "message": "Régénération échouée"},
        )

    # Mettre à jour la fiche existante (même ID, même item_id)
    card.card_type = new_card_data.card_type
    card.recto = new_card_data.recto
    card.verso = new_card_data.verso
    card.user_feedback = None  # Reset feedback après régénération
    await db.commit()
    await db.refresh(card)

    return FlashCardResponseWrapped(
        data=FlashCardData(
            id=str(card.id),
            item_id=str(card.item_id),
            college_id=str(card.college_id),
            card_type=card.card_type,
            rang=card.rang,
            recto=card.recto,
            verso=card.verso,
            ocr_confidence_score=card.ocr_confidence_score,
            low_confidence=card.low_confidence,
            user_feedback=card.user_feedback,
        )
    )
```

---

### Backend : `notifications.py` router

```python
# collega_backend/app/api/v1/notifications.py
"""Enregistrement token APNs — FR23."""
from __future__ import annotations

from pydantic import BaseModel
from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.deps import get_current_user

router = APIRouter(tags=["notifications"])


class ApnsTokenRequest(BaseModel):
    token: str


@router.post("/notifications/apns-token")
async def register_apns_token(
    body: ApnsTokenRequest,
    current_user=Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    current_user.apns_token = body.token
    await db.commit()
    return {"data": {"registered": True}}
```

---

### Backend : Mise à jour `main.py`

```python
# Ajouter après les imports existants :
from app.api.v1.flash_cards import router as flash_cards_router
from app.api.v1.notifications import router as notifications_router

# Ajouter dans app.include_router() :
app.include_router(flash_cards_router, prefix="/v1")
app.include_router(notifications_router, prefix="/v1")
```

---

### Backend : Nouveaux schémas Pydantic

```python
# Dans collega_backend/app/schemas/college.py — AJOUTER à la fin
from typing import Literal

class FlashCardFeedbackRequest(BaseModel):
    feedback: Literal['positive', 'negative']

class FlashCardRegenerateRequest(BaseModel):
    user_note: str | None = None

# METTRE À JOUR FlashCardData pour inclure user_feedback :
class FlashCardData(BaseModel):
    id: str
    item_id: str
    college_id: str
    card_type: str
    rang: str
    recto: str
    verso: str
    ocr_confidence_score: float
    low_confidence: bool
    user_feedback: str | None = None   # NOUVEAU CHAMP

class FlashCardResponseWrapped(BaseModel):
    data: FlashCardData
```

**ATTENTION** : `FlashCardData` est déjà utilisé dans `colleges.py` pour `GET /v1/colleges/{id}/items/{itemId}/cards`. Ajouter `user_feedback: str | None = None` est rétrocompatible (valeur par défaut None).

---

### Flutter : `FlashCards` table Drift — ajout colonne

```dart
// collega_app/lib/core/database/tables/flash_cards_table.dart — AJOUTER
TextColumn get userFeedback => text().nullable()();
```

```dart
// collega_app/lib/core/database/app_database.dart — MODIFIER
@override
int get schemaVersion => 3;  // était 2

@override
MigrationStrategy get migration => MigrationStrategy(
  onCreate: (Migrator m) async {
    await m.createAll();
  },
  onUpgrade: (Migrator m, int from, int to) async {
    if (from < 2) {
      await m.createTable(items);
      await m.createTable(flashCards);
    }
    if (from < 3) {
      await m.addColumn(flashCards, flashCards.userFeedback);
    }
  },
);
```

Régénérer après : `dart run build_runner build --delete-conflicting-outputs` dans `collega_app/`.

---

### Flutter : `FlashCardModel` mis à jour

```dart
// Dans college_detail_models.dart

class FlashCardModel {
  const FlashCardModel({
    required this.id,
    required this.itemId,
    required this.collegeId,
    required this.cardType,
    required this.rang,
    required this.recto,
    required this.verso,
    required this.ocrConfidenceScore,
    required this.lowConfidence,
    this.userFeedback,           // NOUVEAU — nullable
  });

  // ... champs existants ...
  final String? userFeedback;

  factory FlashCardModel.fromJson(Map<String, dynamic> json) => FlashCardModel(
        // ... champs existants ...
        userFeedback: json['user_feedback'] as String?,  // NOUVEAU
      );

  FlashCardModel copyWith({String? id, /* ... */ String? userFeedback}) =>
      FlashCardModel(/* ... */ userFeedback: userFeedback ?? this.userFeedback);
}
```

Ajouter `copyWith` — **indispensable** pour mettre à jour les cartes dans le notifier sans récharger depuis le réseau.

---

### Flutter : Méthodes `CollegeDetailRepository`

```dart
// Dans college_detail_repository.dart — AJOUTER
import 'dart:convert';

Future<void> submitFeedback(String cardId, String feedback) async {
  await dio.post<void>(
    '/v1/flash-cards/$cardId/feedback',
    data: {'feedback': feedback},
  );
  // Mettre à jour Drift
  await (db.update(db.flashCards)..where((t) => t.id.equals(cardId)))
      .write(FlashCardsCompanion(userFeedback: Value(feedback)));
}

Future<void> deleteCard(String cardId) async {
  await dio.delete<void>('/v1/flash-cards/$cardId');
  await (db.delete(db.flashCards)..where((t) => t.id.equals(cardId))).go();
}

Future<FlashCardModel> regenerateCard(String cardId, {String? userNote}) async {
  final response = await dio.post<Map<String, dynamic>>(
    '/v1/flash-cards/$cardId/regenerate',
    data: {'user_note': userNote},
  );
  final newCard = FlashCardModel.fromJson(
    response.data!['data'] as Map<String, dynamic>,
  );
  await syncCardsToDrift([newCard]);
  return newCard;
}

// METTRE À JOUR syncCardsToDrift pour inclure userFeedback :
// Dans FlashCardsCompanion.insert(...) : ajouter userFeedback: Value(c.userFeedback),
// Dans getCardsFromDrift : ajouter userFeedback: r.userFeedback,
```

---

### Flutter : Méthodes `ItemDetailNotifier`

```dart
// Dans colleges_detail_providers.dart — AJOUTER dans ItemDetailNotifier

Future<void> submitPositiveFeedback(String cardId) async {
  final repo = ref.read(collegeDetailRepositoryProvider);
  try {
    await repo.submitFeedback(cardId, 'positive');
    final current = state.valueOrNull ?? [];
    state = AsyncValue.data(
      current.map((c) => c.id == cardId ? c.copyWith(userFeedback: 'positive') : c).toList(),
    );
  } on DioException catch (e) {
    AppLogger.error('submitPositiveFeedback failed', tag: 'ItemDetailNotifier', error: e);
    rethrow;
  }
}

Future<void> deleteCard(String cardId) async {
  final repo = ref.read(collegeDetailRepositoryProvider);
  await repo.deleteCard(cardId);
  final current = state.valueOrNull ?? [];
  state = AsyncValue.data(current.where((c) => c.id != cardId).toList());
  // Invalider le provider de détail collège pour refresh des compteurs
  ref.invalidate(collegeDetailProvider);
}

Future<FlashCardModel> regenerateCard(String cardId, {String? userNote}) async {
  final repo = ref.read(collegeDetailRepositoryProvider);
  final newCard = await repo.regenerateCard(cardId, userNote: userNote);
  final current = state.valueOrNull ?? [];
  state = AsyncValue.data(
    current.map((c) => c.id == cardId ? newCard : c).toList(),
  );
  return newCard;
}
```

---

### Flutter : UI feedback dans `ItemDetailScreen`

`_ItemDetailBody` doit devenir `ConsumerStatefulWidget` (il est déjà `StatefulWidget` — ajouter `Consumer`) pour accéder au ref.

```dart
// Transformer _ItemDetailBody en ConsumerStatefulWidget :
class _ItemDetailBody extends ConsumerStatefulWidget {
  const _ItemDetailBody({required this.cards, required this.collegeId, required this.compositeKey});
  final List<FlashCardModel> cards;
  final String collegeId;
  final String compositeKey;  // pour ref.read(itemDetailProvider(compositeKey).notifier)
  @override
  ConsumerState<_ItemDetailBody> createState() => _ItemDetailBodyState();
}
```

Dans chaque `ShadAccordionItem`, APRÈS `OcrConfidenceBadge`, ajouter les boutons feedback :

```dart
// AJOUTER après le bloc OcrConfidenceBadge
Row(
  mainAxisAlignment: MainAxisAlignment.end,
  children: [
    IconButton(
      icon: Icon(
        Icons.thumb_up_outlined,
        color: card.userFeedback == 'positive'
            ? AppColors.primary
            : null,
        size: 20,
      ),
      onPressed: _isLoadingCard(card.id)
          ? null
          : () => _handlePositiveFeedback(card.id),
      tooltip: 'Fiche pertinente',
    ),
    IconButton(
      icon: const Icon(Icons.thumb_down_outlined, size: 20),
      onPressed: _isLoadingCard(card.id)
          ? null
          : () => _handleNegativeFeedback(card),
      tooltip: 'Fiche non pertinente',
    ),
  ],
),
```

État de chargement par card :
```dart
// Dans _ItemDetailBodyState :
final _loadingCards = <String>{};
bool _isLoadingCard(String id) => _loadingCards.contains(id);
void _setCardLoading(String id, bool loading) {
  setState(() {
    if (loading) _loadingCards.add(id); else _loadingCards.remove(id);
  });
}
```

Dialog "Pouce bas" → `ShadDialog.alert` :
```dart
Future<void> _handleNegativeFeedback(FlashCardModel card) async {
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
        ShadButton.destructive(
          onPressed: () => Navigator.of(ctx).pop('delete'),
          child: const Text('Supprimer'),
        ),
        ShadButton(
          onPressed: () => Navigator.of(ctx).pop('regenerate'),
          child: const Text('Régénérer'),
        ),
      ],
    ),
  );

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
    await _regenerateCard(card.id, userNote: controller.text.trim().isEmpty ? null : controller.text.trim());
  }
  controller.dispose();
}

Future<void> _handlePositiveFeedback(String cardId) async {
  if (!mounted) return;
  _setCardLoading(cardId, true);
  try {
    await ref.read(itemDetailProvider(widget.compositeKey).notifier).submitPositiveFeedback(cardId);
    if (!mounted) return;
    ShadToaster.of(context).show(
      const ShadToast(
        title: Text('Fiche signalée comme pertinente'),
      ),
    );
  } catch (_) {
    if (mounted) {
      ShadToaster.of(context).show(
        const ShadToast.destructive(title: Text('Erreur lors de l\'enregistrement')),
      );
    }
  } finally {
    if (mounted) _setCardLoading(cardId, false);
  }
}

Future<void> _deleteCard(String cardId) async {
  _setCardLoading(cardId, true);
  try {
    await ref.read(itemDetailProvider(widget.compositeKey).notifier).deleteCard(cardId);
  } catch (_) {
    if (mounted) {
      ShadToaster.of(context).show(
        const ShadToast.destructive(title: Text('Erreur lors de la suppression')),
      );
    }
  } finally {
    if (mounted) _setCardLoading(cardId, false);
  }
}

Future<void> _regenerateCard(String cardId, {String? userNote}) async {
  _setCardLoading(cardId, true);
  try {
    await ref.read(itemDetailProvider(widget.compositeKey).notifier).regenerateCard(cardId, userNote: userNote);
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
    if (mounted) _setCardLoading(cardId, false);
  }
}
```

---

### Flutter : `NotificationsService`

```dart
// collega_app/lib/core/notifications/notifications_service.dart
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_apns_only/flutter_apns_only.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:collega_app/core/utils/logger.dart';

class NotificationsService {
  NotificationsService({required this.dio, required this.navigatorKey});

  final Dio dio;
  final GlobalKey<NavigatorState> navigatorKey;  // pour navigation depuis notification

  final _connector = ApnsPushConnectorOnly();

  Future<void> requestPermissionsAndRegister() async {
    if (!defaultTargetPlatform.name.toLowerCase().contains('ios')) return;

    _connector.configureApns(
      onLaunch: _onNotificationTap,
      onResume: _onNotificationTap,
      onMessage: (message) async {
        // App au premier plan — optionnel : afficher une bannière in-app
        AppLogger.info('Notification reçue (foreground)', tag: 'NotificationsService');
      },
    );

    await _connector.requestNotificationPermissions();

    _connector.token.addListener(() {
      final token = _connector.token.value;
      if (token != null) _registerToken(token);
    });
  }

  Future<void> _onNotificationTap(Map<String, dynamic> payload) async {
    final collegeRefId = payload['college_ref_id'];
    if (collegeRefId == null) return;
    // Naviguer vers le détail collège
    final context = navigatorKey.currentContext;
    if (context != null && context.mounted) {
      context.go('/colleges/$collegeRefId');
    }
  }

  Future<void> _registerToken(String token) async {
    try {
      await dio.post<void>(
        '/v1/notifications/apns-token',
        data: {'token': token},
      );
      AppLogger.info('APNs token enregistré', tag: 'NotificationsService');
    } on Exception catch (e) {
      AppLogger.error('Échec enregistrement token APNs', tag: 'NotificationsService', error: e);
    }
  }
}

final notificationsServiceProvider = Provider<NotificationsService?>((ref) => null);
```

**Note GoRouter / NavigatorKey** : Le deep link depuis notification nécessite un `GlobalKey<NavigatorState>`. Exposer ce key via le `routerProvider` ou un `navigatorKeyProvider`. Vérifier comment GoRouter est configuré dans `app_router.dart` — si `GoRouter` est créé avec `navigatorKey`, l'extraire via `ref.read(routerProvider).routerDelegate.navigatorKey`.

Alternative plus simple si `GoRouter` est dans un `Provider` : utiliser `ref.read(routerProvider).go('/colleges/$collegeRefId')` directement dans `_onNotificationTap` sans navigatorKey.

---

### Flutter : Initialisation dans `main.dart`

```dart
// Ajouter l'initialisation des notifications après auth login
// Pattern recommandé : écouter authProvider dans un widget haut niveau
// (ex: dans App.dart ou via un listener dans GoRouter)

// Dans un ConsumerWidget racine, après confirmation auth :
ref.listen(authProvider, (_, state) {
  if (state.valueOrNull?.isAuthenticated == true) {
    final dio = ref.read(apiClientProvider).dio;
    ref.read(notificationsServiceProvider)?.requestPermissionsAndRegister();
  }
});
```

L'initialisation des notifications DOIT se faire APRÈS l'auth pour que le token soit enregistré avec le bon user JWT.

---

### Anti-patterns à éviter

- **NE PAS** envoyer la notification push depuis `card_generator.py` — la notification appartient au `generation_worker.py` (separation of concerns)
- **NE PAS** faire échouer le job de génération si APNs échoue — `try/except` obligatoire autour de l'appel push
- **NE PAS** utiliser `ShadSkeleton` — absent de `shadcn_ui ^0.19.0`, utiliser `CircularProgressIndicator(strokeWidth: 2)` 20px ou `_isLoadingCard` pattern
- **NE PAS** oublier `mounted` check dans tous les callbacks async Flutter (pattern `if (!mounted) return;`)
- **NE PAS** modifier `card_type` ou `rang` lors de la régénération — seuls `recto`, `verso`, `user_feedback` changent (le rang est une propriété de l'item, pas de la fiche)
- **NE PAS** utiliser `package:collection` — non dans `pubspec.yaml`
- **NE PAS** oublier `copyWith` sur `FlashCardModel` — indispensable pour les mises à jour optimistes
- **NE PAS** appeler `ref.invalidate(itemDetailProvider(...))` pour les mises à jour — utiliser mutation directe du state via les méthodes notifier (performance)
- **NE PAS** créer une nouvelle fiche (nouveau UUID) lors de la régénération — mettre à jour la fiche existante (même UUID) pour préserver les références Drift
- **NE PAS** supprimer puis recréer la fiche lors d'un reimport collège (hash-sharing) — hors scope cette story

---

### Règles qualité héritées des stories précédentes

- `flutter analyze` → 0 erreur avant de marquer terminée
- `AsyncValue.when(loading, error, data)` pour tous les états async
- Logique métier dans les Notifiers, jamais dans les widgets
- Pattern `_Fake[Repository]` pour les tests Flutter (sans mockito)
- `ShadToast` pour erreurs non-bloquantes
- `ShadDialog.alert` pour confirmations et blocages
- `AppLogger` pour les logs (jamais `print()` ni `debugPrint()`)
- Pattern `_make_user()`, `_make_card()` dans les tests Python

---

### Références

- `flash_card.py` (modèle SQLAlchemy) : `collega_backend/app/models/flash_card.py`
- `claude_client.py` : `collega_backend/app/services/generation/claude_client.py`
- `generation_worker.py` : `collega_backend/app/workers/generation_worker.py`
- `item_detail_screen.dart` (UI fiches, accordion) : `collega_app/lib/features/colleges/presentation/item_detail_screen.dart:90`
- `college_detail_models.dart` (FlashCardModel, ItemModel) : `collega_app/lib/features/colleges/domain/college_detail_models.dart`
- `college_detail_repository.dart` (syncCardsToDrift, getCardsFromDrift) : `collega_app/lib/features/colleges/data/college_detail_repository.dart`
- `colleges_detail_providers.dart` (ItemDetailNotifier) : `collega_app/lib/features/colleges/colleges_detail_providers.dart`
- `app_database.dart` (schemaVersion=2, migration) : `collega_app/lib/core/database/app_database.dart`
- `flash_cards_table.dart` (colonnes Drift) : `collega_app/lib/core/database/tables/flash_cards_table.dart`
- `app_router.dart` (GoRouter, routes existantes) : `collega_app/lib/core/router/app_router.dart`
- `config.py` (Settings, pydantic-settings) : `collega_backend/app/core/config.py`
- `schemas/college.py` (FlashCardData — à étendre) : `collega_backend/app/schemas/college.py`
- `main.py` (routers existants) : `collega_backend/app/main.py`
- `deps.py` (require_subscription, get_current_user) : `collega_backend/app/deps.py`
- Pattern tests backend (conftest, mock_db) : `collega_backend/tests/conftest.py`
- Tests reimport (pattern _make_user, _make_college) : `collega_backend/tests/api/test_colleges_reimport.py`

---

## Dev Agent Record

### Agent Model Used

claude-sonnet-4-6

### Debug Log References

- `flutter_apns_only` 1.6.0 installé (pas 1.0.0) — `ApnsMessageHandler` prend `ApnsRemoteMessage` (non `Map<String, dynamic>`) → adapté les callbacks
- `ApnsPushConnectorOnly` ne peut être instancié que sur iOS (assert) → création lazy dans `requestPermissionsAndRegister()` avec guard `defaultTargetPlatform != TargetPlatform.iOS`
- `notificationsServiceProvider` implémenté comme `Provider<NotificationsService>` réel (pas nullable) en lisant `apiClientProvider` et `routerProvider`

### Completion Notes List

- Migration Alembic #008 : ajout colonne `user_feedback VARCHAR(20) NULL` sur `flash_cards` avec CheckConstraint
- Modèle SQLAlchemy `FlashCard` mis à jour avec `user_feedback: Mapped[str | None]`
- Config APNs ajoutée dans `Settings` (5 champs, valeurs vides par défaut, fallback `NullNotificationService` si incomplet)
- Service `apns_service.py` avec `NotificationService` (ABC), `NullNotificationService`, `APNsNotificationService`, `get_notification_service()`
- Router `flash_cards.py` : 3 endpoints (feedback, delete, regenerate) + scoping user_id + `require_subscription`
- Router `notifications.py` : 1 endpoint `POST /v1/notifications/apns-token`
- `ClaudeClient.regenerate_single_card()` : appel Claude synchrone, retourne `FlashCardData` schema Pydantic
- `generation_worker.py` : push APNs après génération réussie, nouvelle session DB, try/except non-bloquant
- Drift schemaVersion 3 + migration `addColumn(flashCards.userFeedback)` + build_runner régénéré
- `FlashCardModel` : `userFeedback`, `fromJson`, `copyWith` ajoutés
- `CollegeDetailRepository` : `submitFeedback`, `deleteCard`, `regenerateCard` + `syncCardsToDrift`/`getCardsFromDrift` mis à jour
- `ItemDetailNotifier` : `submitPositiveFeedback`, `deleteCard`, `regenerateCard` ajoutés
- `_ItemDetailBody` → `ConsumerStatefulWidget` avec état de chargement per-card, UI pouces haut/bas, dialogs ShadDialog, toasts
- `NotificationsService` + `notificationsServiceProvider` (Provider réel)
- `app.dart` : `ref.listen(authProvider, ...)` pour init notifications après auth
- Tests backend : 7 tests, tous verts ; Tests Flutter : 6 nouveaux + 55 total, 0 régression

### File List

**Backend (nouveau) :**
- `collega_backend/alembic/versions/008_add_user_feedback_to_flash_cards.py`
- `collega_backend/app/api/v1/flash_cards.py`
- `collega_backend/app/api/v1/notifications.py`
- `collega_backend/app/services/notifications/apns_service.py`
- `collega_backend/tests/api/test_flash_cards.py`

**Backend (modifié) :**
- `collega_backend/app/models/flash_card.py` (ajout `user_feedback`)
- `collega_backend/app/schemas/college.py` (FlashCardData + nouveaux schémas)
- `collega_backend/app/services/generation/claude_client.py` (ajout `regenerate_single_card`)
- `collega_backend/app/workers/generation_worker.py` (ajout notification push)
- `collega_backend/app/core/config.py` (ajout config APNs)
- `collega_backend/app/main.py` (ajout routers)

**Flutter (nouveau) :**
- `collega_app/lib/core/notifications/notifications_service.dart`

**Flutter (modifié) :**
- `collega_app/pubspec.yaml` (ajout `flutter_apns_only`)
- `collega_app/lib/core/database/tables/flash_cards_table.dart` (ajout `userFeedback`)
- `collega_app/lib/core/database/app_database.dart` (schemaVersion 3)
- `collega_app/lib/core/database/app_database.g.dart` (regénéré)
- `collega_app/lib/features/colleges/domain/college_detail_models.dart` (FlashCardModel + copyWith)
- `collega_app/lib/features/colleges/data/college_detail_repository.dart` (feedback/delete/regenerate)
- `collega_app/lib/features/colleges/colleges_detail_providers.dart` (méthodes notifier)
- `collega_app/lib/features/colleges/presentation/item_detail_screen.dart` (UI feedback)
- `collega_app/lib/main.dart` (init notifications après auth)

**Flutter (tests) :**
- `collega_app/test/features/colleges/flash_card_feedback_test.dart`

### Review Findings

#### Patches (à corriger)

- [x] [Review][Patch] APNs singleton — `get_notification_service()` instancie une nouvelle `APNsNotificationService` (et donc une nouvelle connexion HTTP/2 Apple) à chaque notification. À rendre singleton (module-level ou `app.state`). [`apns_service.py` + `generation_worker.py`]
- [x] [Review][Patch] `card_type` modifié lors de la régénération — viole l'anti-pattern spec ("NE PAS modifier `card_type`"). `flash_cards.py:87` écrase `card.card_type` avec la valeur Claude. Fixer : ignorer la valeur `type` retournée par Claude et toujours garder `card.card_type`. [`flash_cards.py:87`, `claude_client.py:169`]
- [x] [Review][Patch] `regenerate_card` retourne `new_card_data` (construit avant commit) au lieu du `card` refreshé — `db.refresh(card)` est du dead code. La réponse HTTP diverge de l'état DB (ex. `user_feedback` absent). Construire la réponse depuis `card` après `db.refresh`. [`flash_cards.py:92-94`]
- [x] [Review][Patch] Race condition compteur reimport — check `< max` + incrément non atomiques même avec `with_for_update()`. Deux workers concurrents peuvent dépasser la limite. Utiliser un `UPDATE ... SET count = count + 1 WHERE count < max`. [`card_generator.py:109+`]
- [x] [Review][Patch] Migration Drift v1→v3 : doublon colonne — `m.createTable(flashCards)` en branch `from < 2` crée la table avec `userFeedback` (schéma actuel), puis `from < 3` tente un `ADD COLUMN` → erreur SQLite "duplicate column". Corriger : garder la création v1 sans la colonne ou conditionner `from < 3 && from >= 2`. [`app_database.dart:30-36`]
- [x] [Review][Patch] Migration Drift v1→v2 : `college_imports` jamais créé — la branch `from < 2` crée `items` et `flashCards` mais pas `collegeImports` (pourtant dans `@DriftDatabase`). Crash garanti pour les users upgradeant depuis v1. Ajouter `await m.createTable(collegeImports)`. [`app_database.dart:30-33`]
- [x] [Review][Patch] Feedback négatif jamais persisté en DB — `_handleNegativeFeedback` ouvre un dialog mais n'appelle jamais `submitFeedback(cardId, 'negative')`. Le backend ne reçoit jamais `user_feedback = "negative"`. Appeler `submitFeedback` avant/pendant le dialog. [`item_detail_screen.dart:163`]
- [x] [Review][Patch] `ref.invalidate(collegeDetailProvider)` sans argument family — invalide TOUTES les instances du provider (tous les collèges), pas seulement le collège courant. Utiliser `ref.invalidate(collegeDetailProvider(collegeId))`. [`colleges_detail_providers.dart:99`]
- [x] [Review][Patch] APNs token non validé — `POST /v1/notifications/apns-token` accepte n'importe quelle chaîne. Ajouter `Field(min_length=64, max_length=200, pattern=r'^[0-9a-fA-F]+$')` sur `ApnsTokenRequest.token`. [`notifications.py:14`]
- [x] [Review][Patch] Pas de rate limiting sur `POST /flash-cards/{id}/regenerate` — un user abonné peut appeler l'endpoint en boucle sans limite, générant des coûts Claude illimités. Ajouter `@limiter.limit("X/hour")`. [`flash_cards.py:63`]
- [x] [Review][Patch] `_connector` non réinitialisé au logout — si un 2e utilisateur se connecte sur le même device, `_connector != null` court-circuite l'initialisation APNs et le token n'est jamais enregistré pour le nouveau compte. Ajouter un `reset()` appelé au logout. [`notifications_service.dart:22`]
- [x] [Review][Patch] `_registerToken` swallows le 401 silencieusement — si le JWT est expiré quand le listener APNs fire, le token n'est jamais enregistré côté backend, sans retry. Vérifier que l'intercepteur Dio auth gère le 401 de cet endpoint, ou ajouter un retry explicite. [`notifications_service.dart:50-59`]
- [x] [Review][Patch] Ordre boutons dialog inversé — spec AC1 : "Régénérer" (primary) avant "Supprimer" (destructive). L'implémentation a Supprimer avant Régénérer. Inverser l'ordre dans `actions`. [`item_detail_screen.dart:171-185`]
- [x] [Review][Patch] `deleteCard` notifier sans try/catch — contrairement à `submitPositiveFeedback`, `deleteCard` n'a pas de bloc catch. Si le repo throw, l'exception remonte sans état d'erreur sur le notifier. Ajouter try/catch cohérent. [`colleges_detail_providers.dart:94-100`]
- [x] [Review][Patch] `FlashCardModel.copyWith` ne peut pas remettre `userFeedback` à `null` — `userFeedback ?? this.userFeedback` empêche le passage explicite de `null`. Ajouter un paramètre sentinel `clearUserFeedback: false` ou utiliser `Optional<String?>`. [`college_detail_models.dart:80`]
- [x] [Review][Patch] Risque `DetachedInstanceError` — `job.user_id` est lu depuis l'objet ORM `job` chargé dans la session principale (déjà committée) à l'intérieur d'un bloc `async with async_session_factory() as notif_db`. Si `user_id` est lazy-loaded, cela crash. Lire `job.user_id` avant d'entrer dans le bloc `notif_db`. [`generation_worker.py:38`]

#### Deferred (pré-existant / hors scope)

- [x] [Review][Defer] `monthly_reloads_reset_at` ajouté sans logique de reset mensuel — le compteur ne sera jamais réinitialisé, rendant la limite mensuelle de facto permanente. Hors scope story 3-5. [`user.py`] — deferred, pre-existing
- [x] [Review][Defer] SSE JWT stale sur longue connexion — `_tokenProvider()` capturé une fois à la connexion pour un `receiveTimeout` de 3h. Dépend de l'implémentation du `tokenProvider` (intercepteur auth). [`sse_client.dart`] — deferred, pre-existing
- [x] [Review][Defer] APNs token persisté après logout — pas d'endpoint `DELETE /v1/notifications/apns-token` pour invalider le token. Hors scope. [`notifications.py`] — deferred, pre-existing
- [x] [Review][Defer] Prompt injection via `user_note` — contenu utilisateur interpolé verbatim dans le prompt Claude. Risque acceptable en app fermée (l'attaquant est aussi la victime). Décision produit. [`claude_client.py`] — deferred, pre-existing

## Change Log

- Story 3.5 implémentée — feedback fiches (pouce haut/bas), régénération synchrone Claude, suppression, notification push APNs en fin de génération (Date: 2026-05-12)
