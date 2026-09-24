# Chantier 4 — mesures (2026-09-24)

Image de test `c4smoke-aabd67f` (branche `feat/chantier-4-segmentation` + chantier 2), exécutée sur le NAS avec la clé de prod, sur les textes de pages exportés de la prod avant le vidage. Découpage : nouveau détecteur (24 / 20 / 21 items, 65/65 conformes à la vérité terrain).

## Découpage avant / après

| collège | items exacts avant (prod) | items exacts après | pages de contenu jamais envoyées à Claude avant |
|---|---:|---:|---:|
| 3 CANCÉRO 4e | 1/24 | 24/24 | 272 |
| 12 HÉMATO 5e | 10/20 (faux items 21 et 31) | 20/20 | 19 perdues + 27 hors item dans 329 |
| 34 PNEUMO 8e | 21/21 | 21/21 | 0 |

Mots à l'envers dans les tableaux pivotés (hémato) : 1 412 → 0.

## Tokens d'entrée (count_tokens, claude-sonnet-5)

| collège | items | caractères brut | caractères allégé | tokens brut | tokens allégé | réduction tokens |
|---|---:|---:|---:|---:|---:|---:|
| collège 3 | 24 | 1017737 | 994608 | 475955 | 463197 | 2.7 % |
| collège 12 | 20 | 945982 | 893772 | 447632 | 419180 | 6.4 % |
| collège 34 | 21 | 724248 | 652145 | 347264 | 310431 | 10.6 % |
| **total** | 65 | 2687967 | 2540525 | 1270851 | 1192808 | 6.1 % |

## Contrôle de fumée (claude-sonnet-5, prompt p2)

| collège | item | pages | caractères | effort | fiches | par rang | par type | tokens entrée | tokens sortie | coût € | insuffisant | stop_reason | durée s | nombres hors source |
|---|---:|---:|---:|---|---:|---|---|---:|---:|---:|---|---|---:|---:|
| 3 | 304 | 19 | 44004 | low | 26 | A 10 B 16 | classique 25 definition 1 | 20702 | 3521 | 0.0705 | non | end_turn | 32.9 | 1 |
| 3 | 304 | 19 | 44004 | medium | 39 | A 11 B 28 | classique 36 definition 3 | 20702 | 5934 | 0.0927 | non | end_turn | 52.7 | 1 |
| 12 | 329 | 39 | 115734 | low | 39 | A 30 B 9 | classique 31 definition 6 cas_clinique 2 | 53935 | 4292 | 0.1387 | non | end_turn | 39.7 | 1 |
| 12 | 329 | 39 | 115734 | medium | 40 | A 28 B 12 | classique 33 definition 7 | 53935 | 5856 | 0.1531 | non | end_turn | 54.4 | 1 |
| 34 | 75 | 13 | 34956 | low | 27 | A 24 B 3 | classique 23 definition 3 cas_clinique 1 | 15929 | 3129 | 0.0581 | non | end_turn | 26.9 | 0 |
| 34 | 75 | 13 | 34956 | medium | 32 | A 24 B 8 | classique 30 definition 2 | 15929 | 3935 | 0.0655 | non | end_turn | 33.8 | 0 |

Coût total € : low 0.2673, medium 0.3113

« Nombres hors source » (vérification automatique) : 2 cas, des variantes d'écriture (« CA 19-9 » / « CA19-9 », virgule décimale), pas d'invention.

**Décision : `effort = "medium"`** (défaut du client). La couverture du rang A est la même qu'en `low` (10/11, 30/28, 24/24 fiches A), mais `medium` ajoute les notions B que le prompt p2 demande ensuite (+50 % de fiches sur l'item 304, +5 sur le 75) pour +16 % de coût. L'item le plus long (329, 116 k caractères) atteint le plafond de 40 fiches.

**Estimation pour réimporter les 3 collèges** : ≈ 1,19 M tokens d'entrée (2,4 $) + ≈ 65 × 5 k tokens de sortie (≈ 3,3 $) → **≈ 5-6 € au total**, contre 8 fiches par item avant. Concurrence 4 : aucun 429 observé (appels séquentiels dans le contrôle ; à surveiller au réimport).
