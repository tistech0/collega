---
stepsCompleted: [1, 2, 3, 4]
inputDocuments: ['docs/superpowers/specs/2026-04-25-appmedecine-design.md']
session_topic: 'Re-challenger le design complet d AppMédecine'
session_goals: 'Valider ou challenger les choix techniques, UX, économiques et de scope de la v1'
selected_approach: 'ai-recommended'
techniques_used: ['Assumption Reversal', 'First Principles Thinking', 'Six Thinking Hats']
ideas_generated: [19]
context_file: 'docs/superpowers/specs/2026-04-25-appmedecine-design.md'
session_active: false
workflow_completed: true
---

# Résultats de la session de Brainstorming — AppMédecine

**Facilitateur :** Lesurmatthis
**Date :** 2026-04-25

---

## Aperçu de la Session

**Sujet :** Re-challenger le design complet d'AppMédecine
**Objectifs :** Valider ou challenger les choix techniques (Flutter/Isar/FastAPI), UX (flux OCR, quizzes, planning), économiques (10€/mois, in-app purchase) et de scope de la v1
**Approche :** Techniques recommandées par IA
**Techniques utilisées :** Assumption Reversal → First Principles Thinking → Six Thinking Hats
**Contexte :** Design spec AppMédecine v1 — Flutter/FastAPI/PostgreSQL, 40 collèges médicaux, OCR local, génération de quizzes via Claude API, planning ECN, 10€/mois

---

## Sélection des Techniques

**Approche :** AI-Recommended — séquence déconstruction → reconstruction → validation

- **Assumption Reversal :** Identifier et renverser toutes les hypothèses implicites du design spec
- **First Principles Thinking :** Reconstruire à partir des vérités fondamentales sur les besoins ECN réels
- **Six Thinking Hats :** Valider systématiquement chaque décision depuis 6 perspectives complémentaires

---

## Hypothèses Challengées

