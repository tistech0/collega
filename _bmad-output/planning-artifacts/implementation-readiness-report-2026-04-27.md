---
date: 2026-04-27
project: appMedecine
stepsCompleted: ["step-01-document-discovery", "step-02-prd-analysis", "step-03-epic-coverage-validation", "step-04-ux-alignment", "step-05-epic-quality-review", "step-06-final-assessment"]
status: complete
documentsInventoried:
  prd: "_bmad-output/planning-artifacts/prd.md"
  architecture: "_bmad-output/planning-artifacts/architecture.md"
  epics: "_bmad-output/planning-artifacts/epics.md"
  ux: "_bmad-output/planning-artifacts/ux-design-specification.md"
---

# Implementation Readiness Assessment Report

**Date:** 2026-04-27
**Project:** appMedecine

---

## Section 1 — Inventaire des Documents

### Documents PRD

**Documents complets :**
- `prd.md` (25 815 octets, modifié le 26 avr. 12:17)

**Documents fragmentés :** Aucun

---

### Documents Architecture

**Documents complets :**
- `architecture.md` (23 365 octets, modifié le 26 avr. 21:11)

**Documents fragmentés :** Aucun

---

### Documents Épics & Stories

**Documents complets :**
- `epics.md` (65 235 octets, modifié le 27 avr. 09:12)

**Documents fragmentés :** Aucun

---

### Documents UX Design

**Documents complets :**
- `ux-design-specification.md` (48 347 octets, modifié le 26 avr. 17:33)

**Documents fragmentés :** Aucun

**Ressources supplémentaires :**
- `screens/` — maquettes HTML (college-detail, colleges, drill, home, import-progress, item-detail, profile, search, session-personnalisation, session-terminee)
- `ux-design-directions.html` — directions de design (HTML)

---

### Problèmes identifiés

Aucun doublon détecté. Tous les documents requis sont présents.

---

## Section 2 — Analyse PRD

### Exigences Fonctionnelles (FR)

**Onboarding & Accès**
- FR1 : L'utilisateur peut explorer l'app via une démo interactive avec un collège fictif et des fiches pré-chargées, sans créer de compte.
- FR2 : L'utilisateur peut ignorer la démo et accéder directement à l'inscription.
- FR3 : L'utilisateur peut créer un compte avec email et mot de passe.
- FR4 : L'utilisateur peut souscrire à un abonnement payant via l'in-app purchase App Store.
- FR5 : L'utilisateur ne peut pas accéder aux fonctionnalités principales sans abonnement actif.
- FR6 : L'utilisateur peut consulter le prix et la durée d'abonnement avant de confirmer l'achat.

**Gestion des Collèges & Import**
- FR7 : L'utilisateur peut consulter la liste des 40 collèges médicaux prédéfinis dans l'app.
- FR8 : L'utilisateur peut importer un fichier PDF depuis son stockage local dans un collège sélectionné.
- FR9 : Le système extrait le texte de chaque page d'un PDF via OCR en tâche de fond, sans bloquer l'interface.
- FR10 : Le système reprend automatiquement le traitement OCR si interrompu.
- FR11 : Le système calcule un score de confiance OCR par item et affiche un badge d'alerte si la qualité est insuffisante.
- FR12 : Le système détecte automatiquement les items et chapitres du PDF côté backend.
- FR13 : L'utilisateur peut suivre la progression de l'import et de la génération en temps réel.
- FR14 : L'utilisateur peut re-importer un collège dans la limite de 2 re-traitements par collège et 3 re-traitements par mois. Le premier import est libre.
- FR15 : Le système bloque gracieusement les re-traitements au-delà des limites et informe l'utilisateur de la date de réinitialisation.

