"""Génère, depuis l'app Flutter (source de vérité), les assets partagés avec la console admin.

- app/core/college_catalog.py : noms des collèges par college_ref_id ;
- app/static/admin/js/icons.js : icônes CgIcons (trait en currentColor).

Usage : python -m scripts.gen_admin_assets [--check]
"""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path

BACKEND = Path(__file__).resolve().parents[1]
APP = BACKEND.parent / "collega_app"
ICONS_DART = APP / "lib/core/ui/foundation/cg_icon.dart"
CATALOG_DART = APP / "lib/features/colleges/domain/college_catalog.dart"
CATALOG_PY = BACKEND / "app/core/college_catalog.py"
ICONS_JS = BACKEND / "app/static/admin/js/icons.js"

# Nom entre guillemets simples ou doubles (l'app utilise des doubles quand le nom contient une apostrophe).
_NAME_RE = re.compile(r"refId:\s*(\d+),\s*name:\s*(['\"])((?:\\.|(?!\2).)*)\2")


def _icons_js() -> str:
    source = ICONS_DART.read_text(encoding="utf-8")
    icons = re.findall(r"static const (\w+) = '(<svg.*?</svg>)';", source)
    lines = []
    for name, svg in icons:
        current_color = svg.replace('stroke="#000"', 'stroke="currentColor"')
        lines.append(f"  {name}: '{current_color}',")
    return (
        "// GÉNÉRÉ par scripts/gen_admin_assets.py depuis collega_app/lib/core/ui/foundation/cg_icon.dart.\n"
        "// Ne pas modifier à la main.\n"
        "export const ICONS = {\n" + "\n".join(lines) + "\n};\n"
    )


def _catalog_py() -> str:
    source = CATALOG_DART.read_text(encoding="utf-8")
    entries = _NAME_RE.findall(source)
    body = "\n".join(f"    {int(ref)}: {json.dumps(name, ensure_ascii=False)}," for ref, _quote, name in entries)
    return (
        '"""GÉNÉRÉ par scripts/gen_admin_assets.py depuis collega_app/.../college_catalog.dart.\n\n'
        'Ne pas modifier à la main."""\n\n'
        "COLLEGE_NAMES: dict[int, str] = {\n" + body + "\n}\n\n\n"
        "def college_name(ref_id: int) -> str:\n"
        '    return COLLEGE_NAMES.get(ref_id, f"Collège n°{ref_id}")\n'
    )


def generated_files() -> list[tuple[Path, str]]:
    return [(CATALOG_PY, _catalog_py()), (ICONS_JS, _icons_js())]


def main(argv: list[str] | None = None) -> int:
    check = "--check" in (argv if argv is not None else sys.argv[1:])
    stale = []
    for path, content in generated_files():
        current = path.read_text(encoding="utf-8") if path.exists() else None
        if current == content:
            continue
        if check:
            stale.append(path)
        else:
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(content, encoding="utf-8")
            print(f"écrit : {path.relative_to(BACKEND)}")
    for path in stale:
        print(f"pas à jour : {path.relative_to(BACKEND)}", file=sys.stderr)
    return 1 if stale else 0


if __name__ == "__main__":
    raise SystemExit(main())
