"""Pages publiques (confidentialité, CGU, support) exigées par App Store Connect.

Les textes sont les mêmes Markdown que ceux de l'app (copiés dans
`app/static/legal/`, un test vérifie qu'ils restent identiques)."""

from __future__ import annotations

from functools import cache
from html import escape
from pathlib import Path

from markdown_it import MarkdownIt

LEGAL_DIR = Path(__file__).resolve().parents[1] / "static" / "legal"
CONTACT = "contact@matthislesur.com"

_SUPPORT_MD = f"""# Support Collega

Collega est éditée par **Matthis Lesur**.

Une question, un bug, un collège qui s'importe mal : écris à [{CONTACT}](mailto:{CONTACT}).
Indique si possible l'adresse e-mail de ton compte Collega et le collège concerné.

- [Politique de confidentialité](/legal/privacy)
- [Conditions générales d'utilisation](/legal/terms)
"""

# HTML brut désactivé : le Markdown est rendu tel quel, sans balise injectée.
_md = MarkdownIt("commonmark", {"html": False}).enable("table")

_TEMPLATE = """<!doctype html>
<html lang="fr">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>{title} · Collega</title>
<style>
body {{ font: 16px/1.6 -apple-system, system-ui, sans-serif; max-width: 720px;
  margin: 0 auto; padding: 24px 16px; color: #1c1c1e; background: #fff; }}
table {{ border-collapse: collapse; width: 100%; font-size: 14px; }}
th, td {{ border: 1px solid #d1d1d6; padding: 6px 8px; text-align: left; vertical-align: top; }}
a {{ color: #0a60c2; }}
@media (prefers-color-scheme: dark) {{
  body {{ color: #f2f2f7; background: #111; }} th, td {{ border-color: #3a3a3c; }} a {{ color: #6cb4ff; }}
}}
</style>
</head>
<body>
{body}
<hr>
<p>Contact : <a href="mailto:{contact}">{contact}</a></p>
</body>
</html>
"""


def _render(title: str, markdown: str) -> str:
    return _TEMPLATE.format(title=escape(title), body=_md.render(markdown), contact=CONTACT)


@cache
def privacy_page() -> str:
    return _render("Politique de confidentialité", (LEGAL_DIR / "privacy.md").read_text(encoding="utf-8"))


@cache
def terms_page() -> str:
    return _render("Conditions générales d'utilisation", (LEGAL_DIR / "cgu.md").read_text(encoding="utf-8"))


@cache
def support_page() -> str:
    return _render("Support", _SUPPORT_MD)