**Génération & Gestion des Fiches**
- FR16 : Le système génère des flashcards classiques (recto/verso) et des fiches définition à partir du texte OCR via l'API Claude.
- FR17 : Le système tague automatiquement chaque fiche avec le rang de l'item source (A, B ou C).
- FR18 : Le système détecte si un PDF importé correspond à un traitement existant et sert les fiches sans nouvel appel Claude (hash-sharing).
- FR19 : L'utilisateur peut signaler une fiche comme pertinente ou non pertinente.
- FR20 : L'utilisateur peut déclencher la régénération d'une fiche signalée négativement, avec le feedback transmis en contexte à Claude.
- FR21 : L'utilisateur peut supprimer une fiche jugée non pertinente.
- FR22 : Le système synchronise automatiquement les fiches générées en cache local sur l'appareil.
- FR23 : L'utilisateur reçoit une notification push à la fin de la génération d'un collège.

**Révision & Apprentissage**
- FR24 : L'utilisateur peut lancer une session de quiz (Mode Drill) en sélectionnant collèges, items et rangs.
- FR25 : Le système présente les fiches en spaced repetition à 3 niveaux (À revoir / Bien / Maîtrisé).
- FR26 : L'utilisateur évalue chaque fiche selon son niveau de mémorisation.
- FR27 : Le système ajuste la fréquence de présentation selon le niveau déclaré.
- FR28 : L'utilisateur accède aux fiches générées et lance des sessions de quiz sans connexion internet.
- FR29 : Le système évalue la réponse à une fiche définition par proximité sémantique plutôt que correspondance textuelle exacte.
- FR30 : L'utilisateur configure un planning d'apprentissage en sélectionnant collèges, items, dates et disponibilité quotidienne.
- FR31 : Le système génère un planning algorithmique local, priorisé par rang (A→B→C).
- FR32 : L'utilisateur consulte sa session du jour (items, rangs, nombre de fiches).
- FR33 : L'utilisateur marque une session comme effectuée ou la décale.
- FR34 : L'utilisateur consulte sa progression par collège et par rang.
- FR35 : L'utilisateur configure un rappel quotidien de révision à l'heure de son choix.

**Recherche**
- FR36 : L'utilisateur effectue une recherche full-text sur l'ensemble de ses collèges importés.
- FR37 : Le système affiche les résultats avec le passage contextuel et le chapitre source.
- FR38 : L'utilisateur lance une session de révision directement depuis un résultat de recherche.

**Compte & Conformité**
- FR39 : L'utilisateur supprime son compte et toutes ses données associées depuis l'app.
- FR40 : L'utilisateur consulte la politique de confidentialité et les CGU depuis l'app.
- FR41 : L'utilisateur accède à la gestion de son abonnement (annulation) depuis les paramètres iOS.
- FR42 : Le système valide le statut d'abonnement actif avant chaque appel à l'API Claude.

**Administration & Opérateur**
- FR43 : L'opérateur consulte l'état de la queue de génération (traitements en attente, statut, temps).
- FR44 : L'opérateur gère les accès beta (accès gratuit sans abonnement).
- FR45 : L'opérateur ajuste les limites anti-spam côté backend sans mise à jour de l'app.
- FR46 : L'opérateur surveille les statuts d'abonnement et les webhooks App Store.
- FR47 : L'opérateur déclenche manuellement la génération d'un collège via une interface admin web sécurisée.
- FR48 : L'opérateur consulte les statistiques de génération : nombre de fiches, score OCR par item, taux de similarité hash-sharing.