| Hypothèse de la spec originale | Verdict | Décision |
|---|---|---|
| Tout le contenu reste 100% local | ❌ Invalidée | Seuls les PDFs restent locaux — tout le reste dans le cloud |
| Isar DB est nécessaire | ❌ Invalidée | Oversized — SQLite/drift ou fichier simple suffit |
| Texte OCR stocké en local | ❌ Invalidée | Stream vers backend, stocké par user dans PostgreSQL |
| Détection des chapitres en local | ❌ Invalidée | Mieux fait par Claude côté backend (formats hétérogènes) |
| Abonnement 10€/mois | ❌ Invalidée | → ~100€/an facturé ~9€/mois |
| Cible 4ème-5ème année uniquement | ❌ Invalidée | → Dès la 2ème année, sans changement produit |
| Portail web hors scope v1 | ✅ Confirmée | Hors scope même V2 — usage exclusivement mobile |
| PostgreSQL insuffisant pour la recherche | ❌ Invalidée | GIN index + partition par user_id largement suffisant |
| Planning initial nécessite un LLM | ✅ Confirmée | Algo local suffisant pour le planning initial |
| Import individuel = contrainte technique | ✅ Confirmée | Contrainte légale légitime (droits d'auteur) |

---

## Idées Générées

### Thème 1 — Architecture & Données

**[Architecture #1] : Stockage hybride PDFs local / tout le reste cloud**
*Concept :* Les PDFs bruts restent sur l'appareil (trop lourds, 300-1000 pages × 40 collèges). Le texte OCR, les cards, la progression et l'historique sont dans PostgreSQL sous le compte de l'étudiant. Isar DB n'est plus nécessaire.
*Nouveauté :* Simplifie radicalement l'architecture locale sans compromettre la confidentialité des PDFs.

**[Architecture #2] : Texte OCR éphémère + quizzes permanents**
*Concept :* Le texte OCR transite par le backend le temps que Claude génère les cards, puis est supprimé. Seules les cards (œuvre dérivée transformative) sont conservées. Le texte OCR per-user est stocké séparément pour alimenter la recherche full-text.
*Nouveauté :* Position légale propre — on ne stocke pas le contenu copyrighted, uniquement une dérivée et le texte de l'utilisateur lui-même.

**[Architecture #3] : Hash-sharing des quizzes entre abonnés**
*Concept :* Avant de lancer l'OCR, le backend calcule un hash du PDF. Si ce hash existe déjà (même édition du même collège), les quizzes sont servis immédiatement sans nouveau traitement Claude. L'étudiant reste l'importateur de son propre PDF — on ne distribue rien.
*Nouveauté :* Une cohorte annuelle (~100 étudiants/an sur la même édition) = un seul traitement Claude pour tous. Coût quasi nul dès le 2ème abonné.

**[Architecture #4] : Détection des items par Claude côté backend**
*Concept :* Au lieu d'un algorithme local de détection des titres (fragile sur 40 formats hétérogènes), le texte OCR streame vers le backend et Claude identifie les limites de chapitres. Plus robuste, plus flexible.
*Nouveauté :* Élimine une source majeure d'erreurs de découpage sans complexité côté app.

**[Architecture #5] : PostgreSQL + GIN index pour la recherche full-text**
*Concept :* Le texte OCR de chaque étudiant est indexé dans PostgreSQL avec un index GIN sur un champ tsvector, partitionné par user_id. Toutes les requêtes de recherche sont scopées à un seul utilisateur (~60MB de texte max).
*Nouveauté :* Elasticsearch inutile à cette échelle. PostgreSQL gère confortablement jusqu'à 10 000+ étudiants sans infrastructure supplémentaire.

**[Architecture #6] : Queue asynchrone pour la génération Claude**
*Concept :* Les demandes de génération entrent dans une queue backend. Si Claude est indisponible, la queue attend et reprend automatiquement. L'étudiant voit "tes quizzes sont en cours de génération" plutôt qu'une erreur.
*Nouveauté :* Découple l'expérience utilisateur de la disponibilité temps-réel de l'API.

---

### Thème 2 — Modèle Économique & Marché

**[Éco #1] : ~100€/an facturé ~9€/mois**
*Concept :* Engagement annuel avec étalement mensuel. Sous le seuil psychologique des 10€, engagement plus fort qu'un mensuel pur, meilleur LTV, revenu prévisible.
*Nouveauté :* Aligne le modèle de revenu sur le cycle de vie réel de l'utilisateur ECN (1-3 ans de préparation).

**[Éco #2] : Cible élargie dès la 2ème année de médecine**
*Concept :* Les collèges sont utilisés dès la 2ème année. Sans aucun changement produit, l'app est pertinente pour les étudiants de 2ème à 6ème année. Repositionnement marketing uniquement.
*Nouveauté :* Marché adressable multiplié par 2-3, LTV par étudiant doublé ou triplé.

**[Éco #3] : Cercle vertueux de cohorte**
*Concept :* Plus il y a d'abonnés sur une même promo, plus le hash-sharing réduit les coûts de traitement, plus la marge est forte. Le premier adoptant dans une promo entraîne les suivants — et chaque nouvel abonné coûte moins cher à servir.
*Nouveauté :* Dynamique de réseau dans un produit d'apprentissage individuel.

---

### Thème 3 — Différenciateurs Produit

**[Produit #1] : 3 types de cards générées par Claude**
*Concept :* Claude génère automatiquement 3 formats selon le contenu détecté :
- **Flashcard classique** — Recto/Verso, avec ou sans Chain de raisonnement
- **Phrase à compléter** — Mots-clés masqués, réponse par liste déroulante ou saisie libre
- **Définition + reconnaissance** — L'étudiant écrit ou dicte la définition, Claude évalue la proximité sémantique (pas de correspondance exacte exigée)
L'étudiant choisit son format préféré dans les paramètres.
*Nouveauté :* Variété pédagogique vs. Anki qui impose un format unique. La dictée est particulièrement utile entre deux stages.

**[Produit #2] : Flashcard Chains — raisonnement clinique séquentiel**
*Concept :* Claude génère des séquences de 5-10 cards qui suivent un raisonnement clinique complet : symptômes → diagnostic différentiel → examens → traitement → suivi. Chaque card s'appuie sur la précédente. Étudiable en mode chain complète ou card par card en spaced repetition.
*Nouveauté :* Aligne le format d'apprentissage sur le format réel de l'ECN (dossiers progressifs). Aucun concurrent ne propose ça.

**[Produit #3] : Mode drill vs mode raisonnement**
*Concept :* Mode drill = cards isolées en spaced repetition rapide pour ancrer les faits Rang A/B. Mode raisonnement = chains complètes pour construire le raisonnement clinique de A à Z.
*Nouveauté :* Un seul contenu généré, deux expériences d'étude adaptées à la phase de préparation de l'étudiant.

**[Produit #4] : Mode "je viens de voir ce cas en stage"**
*Concept :* Bouton rapide — l'étudiant tape un symptôme ou une pathologie vue en stage ("dyspnée", "BNP élevé"), retrouve l'item correspondant via la recherche full-text, lance une session de révision immédiate. Le planning s'ajuste automatiquement pour tenir compte de cette révision.
*Nouveauté :* Exploite le pic de motivation contextuel du stage clinique. Connecte l'apprentissage théorique à l'expérience clinique réelle — aucun concurrent ne fait ce lien.

**[Produit #5] : Ancres épisodiques — souvenirs cliniques attachés aux items**
*Concept :* Sur chaque item, l'étudiant peut noter une anecdote de stage : "M. Dupont, 72 ans, IC décompensée après arrêt des diurétiques, vu le 15 mars". Note privée, visible pendant les révisions.
*Nouveauté :* Exploite la mémoire épisodique — scientifiquement la forme de mémoire la plus durable. Un fait médical associé à un vrai patient est retenu 3-5× mieux. Irremplaçable par un deck Anki partagé.
*Note :* Feature secondaire — non mise en avant dans l'onboarding principal, découvrable progressivement.

**[Produit #6] : L'app comme journal de l'externat**
*Concept :* Au bout d'un an, l'étudiant a non seulement ses quizzes — il a un carnet de bord de son externat entier. Chaque pathologie vue en vrai est ancrée dans l'app. Objet de valeur au-delà de la préparation ECN.
*Nouveauté :* Rétention émotionnelle forte. On n'efface pas son journal clinique. Le churn s'effondre.

**[Produit #7] : Score de confiance OCR**
*Concept :* iOS Vision et Android ML Kit retournent un score de confiance par token. Le backend calcule un score moyen par item. En dessous d'un seuil : badge "source peu lisible" sur les cards concernées. Au-dessus : rien.
*Nouveauté :* L'étudiant sait quand vérifier dans le PDF original. Évite de mémoriser des informations erronées issues d'un OCR dégradé.

**[Produit #8] : Onboarding par un cas clinique réel**
*Concept :* L'onboarding démarre avec un cas simulé — "tu es en stage de cardio, tu viens de voir un patient en IC" — et montre en live comment l'app lie le cas à l'item, génère une chain, lance une révision. Valeur démontrée en 60 secondes.
*Nouveauté :* Démontre immédiatement le différenciateur principal (lien stage-révision) avant même le premier paiement.

**[Produit #9] : LLM pour le re-planning adaptatif uniquement**
*Concept :* Le planning initial reste un algorithme déterministe local (priorité A→B→C, répartition sur les jours). Après 2 semaines de données réelles, Claude intervient ponctuellement pour proposer des ajustements : "tu maîtrises la Cardio Rang A plus vite que prévu — réallouer ces jours sur la Neuro Rang B ?"
*Nouveauté :* LLM uniquement là où le jugement contextuel remplace l'algo. Pas de surcoût au démarrage.

**[Produit #10] : Recherche full-text multi-collèges**
*Concept :* L'étudiant recherche "BNP", "crépitants" ou "dyspnée" à travers ses 40 collèges. Résultats avec passage en contexte et chapitre source. Alimenté par PostgreSQL + GIN index. Connexion requise. Point d'entrée naturel pour le mode stage.
*Nouveauté :* Transforme la recherche en outil clinique quotidien, pas juste une fonction de navigation.

---

## Organisation et Priorisation

### MVP Phase 1 — Beta (3 collèges)

| Priorité | Feature | Impact | Notes |
|---|---|---|---|
| 🔴 Critique | Auth / compte étudiant | Fondation | Simple à implémenter |
| 🔴 Critique | 40 collèges prédéfinis dans l'app | Fondation | Liste fixe |
| 🔴 Critique | Import PDF → OCR background → stream backend | Core | Tâche de fond, reprend si interrompue |
| 🔴 Critique | Génération flashcards classiques via Claude | Core | JSON structuré, taggé Rang A/B/C |
| 🔴 Critique | Sessions quiz en spaced repetition (3 niveaux) | Core | À revoir / Bien / Maîtrisé |
| 🔴 Critique | Planning d'apprentissage algorithmique local | Core | Priorité A→B→C, jours dispo |
| 🔴 Critique | Recherche full-text multi-collèges | Différenciateur | PostgreSQL GIN index |
| 🟠 Important | Score de confiance OCR | Qualité | Badge warning si OCR dégradé |
| 🟠 Important | Définition + reconnaissance sémantique | Pédagogie | 2ème type de card |

### Post-MVP — Phase 2

| Priorité | Feature | Notes |
|---|---|---|
| 🟡 Valeur | Flashcard Chains | Différenciateur vs Anki |
| 🟡 Valeur | Mode "je viens de voir ce cas en stage" | Différenciateur acquisition #1 |
| 🟡 Valeur | Hash-sharing des quizzes | Rentabilité à l'échelle |
| 🟡 Valeur | Phrase à compléter + dictée | 3ème type de card |
| 🟡 Valeur | LLM pour re-planning adaptatif | Après 2 semaines de données |
| 🟢 Long terme | Ancres épisodiques (journal de stage) | Rétention émotionnelle |
| 🟢 Long terme | Onboarding par cas clinique simulé | Conversion |

### Hors scope confirmé

- Portail web (même V2) — usage exclusivement mobile
- QCM / dossiers progressifs ECN — V2
- Synchronisation cross-device — natif avec l'architecture cloud

---

## Points d'Action Immédiats

1. **Faire 5-10 entretiens utilisateurs** — valider le mode "stage" et la recherche full-text avec de vrais étudiants. C'est la connaissance manquante la plus critique.
2. **Mettre à jour la spec technique** — refléter la nouvelle architecture (pas d'Isar, OCR éphémère, PostgreSQL pour search et cards, hash-sharing).
3. **Valider le pricing** — tester 99€/an facturé 9,17€/mois vs 59€/an avec quelques étudiants cibles.
4. **Prototype OCR pipeline** — valider la qualité de la détection d'items par Claude sur 3 collèges réels avant de builder le reste.

---

## Insights Clés de la Session

**Insight #1 — Le "tout local" était une généralisation d'une contrainte réelle**
Seuls les PDFs justifient le stockage local (poids). Cette généralisation a entraîné le choix d'Isar DB, l'absence de search cloud, et l'exclusion du portail web — tous des choix qui se défont une fois la contrainte bien délimitée.

**Insight #2 — Le différenciateur n'est pas la génération de cards**
La génération automatique de flashcards est la proposition de valeur évidente. Le vrai différenciateur est le lien stage clinique → révision théorique — quelque chose qu'aucun concurrent (Anki, decks partagés) ne peut proposer par définition car c'est personnel.

**Insight #3 — L'app a deux modes de valeur distincts**
Acquisition : "je viens de voir ce cas, je veux réviser maintenant" — valeur immédiate, démontrée en 60 secondes.
Rétention : journal de stage, ancres épisodiques, progression personnelle — valeur cumulée sur 1-3 ans, irremplaçable.

**Insight #4 — Le modèle économique sous-estimait la valeur**
10€/mois venait d'une estimation de coût, pas d'une analyse de valeur. Le retour utilisateur suggère que 100€/an est acceptable — voire que c'est encore sous la valeur perçue pour quelqu'un qui prépare un concours déterminant pour sa carrière.

---

*Session facilitée avec les techniques : Assumption Reversal · First Principles Thinking · Six Thinking Hats*
*19 idées générées · 10 hypothèses challengées · 4 thèmes identifiés*
