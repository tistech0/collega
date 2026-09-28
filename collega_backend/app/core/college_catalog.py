"""GÉNÉRÉ par scripts/gen_admin_assets.py depuis collega_app/.../college_catalog.dart.

Ne pas modifier à la main."""

COLLEGE_NAMES: dict[int, str] = {
    1: "Anatomie pathologique",
    2: "Anesthésie-Réanimation",
    3: "Cancérologie",
    4: "Cardiologie",
    5: "Chirurgie générale, viscérale et digestive",
    6: "Chirurgie maxillo-faciale et stomatologie",
    7: "Dermatologie",
    8: "Douleur, soins palliatifs et accompagnement",
    9: "Endocrinologie, diabétologie",
    10: "Gériatrie",
    11: "Gynécologie-Obstétrique",
    12: "Hématologie",
    13: "Hépato-Gastro-Entérologie",
    14: "Imagerie médicale",
    15: "Immunopathologie",
    16: "Infectiologie",
    17: "Médecine d'urgence",
    18: "Médecine du travail",
    19: "Médecine et chirurgie vasculaire",
    20: "Médecine intensive – Réanimation",
    21: "Médecine interne",
    22: "Médecine légale",
    23: "Médecine physique et de réadaptation",
    24: "Néphrologie",
    25: "Neurochirurgie",
    26: "Neurologie",
    27: "Nutrition",
    28: "Ophtalmologie",
    29: "ORL et chirurgie cervico-faciale",
    30: "Orthopédie-Traumatologie",
    31: "Parasitoses et Mycoses",
    32: "Pédiatrie",
    33: "Pharmacologie",
    34: "Pneumologie",
    35: "Psychiatrie",
    36: "Rhumatologie",
    37: "Santé publique",
    38: "Sémiologie clinique",
    39: "Urologie",
}


def college_name(ref_id: int) -> str:
    return COLLEGE_NAMES.get(ref_id, f"Collège n°{ref_id}")
