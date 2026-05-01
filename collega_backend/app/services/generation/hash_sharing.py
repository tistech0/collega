from __future__ import annotations

import hashlib
from abc import ABC, abstractmethod
from typing import Optional

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.generation_job import GenerationJob


class SimilarityChecker(ABC):
    @abstractmethod
    def compute_hash(self, pdf_path: str) -> str: ...

    @abstractmethod
    async def find_similar_job(self, db: AsyncSession, pdf_hash: str) -> Optional[GenerationJob]: ...


class SHA256SimilarityChecker(SimilarityChecker):
    def compute_hash(self, pdf_path: str) -> str:
        h = hashlib.sha256()
        with open(pdf_path, "rb") as f:
            for chunk in iter(lambda: f.read(65536), b""):
                h.update(chunk)
        return h.hexdigest()

    async def find_similar_job(self, db: AsyncSession, pdf_hash: str) -> Optional[GenerationJob]:
        result = await db.execute(
            select(GenerationJob)
            .where(GenerationJob.pdf_hash == pdf_hash)
            .where(GenerationJob.status == "generation_complete")
            .order_by(GenerationJob.created_at.desc())
            .limit(1)
        )
        return result.scalar_one_or_none()
