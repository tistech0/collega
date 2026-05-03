"""Seed de développement — insère un collège fictif avec fiches pour tester sans Claude."""
import asyncio
import uuid

from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession, create_async_engine
from sqlalchemy.orm import sessionmaker

from app.core.config import settings

engine = create_async_engine(settings.database_url, echo=False)
AsyncSessionLocal = sessionmaker(engine, class_=AsyncSession, expire_on_commit=False)

COLLEGE_REF_ID = 45  # Item ECNi 45 — Douleur thoracique aiguë

ITEMS = [
    {
        "item_number": 45,
        "rang": "A",
        "chapter_title": "Douleur thoracique aiguë",
        "ocr_confidence_score": 0.91,
        "low_confidence": False,
        "cards": [
            {
                "card_type": "classique",
                "rang": "A",
                "recto": "Quelles sont les 3 causes immédiates à éliminer devant une douleur thoracique aiguë ?",
                "verso": "1. Syndrome coronarien aigu (SCA)\n2. Embolie pulmonaire (EP)\n3. Dissection aortique",
            },
            {
                "card_type": "classique",
                "rang": "A",
                "recto": "Quel ECG est caractéristique d'un SCA ST+ antérieur ?",
                "verso": "Sus-décalage ST ≥ 2 mm en V1–V4 avec image en miroir inférieure. Aspect de Pardee si onde de nécrose Q présente.",
            },
            {
                "card_type": "definition",
                "rang": "A",
                "recto": "Définition du syndrome coronarien aigu (SCA)",
                "verso": "Occlusion totale ou partielle d'une artère coronaire par rupture de plaque athéromateuse et thrombose.",
            },
        ],
    },
    {
        "item_number": 67,
        "rang": "B",
        "chapter_title": "Insuffisance cardiaque — examens complémentaires",
        "ocr_confidence_score": 0.85,
        "low_confidence": False,
        "cards": [
            {
                "card_type": "classique",
                "rang": "B",
                "recto": "Quelle est la sensibilité de la troponine à H0 pour le SCA ?",
                "verso": "Troponine ultrasensible : Se ~80–90 % à H0, ~99 % à H3. Un dosage négatif à H0+H3 exclut le SCA avec forte probabilité.",
            },
            {
                "card_type": "classique",
                "rang": "B",
                "recto": "Signe de Homans : définition et utilité",
                "verso": "Douleur du mollet à la dorsiflexion passive du pied. Peu sensible et peu spécifique — ne pas utiliser seul.",
                "low_confidence": True,
                "ocr_confidence_score": 0.62,
            },
        ],
    },
    {
        "item_number": 135,
        "rang": "C",
        "chapter_title": "Dissection aortique",
        "ocr_confidence_score": 0.78,
        "low_confidence": False,
        "cards": [
            {
                "card_type": "classique",
                "rang": "C",
                "recto": "Signes cliniques d'une dissection aortique de type A ?",
                "verso": "Douleur thoracique déchirante irradiant dans le dos + asymétrie tensionnelle > 20 mmHg + souffle IA. Urgence chirurgicale.",
            },
        ],
    },
]


async def seed() -> None:
    async with AsyncSessionLocal() as db:
        result = await db.execute(
            text("SELECT id FROM colleges WHERE college_ref_id = :ref"),
            {"ref": COLLEGE_REF_ID},
        )
        existing = result.scalar_one_or_none()
        if existing:
            print(f"✅ Seed déjà présent (college_ref_id={COLLEGE_REF_ID})")
            print(f"   Interface testeur → http://localhost/tester")
            print(f"   Interface admin   → http://localhost/v1/admin/")
            return

        total_cards = sum(len(item["cards"]) for item in ITEMS)

        # users : id, email, hashed_password, is_beta, is_subscribed, monthly_reloads, created_at
        user_id = uuid.uuid4()
        await db.execute(
            text(
                "INSERT INTO users (id, email, hashed_password, is_beta, is_subscribed, monthly_reloads, created_at) "
                "VALUES (:id, :email, 'seed', true, false, 0, now())"
            ),
            {"id": str(user_id), "email": "dev@seed.local"},
        )

        # colleges : id, user_id, college_ref_id, status, reload_count, ocr_page_progress, total_pages, created_at, updated_at
        college_id = uuid.uuid4()
        await db.execute(
            text(
                "INSERT INTO colleges (id, user_id, college_ref_id, status, reload_count, ocr_page_progress, total_pages, created_at, updated_at) "
                "VALUES (:id, :user_id, :ref, 'generation_complete', 0, 12, 12, now(), now())"
            ),
            {"id": str(college_id), "user_id": str(user_id), "ref": COLLEGE_REF_ID},
        )

        # generation_jobs : id, college_id, user_id, status, card_count, hash_shared, created_at, updated_at
        job_id = uuid.uuid4()
        await db.execute(
            text(
                "INSERT INTO generation_jobs (id, college_id, user_id, status, card_count, hash_shared, created_at, updated_at) "
                "VALUES (:id, :college_id, :user_id, 'generation_complete', :count, false, now(), now())"
            ),
            {"id": str(job_id), "college_id": str(college_id), "user_id": str(user_id), "count": total_cards},
        )

        # items : id, college_id, item_number, rang, chapter_title, ocr_text, ocr_confidence_score, low_confidence, created_at
        # flash_cards : id, item_id, college_id, user_id, card_type, rang, recto, verso, ocr_confidence_score, low_confidence, created_at, updated_at
        for item_data in ITEMS:
            item_id = uuid.uuid4()
            await db.execute(
                text(
                    "INSERT INTO items (id, college_id, item_number, rang, chapter_title, "
                    "ocr_text, ocr_confidence_score, low_confidence, created_at) "
                    "VALUES (:id, :college_id, :num, :rang, :title, :ocr, :score, :low, now())"
                ),
                {
                    "id": str(item_id),
                    "college_id": str(college_id),
                    "num": item_data["item_number"],
                    "rang": item_data["rang"],
                    "title": item_data["chapter_title"],
                    "ocr": "[seed]",
                    "score": item_data["ocr_confidence_score"],
                    "low": item_data["low_confidence"],
                },
            )

            for card_data in item_data["cards"]:
                await db.execute(
                    text(
                        "INSERT INTO flash_cards (id, item_id, college_id, user_id, card_type, rang, "
                        "recto, verso, ocr_confidence_score, low_confidence, created_at, updated_at) "
                        "VALUES (:id, :item_id, :college_id, :user_id, :type, :rang, "
                        ":recto, :verso, :score, :low, now(), now())"
                    ),
                    {
                        "id": str(uuid.uuid4()),
                        "item_id": str(item_id),
                        "college_id": str(college_id),
                        "user_id": str(user_id),
                        "type": card_data["card_type"],
                        "rang": card_data["rang"],
                        "recto": card_data["recto"],
                        "verso": card_data["verso"],
                        "score": card_data.get("ocr_confidence_score", item_data["ocr_confidence_score"]),
                        "low": card_data.get("low_confidence", False),
                    },
                )

        await db.commit()

        print(f"✅ Seed terminé !")
        print(f"   College : Item 45 — Douleur thoracique aiguë")
        print(f"   Items   : {len(ITEMS)} (rang A / B / C)")
        print(f"   Fiches  : {total_cards} flash cards")
        print()
        print(f"   Interface testeur → http://localhost/tester  (tester / tester-dev-password)")
        print(f"   Interface admin   → http://localhost/v1/admin/ (admin / admin-dev-password)")


if __name__ == "__main__":
    asyncio.run(seed())