**Interface Testeur (Phase 0)**
- FR49 : Le testeur parcourt et interagit avec les fiches d'un collège généré via une interface web (accès restreint).
- FR50 : Le testeur signale chaque fiche comme pertinente ou non (feedback transmis à l'opérateur).

**Total FR : 50**

---

### Exigences Non-Fonctionnelles (NFR)

**Performance**
- NFR1 : Recherche full-text < 1 seconde pour 10 collèges indexés.
- NFR2 : Génération complète d'un collège (OCR → items → fiches) en moins de 2 heures.
- NFR3 : Sessions quiz répondent en moins de 100ms (données locales).
- NFR4 : Démarrage et affichage écran principal en moins de 3 secondes.

**Sécurité**
- NFR5 : Clé API Claude jamais dans le bundle app — exclusivement côté backend.
- NFR6 : Statut abonnement validé côté backend (receipt App Store) avant chaque appel Claude.
- NFR7 : Toutes les communications app ↔ backend en HTTPS.
- NFR8 : Données utilisateur avec accès scopé par user_id — aucune donnée cross-user accessible.
- NFR9 : Texte OCR supprimé du backend après génération — rétention max 24h.

**Fiabilité**
- NFR10 : Si Claude API indisponible, demandes en queue et reprise automatique avec information utilisateur.
- NFR11 : OCR interrompu reprend au dernier point de sauvegarde.
- NFR12 : Panne backend n'empêche pas l'accès aux fiches synchronisées ni les sessions quiz.

**Total NFR : 12**

---

### Exigences Additionnelles (Contraintes & Assumptions)

- **RGPD** : Politique de confidentialité, droit à la suppression, consentement explicite.
- **Copyright** : Import personnel uniquement, OCR éphémère, fiches comme œuvre dérivée transformative.
- **App Store** : Demo accessible sans compte, prix affichés avant achat, politique d'annulation accessible.
- **Plateforme** : iOS 16+ / iPadOS Phase 1, Flutter, BGProcessingTask pour OCR longue durée.
- **Mode hors ligne** : Fiches et quiz disponibles offline ; search, import, génération nécessitent une connexion.
- **Beta** : Limite à 3 collèges importables en phase beta.

---

### Évaluation de Complétude du PRD

Le PRD est **bien structuré et complet** pour une Phase 1. Les 50 FR couvrent tous les parcours utilisateurs décrits. Les 12 NFR adressent les dimensions critiques (performance, sécurité, fiabilité). Les critères de succès sont mesurables et le phasage est clairement défini.

---

## Section 3 — Validation de Couverture des Épics

### Matrice de Couverture FR

| FR | Requirement (résumé) | Couverture Épic | Story | Statut |
|----|----------------------|-----------------|-------|--------|
| FR1 | Démo interactive sans compte | Epic 2 | Story 2.2 | ✓ Couvert |
| FR2 | Skip démo → inscription directe | Epic 2 | Story 2.2 | ✓ Couvert |
| FR3 | Création compte email/mdp | Epic 2 | Story 2.3 | ✓ Couvert |
| FR4 | In-app purchase App Store | Epic 2 | Story 2.4 | ✓ Couvert |
| FR5 | Paywall sans abonnement actif | Epic 2 | Story 2.4 | ✓ Couvert |
| FR6 | Prix/durée affichés avant achat | Epic 2 | Story 2.4 | ✓ Couvert |
| FR7 | Liste des 40 collèges | Epic 3 | Story 3.1 | ✓ Couvert |
| FR8 | Import PDF depuis stockage local | Epic 3 | Story 3.2 | ✓ Couvert |
| FR9 | OCR en tâche de fond | Epic 3 | Story 3.2 | ✓ Couvert |
| FR10 | Reprise OCR si interrompu | Epic 3 | Story 3.2 | ✓ Couvert |
| FR11 | Score confiance OCR + badge | Epic 3 | Story 3.3 | ✓ Couvert |
| FR12 | Détection items/chapitres backend | Epic 3 | Story 1.2 | ✓ Couvert |
| FR13 | Progression import temps réel (SSE) | Epic 3 | Story 3.2 | ✓ Couvert |
| FR14 | Limites reimport (2/collège, 3/mois) | Epic 3 | Story 3.4 | ✓ Couvert |
| FR15 | Blocage gracieux + date réinit | Epic 3 | Story 3.4 | ✓ Couvert |
| FR16 | Génération flashcards + fiches déf. | Epic 3 | Story 3.3 | ✓ Couvert |
| FR17 | Tagging rang A/B/C automatique | Epic 3 | Story 3.3 | ✓ Couvert |
| FR18 | Hash-sharing v1 | Epic 3 | Story 3.4 | ✓ Couvert |
| FR19 | Feedback fiche (pouce haut/bas) | Epic 3 | Story 3.5 | ✓ Couvert |
| FR20 | Régénération fiche avec feedback | Epic 3 | Story 3.5 | ✓ Couvert |
| FR21 | Suppression fiche | Epic 3 | Story 3.5 | ✓ Couvert |
| FR22 | Sync locale automatique (offline-first) | Epic 3 | Story 3.3 | ✓ Couvert |
| FR23 | Push notification "fiches prêtes" | Epic 3 | Story 3.5 | ✓ Couvert |
| FR24 | Lancement session Mode Drill | Epic 4 | Story 4.2 | ✓ Couvert |
| FR25 | Spaced repetition 3 niveaux | Epic 4 | Story 4.2 | ✓ Couvert |
| FR26 | Évaluation fiche par l'étudiant | Epic 4 | Story 4.2 | ✓ Couvert |
| FR27 | Ajustement fréquence de présentation | Epic 4 | Story 4.2 | ✓ Couvert |
| FR28 | Accès fiches + quiz sans internet | Epic 4 | Story 4.2 | ✓ Couvert |
| FR29 | Évaluation sémantique (fiches déf.) | Epic 4 | Story 4.2 | ✓ Couvert |
| FR30 | Configuration planning | Epic 4 | Story 4.4 | ✓ Couvert |
| FR31 | Planning algorithmique local A→B→C | Epic 4 | Story 4.4 | ✓ Couvert |
| FR32 | Session du jour | Epic 4 | Story 4.3 | ✓ Couvert |
| FR33 | Session effectuée / décalée | Epic 4 | Story 4.4 | ✓ Couvert |
| FR34 | Progression par collège et rang | Epic 4 | Story 4.5 | ✓ Couvert |
| FR35 | Rappel quotidien configurable | Epic 4 | Story 4.5 | ✓ Couvert |
| FR36 | Recherche full-text | Epic 5 | Story 5.1 | ✓ Couvert |
| FR37 | Résultats contextuels + chapitre | Epic 5 | Story 5.1 | ✓ Couvert |
| FR38 | Lancement session depuis résultat | Epic 5 | Story 5.2 | ✓ Couvert |
| FR39 | Suppression compte + données (RGPD) | Epic 6 | Story 6.2 | ✓ Couvert |
| FR40 | CGU + politique confidentialité | Epic 6 | Story 6.1 | ✓ Couvert |
| FR41 | Gestion abonnement (annulation iOS) | Epic 6 | Story 6.1 | ✓ Couvert |
| FR42 | Validation abonnement avant Claude | Epic 6 | Story 6.2 | ✓ Couvert |
| FR43 | Monitoring queue génération | Epic 1 | Story 1.4 | ✓ Couvert |
| FR44 | Gestion accès beta | Epic 1 | Story 1.4 | ✓ Couvert |
| FR45 | Limites anti-spam configurables | Epic 1 | Story 1.4 | ✓ Couvert |
| FR46 | Surveillance abonnements + webhooks | Epic 1 | Story 1.4 | ✓ Couvert |
| FR47 | Déclenchement manuel génération | Epic 1 | Story 1.4 | ✓ Couvert |
| FR48 | Stats génération admin | Epic 1 | Story 1.4 | ✓ Couvert |
| FR49 | Interface testeur web | Epic 1 | Story 1.5 | ✓ Couvert |
| FR50 | Feedback testeur par fiche | Epic 1 | Story 1.5 | ✓ Couvert |

### Exigences Manquantes

**Aucun FR manquant.** Tous les 50 FR du PRD sont couverts.

### Statistiques de Couverture

- **Total FR PRD :** 50
- **FR couverts dans les épics :** 50
- **Pourcentage de couverture :** **100%**

---

## Section 4 — Évaluation de l'Alignement UX

### Statut du Document UX

**Trouvé** : `ux-design-specification.md` (48 347 o, modifié le 26 avr. 17:33)
Ressources supplémentaires : 11 maquettes HTML dans `screens/` + `ux-design-directions.html`

---

### Alignement UX ↔ PRD

| Dimension | Résultat |
|-----------|----------|
| Parcours utilisateurs couverts | ✓ Léa, Tom, Camille, Lesurmatthis, Maxime — tous dans la spec UX |
| UX-DR1 à UX-DR18 dans les épics | ✓ Tous listés dans l'inventaire Requirements du fichier epics.md |
| Stratégie offline/online | ✓ Cohérente : révision offline, search/import/génération online |
| Cibles de performance | ✓ NFR1 < 1s, NFR3 < 100ms, NFR4 < 3s — reflétées dans la spec UX |

---

### Alignement UX ↔ Architecture

| Dimension | Résultat |
|-----------|----------|
| Stack UX (shadcn_ui + flutter_animate) | ✓ Explicitement référencée dans l'architecture ("design system décidé en UX") |
| SSE pour progression OCR | ✓ Documenté dans les deux documents — correspond au UX "fiches progressivement" |
| Breakpoint iPad 600px via LayoutBuilder | ✓ Aligné dans spec UX et architecture |
| Riverpod lazy (NFR4 startup) | ✓ Gap résolu dans l'architecture |
| Reprise OCR (NFR11) | ✓ Gap résolu dans l'architecture via `ocr_page_progress` |
| Feature-first + composants custom | ✓ Architecture liste les widgets UX dans la structure de dossiers |

---

### Observations (non bloquantes)

**OBS-1 — Écran "Configuration Planning global" non maquetté** ⚠️
La spec UX Flow 4 référence un écran "Paramètres du planning global" mais aucun fichier `screens/planning.html` n'existe. La navigation à 4 tabs (Accueil, Collèges, Recherche, Profil) ne comprend pas de tab Planning. Story 4.4 dit "l'écran de configuration du planning (FR30)" sans maquette de référence.
- **Risque :** Implémentation incohérente entre stories si le point d'entrée n'est pas défini explicitement.
- **Recommandation :** Clarifier dans la Story 4.4 l'accès à la configuration globale du planning (depuis Profil ? Depuis un bouton sur la SessionHeroCard ? Écran dédié ?).

**OBS-2 — Légère divergence couleur de surlignage search** (mineur)
`screens/search.html` utilise `#bbeddc` ; UX-DR7 et les épics spécifient `#B7F2C8`. Cohérence à aligner avant implémentation.

**OBS-3 — Icône "Bookmark" sur l'écran détail item sans FR correspondant** (mineur)
Visible dans `screens/item-detail.html`. Aucune story ne couvre cette fonctionnalité. À clarifier : élément décoratif ou feature non planifiée (V2+) ?

**OBS-4 — Notification bell dans TopAppBar sans story dédiée** (mineur)
Visible sur plusieurs écrans mockup. Aucune story ne couvre un "centre de notifications" in-app. Si c'est purement décoratif, le préciser pour éviter les questions des développeurs.

**OBS-5 — Durée OCR : incohérence PRD vs UX spec** (mineur)
Le PRD indique NFR2 "≤ 2 heures" ; la spec UX Défi UX #1 mentionne "jusqu'à 4h". À aligner — la cible contractuelle est NFR2 (2h).

---

## Section 5 — Revue de Qualité des Épics

### Checklist par Épic

| Épic | Valeur Utilisateur | Indépendance | Stories Bien Dimensionnées | AC Format BDD | Traçabilité FR |
|------|-------------------|--------------|---------------------------|---------------|----------------|
| Epic 1 | ⚠️ Technique (opérateur/testeuse) | ✓ | ⚠️ Story 1.1 technique | ✓ | ✓ |
| Epic 2 | ✓ | ✓ (après Epic 1) | ⚠️ Story 2.1 technique | ✓ | ⚠️ FR41/FR42 |
| Epic 3 | ✓ | ✓ (après Epic 1+2) | ✓ | ✓ | ✓ |
| Epic 4 | ✓ | ✓ (après Epic 3) | ⚠️ Story 4.1 technique, 4.2 large | ✓ | ✓ |
| Epic 5 | ✓ | ✓ (après Epic 3) | ✓ | ✓ | ✓ |
| Epic 6 | ✓ | ✓ (après Epic 2) | ✓ | ✓ | ✓ |

---

### 🔴 Violations Critiques

**Aucune violation critique identifiée.**

---

### 🟠 Problèmes Majeurs

**QUAL-1 — Story 1.1 : "Infrastructure Homelab & Squelettes Projets" — Story technique sans valeur utilisateur directe**
- La persona est "développeur", pas un utilisateur final.
- Aucun livrable utilisateur dans cette story.
- **Contexte mitigant :** L'architecture documente explicitement cette story comme fondation obligatoire pour un projet brownfield ("L'initialisation des deux projets constitue la première story d'implémentation"). Acceptable dans ce contexte, mais à étiqueter clairement comme "Technical Foundation Story" pour éviter toute confusion.
- **Recommandation :** Ajouter un commentaire dans la story : "Story de fondation technique — prérequis pour toutes les stories suivantes."

**QUAL-2 — Story 2.1 : "Thème & Design System Flutter" — Story technique sans valeur utilisateur directe**
- Persona : "développeur". Aucune valeur utilisateur directe.
- **Recommandation :** Même traitement que QUAL-1 — labeller comme Technical Foundation Story.

**QUAL-3 — Story 4.1 : "Composants FlashCard & DrillEvaluationBar" — Story technique sans valeur utilisateur directe**
- Persona : "développeur". Story de composants réutilisables.
- **Recommandation :** Même traitement que QUAL-1/QUAL-2.

**QUAL-4 — Incohérence FR41/FR42 entre coverage map et contenu des stories**
- La coverage map `FR41 → Epic 6`, `FR42 → Epic 6`.
- Mais Story 2.4 implémente déjà FR41 (deep link vers paramètres iOS) et FR42 (validation abonnement avant Claude).
- Risque : Story 6.1 (FR41) et Story 6.2 (FR42) pourraient créer des doublons ou supposer que le travail n'est pas encore fait.
- **Recommandation :** Mettre à jour la coverage map : `FR41 → Epic 2 (Story 2.4)`, `FR42 → Epic 2 (Story 2.4)`. Ou définir clairement quelle partie est dans chaque story (ex : FR41 = deep link dans Story 2.4, affichage dans profil dans Story 6.1).

---

### 🟡 Observations Mineures

**QUAL-5 — Story 4.2 : "Mode Drill — Session de Révision" potentiellement surdimensionnée**
- Couvre FR24, FR25, FR26, FR27, FR28, FR29 (6 FRs) dont l'évaluation sémantique via Claude (appel réseau) dans une story sinon entièrement offline.
- L'évaluation sémantique (FR29) est un appel Claude avec fallback offline — logique différente du reste du Mode Drill.
- **Recommandation :** Acceptable pour le MVP si l'équipe est à l'aise. Alternative : extraire FR29 en Story 4.2b "Évaluation sémantique des fiches définition" pour clarifier le scope.

**QUAL-6 — Navigation vers la "Configuration Planning Global" non définie (confirme OBS-1 UX)**
- Story 4.4 dit "l'écran de configuration du planning (FR30)" mais la navigation à 4 tabs n'inclut pas Planning.
- Story 4.3 ouvre un bottom sheet depuis "Modifier" sur la SessionHeroCard — ce bottom sheet couvre FR30 (quick session), mais où est la configuration globale (dates, disponibilité, collèges) ?
- **Recommandation :** Clarifier dans Story 4.4 le point d'entrée exact pour la configuration globale du planning (ex : depuis le profil ? Via un bouton dans la SessionHeroCard "Modifier le planning" distinct de "Modifier la session" ?).

**QUAL-7 — Création des tables DB : non spécifiée story par story**
- Story 1.1 inclut `alembic upgrade head` sans spécifier quelles tables sont créées dans la migration initiale.
- Bonne pratique : chaque story crée uniquement les tables qu'elle utilise.
- **Recommandation :** Dans Story 1.1, préciser que seules les tables `users` et `colleges` (base) sont créées. Les tables `items`, `flash_cards`, `generation_jobs` sont créées dans Story 1.2 et 1.3.

**QUAL-8 — Accès beta partagé entre Epic 1 (backend) et Epic 2 (Flutter)**
- FR44 → Epic 1 (Story 1.4 : gestion admin backend du flag `is_beta`)
- Story 2.3 : validation Flutter côté client du flag `is_beta`
- Cette répartition est cohérente mais doit être documentée pour éviter que le développeur de Story 2.3 attende la Story 1.4 ou qu'il reduplique la logique.
- **Recommandation :** Ajouter une note de dépendance explicite dans Story 2.3 : "Prérequis : Story 1.4 (endpoint beta access) doit être implémenté."

---

### Synthèse Qualité

| Catégorie | Compte | Statut |
|-----------|--------|--------|
| 🔴 Violations critiques | 0 | ✓ Aucune |
| 🟠 Problèmes majeurs | 4 | ⚠️ À corriger avant implémentation |
| 🟡 Observations mineures | 4 | ℹ️ À adresser si possible |

**Qualité globale des épics : BONNE** — Structure BDD cohérente, traçabilité des FRs quasi-complète, dépendances correctement ordonnées. Les 3 stories "techniques" (1.1, 2.1, 4.1) sont le seul pattern récurrent à adresser.

---

## Section 6 — Évaluation Finale de Prêt à Implémenter

### Statut Global

> ## ✅ PRÊT À IMPLÉMENTER — avec corrections mineures recommandées

Aucune violation critique n'a été identifiée. Les 4 problèmes majeurs sont résolvables rapidement (corrections de documentation, non refonte de fond). Le projet est **prêt à démarrer l'implémentation dès Epic 1**.

---

### Synthèse de Tous les Problèmes Identifiés

| ID | Section | Sévérité | Description | Action |
|----|---------|----------|-------------|--------|
| QUAL-1 | Qualité Épics | 🟠 Majeur | Story 1.1 technique sans valeur utilisateur | Labeller "Technical Foundation Story" |
| QUAL-2 | Qualité Épics | 🟠 Majeur | Story 2.1 technique sans valeur utilisateur | Labeller "Technical Foundation Story" |
| QUAL-3 | Qualité Épics | 🟠 Majeur | Story 4.1 technique sans valeur utilisateur | Labeller "Technical Foundation Story" |
| QUAL-4 | Qualité Épics | 🟠 Majeur | FR41/FR42 attribués Epic 6 mais implémentés dans Story 2.4 | Corriger la coverage map |
| QUAL-5 | Qualité Épics | 🟡 Mineur | Story 4.2 potentiellement surdimensionnée (6 FRs, dont FR29 avec appel Claude) | Acceptable en l'état, splitler si besoin |
| QUAL-6 | Qualité Épics | 🟡 Mineur | Entrée vers la "Configuration Planning Global" non définie | Clarifier dans Story 4.4 |
| QUAL-7 | Qualité Épics | 🟡 Mineur | Tables DB créées par Story 1.1 non spécifiées | Préciser dans Story 1.1 : tables `users` + `colleges` uniquement |
| QUAL-8 | Qualité Épics | 🟡 Mineur | Dépendance Story 2.3 → Story 1.4 non documentée | Ajouter note de prérequis dans Story 2.3 |
| OBS-1 | UX | 🟡 Mineur | Écran config planning global non maquetté, navigation non définie | Confirme QUAL-6 |
| OBS-2 | UX | 🟡 Mineur | Couleur surlignage search : `#bbeddc` vs `#B7F2C8` | Aligner avant Story 5.1 |
| OBS-3 | UX | 🟡 Mineur | Icône bookmark sans FR ni story | Décider : décoratif ou supprimer des maquettes |
| OBS-4 | UX | 🟡 Mineur | Notification bell sans centre de notifications | Décider : décoratif ou supprimer des maquettes |
| OBS-5 | UX | 🟡 Mineur | Durée OCR : "2h" (PRD/NFR2) vs "4h" (spec UX) | Aligner sur NFR2 : 2h |

**Total : 0 critique · 4 majeurs · 9 mineurs**

---

### Actions Recommandées Avant Implémentation

**Priorité 1 — À faire maintenant (impacte la compréhension des stories)**

1. **Corriger la coverage map FR41/FR42** (QUAL-4) : Mettre à jour `epics.md` pour refléter que FR41 et FR42 sont implémentés dans Story 2.4, pas Story 6.1/6.2. Évite un doublon lors du développement d'Epic 6.

2. **Clarifier l'accès à la Configuration Planning Global** (QUAL-6 / OBS-1) : Ajouter dans Story 4.4 un AC explicite décrivant le point d'entrée navigation vers cet écran. Suggestion : bouton "Modifier le planning" dans la section `RevisionPrefsCard` du Profil, ou un bouton distinct dans la `SessionHeroCard` (différent du "Modifier la session").

**Priorité 2 — À faire lors de l'écriture des stories (avant de coder)**

3. **Labeller les 3 Technical Foundation Stories** (QUAL-1/2/3) : Ajouter `[Technical Foundation]` dans le titre de Stories 1.1, 2.1, 4.1 pour indiquer clairement qu'elles sont des prérequis techniques, pas des user stories classiques.

4. **Ajouter la dépendance Story 2.3 → Story 1.4** (QUAL-8) : Note dans Story 2.3 : "Prérequis : endpoint `is_beta` opérationnel (Story 1.4)".

5. **Spécifier les tables créées par Story 1.1** (QUAL-7) : Dans les ACs de Story 1.1, préciser que la migration initiale crée uniquement `users` et `colleges` (base). Les tables `items`, `flash_cards`, `generation_jobs` sont créées dans Stories 1.2 et 1.3.

**Priorité 3 — Corrections cosmétiques (avant les stories concernées)**

6. Aligner la couleur de surlignage search sur `#B7F2C8` (OBS-2) avant Story 5.1.
7. Décider du statut des icônes bookmark et notification bell dans les maquettes (OBS-3/4).
8. Aligner la durée OCR sur "≤ 2 heures" (NFR2) dans la spec UX (OBS-5).

---

### Points Forts Notables

- **Couverture des FR à 100%** — Tous les 50 FR du PRD ont un chemin d'implémentation traçable dans les épics.
- **Architecture solide et bien alignée** — L'architecture documente explicitement les gaps et leur résolution (NFR4, NFR11, flux SSE→Drift). Prête pour l'implémentation.
- **Format BDD cohérent** — Les ACs de toutes les stories suivent le format Given/When/Then, avec couverture des cas d'erreur sur la grande majorité.
- **Phasage réaliste** — La Phase 0 comme go/no-go technique avant Flutter est une décision de risque excellente pour un développeur solo.
- **Stratégie offline-first bien pensée** — La distinction revisions offline / génération+search online est clairement reflétée dans toutes les stories concernées.

---

### Note Finale

**Ce rapport d'évaluation a analysé :**
- 4 documents (PRD, Architecture, Épics, UX Spec) + 11 maquettes HTML
- 50 Exigences Fonctionnelles · 12 Exigences Non-Fonctionnelles · 18 Exigences UX
- 6 épics · 17 stories · ~120 critères d'acceptance

**Conclusion :** AppMédecine Phase 0 + Phase 1 est **prêt à implémenter**. Les corrections recommandées sont mineures et ne nécessitent pas de refonte des documents. Commencez par corriger QUAL-4 (coverage map FR41/FR42) et QUAL-6 (navigation planning global), puis lancez Epic 1 Story 1.1.

**Évaluateur :** Claude (bmad-check-implementation-readiness)
**Date d'évaluation :** 2026-04-27

