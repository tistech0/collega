---
stepsCompleted: ['step-01-init', 'step-02-discovery', 'step-02b-vision', 'step-02c-executive-summary', 'step-03-success', 'step-04-journeys', 'step-05-domain', 'step-06-innovation', 'step-07-project-type', 'step-08-scoping', 'step-09-functional', 'step-10-nonfunctional', 'step-11-polish', 'step-12-complete']
releaseMode: phased
inputDocuments:
  - 'docs/superpowers/specs/2026-04-25-appmedecine-design.md'
  - '_bmad-output/brainstorming/brainstorming-session-2026-04-25-1958.md'
classification:
  projectType: mobile_app
  domain: edtech
  complexity: high
  projectContext: brownfield
workflowType: 'prd'
---

# Product Requirements Document — AppMédecine

**Auteur :** Lesurmatthis
**Date :** 2026-04-26

---

## Résumé Exécutif

AppMédecine est une application mobile (iOS + iPadOS Phase 1, Android Phase 2) destinée aux étudiants en médecine français préparant l'ECN (Examen Classant National), à partir de la 2ème année. Elle résout un problème structurel : les cursus médicaux français sont profondément hétérogènes d'une faculté à l'autre — ordre des collèges, découpage des items, calendrier des examens — rendant impossible tout outil de révision basé sur un contenu ou un ordre partagé.

L'app permet à chaque étudiant d'importer les PDFs officiels des 40 collèges médicaux, d'en extraire automatiquement des fiches de révision par item et par rang (A/B/C), et d'organiser librement son apprentissage selon son propre calendrier de faculté. L'état de progression est entièrement personnel.

Un second axe de valeur connecte l'apprentissage théorique à l'expérience clinique : depuis la recherche, l'étudiant retrouve en secondes l'item correspondant à un cas vu en stage et lance une révision immédiate à chaud. Ce lien — stage clinique → révision théorique contextualisée — est par définition impossible à reproduire par des decks partagés.

### Ce qui rend AppMédecine unique

**Différenciateur #1 — Liberté totale d'organisation.** L'app ne prescrit aucun ordre d'apprentissage. L'étudiant importe les collèges dont il a besoin maintenant, travaille les items couverts cette semaine, et construit son propre état de progression. Le seul outil qui s'adapte au cursus réel de chaque étudiant plutôt que d'imposer le sien.

**Différenciateur #2 — Lien stage → révision.** Chaque cas clinique devient un point d'entrée vers les fiches correspondantes. Au fil du temps, l'app devient un journal de l'externat : chaque pathologie vue sur un vrai patient est ancrée dans la mémoire épisodique — la forme de mémoire la plus durable.

**Insight fondamental.** L'hétérogénéité des cursus entre facultés n'est pas un obstacle à contourner — c'est exactement pourquoi aucune solution existante ne fonctionne, et pourquoi AppMédecine a un espace clair sur ce marché.

**Modèle économique.** ~100€/an facturé ~9€/mois. Coût LLM ~15$ au premier traitement, quasi nul dès le second abonné sur la même édition grâce au hash-sharing. Rentable dès le 2ème mois par étudiant.

## Classification du Projet

| Dimension | Valeur |
|---|---|
| Type | Application mobile Flutter |
| Domaine | EdTech — formation médicale |
| Complexité | Haute (pipeline OCR, LLM asynchrone, in-app purchase, recherche full-text cloud) |
| Contexte | Brownfield (spec initiale + brainstorming complets) |
| Lancement | iOS + iPadOS Phase 1 (dev/test sur Mac) — Android Phase 2 |
| Données sensibles | Aucune — pas de données de santé cliniques ; ancres épisodiques (V2) anonymisées |

## Critères de Succès

### Succès Utilisateur

- L'étudiant complète la demo interactive et comprend la proposition de valeur avant toute inscription.
- Après inscription, l'étudiant importe son premier collège réel et obtient ses fiches sans friction.
- L'étudiant organise ses révisions selon son calendrier de faculté — sans ordre imposé.
- La recherche full-text retrouve un item clinique pertinent en moins d'une seconde.
- Le badge de confiance OCR alerte l'étudiant quand la qualité source est insuffisante.

### Succès Business

- **Phase 0 :** Qualité des fiches validée par la testeuse sur 1 collège réel → go/no-go pour le MVP Flutter.
- **Beta :** Utilisateurs de la promotion de la sœur du développeur (accès gratuit). Validation de l'usage réel sur 3 collèges.
- **Validation mid-développement :** Présentation du premier bloc MVP fonctionnel à des étudiants réels pour valider la pertinence des fiches et l'expérience de révision.
- **Post-beta :** 5 abonnés payants à ~100€/an — premier signal de traction et viabilité du modèle économique.
- **Rentabilité unitaire :** Dès le 2ème mois d'abonnement par étudiant.

### Résultats Mesurables

| Métrique | Cible |
|---|---|
| Validation Phase 0 | Fiches jugées pertinentes par la testeuse sur 1 collège |
| Abonnés payants post-beta | 5 (premier palier) |
| Délai de génération par collège | ≤ 2 heures |
| Latence recherche full-text | < 1 seconde (10 collèges indexés) |
| Plateforme au lancement | iOS + iPadOS uniquement |

## Parcours Utilisateurs

### Parcours 1 — Léa, 4ème année (parcours succès)

Léa prépare son exam de Cardiologie dans 3 semaines. Elle télécharge AppMédecine sur son iPhone.

**Découverte :** L'app propose une demo avec un faux collège "Cardiologie Exemple" — 3 fiches pré-chargées, 1 souvenir sur un item. Elle comprend le fonctionnement en quelques minutes, sans rien lire.

**Inscription :** Deux jours plus tard, elle revient décidée. Elle skipe la demo, s'inscrit, souscrit à ~9€/mois.

**Premier import :** Elle sélectionne Cardiologie dans la liste des 40 collèges, importe son PDF (380 pages). L'OCR démarre en background. 90 minutes plus tard : notification — ses fiches sont prêtes.

**Révision :** Elle filtre sur Rang A, lance une session de 20 minutes. Les fiches sont découpées par item. Elle travaille ce qu'elle a vu cette semaine en cours — pas un programme imposé.

**Résultat :** Le jour de l'exam, elle a travaillé dans l'ordre de son cursus, pas celui d'un deck générique.

---

### Parcours 2 — Tom, 5ème année (mode stage)

Tom est en stage de Cardiologie. Il vient de voir un patient en IC aiguë décompensée — BNP à 2300, crépitants bilatéraux. Il n'est pas sûr de maîtriser tous les critères diagnostiques.

**Déclencheur :** Dans le couloir, entre deux visites, il ouvre AppMédecine et tape "BNP".

**Résultat instantané :** L'item IC remonte avec le passage exact sur les biomarqueurs. Il voit ses fiches Rang A sur cet item — Rang B pas encore touché.

**Révision à chaud :** 5 minutes de Mode Drill sur les fiches Rang A de l'item IC. Le cas est encore présent — les informations s'ancrent différemment.

**Résultat :** Ce soir-là, pas besoin de "décider quoi réviser". Le stage a dicté l'agenda.

---

### Parcours 3 — Camille (PDF scanné, OCR dégradé)

Camille importe un vieux PDF scanné du collège de Neurologie — 4ème édition, scans de mauvaise qualité.

**Signal d'alerte :** Sur l'item "Épilepsie", un badge orange : "Source peu lisible — vérifier dans le PDF original". Score de confiance OCR sous le seuil.

**Décision éclairée :** Elle utilise les fiches comme point de départ mais ouvre le PDF pour vérifier avant de marquer "Maîtrisé".

**Résultat :** Elle n'a pas mémorisé une information erronée sans le savoir.

---

### Parcours 4 — Lesurmatthis (opérateur)

Deux semaines après le lancement beta, Lesurmatthis vérifie le backend depuis son Mac.

**Monitoring :** Queue de génération — 2 collèges en attente, aucun bloqué. Temps de traitement < 2h.

**Ajustement :** Il baisse le quota mensuel de re-traitements de 3 à 2 — modifie la valeur en config backend, sans mise à jour de l'app. Effet immédiat.

**Résultat :** Système piloté en quelques minutes, sans déploiement.

---

### Parcours 5 — Maxime (tentative de spam)

Maxime tente de contourner les limites pour régénérer indéfiniment son collège de Médecine Interne.

- **Tentative 1 :** Re-import autorisé. Compteur : 1/2.
- **Tentative 2 :** Autorisé — dernier re-traitement pour ce collège. Compteur : 2/2. L'app l'informe que ce collège ne peut plus être re-traité.
- **Tentative 3 :** Quota mensuel global atteint (3/mois). L'app indique la date de réinitialisation.

**Résultat :** Maxime ne peut pas spammer. Ses fiches existantes sont intactes. Aucun appel Claude non autorisé.

---

### Résumé des Capacités Révélées

| Parcours | Capacités requises |
|---|---|
| Léa — succès | Demo, auth, in-app purchase, import PDF, OCR background, génération fiches, spaced repetition, planning libre |
| Tom — mode stage | Search full-text, résultats avec contexte, lancement session depuis résultat |
| Camille — OCR dégradé | Score confiance OCR par item, badge warning, fiches utilisables malgré qualité partielle |
| Lesurmatthis — opérateur | Monitoring queue, gestion accès beta, config anti-spam sans déploiement |
| Maxime — abuseur | Compteurs `reload_count` (max 2) + `monthly_reloads` (max 3), blocage gracieux sans bannissement |

## Exigences Domaine

### Conformité & Réglementation

- **RGPD :** Collecte d'email et données d'abonnement sur utilisateurs européens → politique de confidentialité, droit à la suppression, consentement explicite à l'inscription.
- **Dispositif médical :** AppMédecine est un outil éducatif — aucune certification MDR (Europe) ni FDA (US) requise. À mentionner dans les CGU.
- **Utilisateurs majeurs :** Cible 18+ — pas d'obligation COPPA/FERPA (lois US, non applicables).

### Données & Confidentialité

- Seuls email, statut d'abonnement et compteurs d'usage sont stockés côté backend.
- Texte OCR éphémère : supprimé après génération des fiches (rétention max 24h — NFR9).
- L'étudiant peut supprimer son compte et toutes ses données associées depuis l'app (FR39).

### Positionnement Copyright

- L'étudiant importe son propre exemplaire acheté — AppMédecine ne distribue aucun contenu.
- Seules les fiches (œuvre dérivée transformative) sont conservées. Position à formaliser dans les CGU.

### Conformité App Store

- Demo accessible sans création de compte.
- Prix et durée d'abonnement affichés avant confirmation d'achat.
- Politique d'annulation accessible depuis les paramètres iOS.

### Risques et Mitigations

| Risque | Mitigation |
|---|---|
| Réclamation copyright d'un collège | CGU claires, OCR éphémère, import personnel uniquement |
| Non-conformité RGPD | Politique de confidentialité, suppression compte, minimisation des données |
| Rejet App Store | Demo gratuite sans compte, paywall après valeur démontrée |
| OCR de mauvaise qualité mémorisé | Badge warning par item, invitation à vérifier dans le PDF original |

## Innovation & Patterns Originaux

### Zones d'Innovation Identifiées

**1. Hash-sharing à seuil de similarité**
Deux PDFs considérés identiques si similarité de contenu textuel (post-OCR) ≥ seuil cible (point de départ : 90%, à calibrer sur vrais collèges). Si le seuil est atteint, les fiches existantes sont servies sans nouvel appel Claude. Architecture modulaire dès la v1 — algorithme remplaçable sans refonte.

**2. Boucle de qualité par feedback**
Pouce bas sur une fiche → régénération ciblée avec feedback en contexte Claude, ou suppression. Coût LLM nul à la génération initiale. Combiné au hash-sharing, le feedback d'un utilisateur améliore à terme les fiches partagées par toute la cohorte.

**3. Mode Drill / Mode Raisonnement**
Deux expériences d'étude sur le même contenu généré : *Mode Drill* (MVP) — cards isolées en spaced repetition rapide pour ancrer les faits Rang A/B. *Mode Raisonnement* (Post-MVP) — Flashcard Chains activables, séquences de 5-10 cards suivant un raisonnement clinique complet (symptômes → diagnostic → examens → traitement → suivi). L'étudiant choisit le mode selon sa phase de préparation.

**4. Évaluation sémantique des réponses**
Pour les fiches définition, Claude évalue la proximité sémantique de la réponse plutôt que la correspondance textuelle exacte. Pédagogiquement supérieur pour des définitions médicales où la formulation peut varier.

**5. OCR éphémère + œuvre dérivée**
Le texte source disparaît après génération. Seule la transformation (fiches) est stockée. Position légale originale et architecture minimisant les données.

### Contexte Marché

Aucun concurrent direct sur la combinaison "liberté d'ordre d'apprentissage + lien stage + génération automatique de fiches par collège". Anki, decks partagés et applications ECN supposent soit un contenu universel partagé, soit une construction manuelle.

### Approche de Validation

| Innovation | Méthode |
|---|---|
| Seuil hash-sharing | Prototypage sur 3-5 PDFs réels, mesure faux positifs/négatifs |
| Feedback → régénération | Beta : taux de fiches signalées, qualité perçue après régénération |
| Mode Raisonnement | Post-MVP : adoption spontanée des Chains vs Mode Drill |
| Évaluation sémantique | A/B interne : satisfaction matching exact vs. sémantique |

### Risques Innovation

| Risque | Mitigation |
|---|---|
| Seuil similarité trop bas → fausses correspondances | Calibration par prototypage, opt-out manuel |
| Feedback abus (thumbs down systématique) | Limiter les régénérations gratuites par période |
| Mode Raisonnement non adopté | Optionnel et activable — n'impacte pas le Mode Drill |

## Exigences Spécifiques Mobile App

### Plateforme & Distribution

- **Phase 1 :** iOS + iPadOS — App Store uniquement (dev/test sur Mac)
- **Phase 2 :** Android — Google Play Store
- **iOS minimum :** iOS 16+ (Vision Framework)
- **Stack :** Flutter — codebase unique, UI adaptée iOS et iPadOS

### Mode Hors Ligne

| Fonctionnalité | Hors ligne | Connexion requise |
|---|---|---|
| Fiches générées + sessions quiz | ✅ | |
| Recherche full-text | | ✅ (PostgreSQL cloud) |
| Import PDF + OCR | | ✅ (stream backend) |
| Génération Claude | | ✅ |
| Synchronisation progression | | ✅ |

**Cache local :** Fiches automatiquement synchronisées en local au moment de la génération (~1-5 MB/collège). Transparent, sans choix utilisateur. À réévaluer si le besoin émerge en beta.

### Notifications Push

- **"Fiches prêtes"** — fin de génération d'un collège
- **Rappel de révision** — quotidien, heure configurable par l'étudiant

### Permissions Appareil (Phase 1)

| Permission | Usage |
|---|---|
| Fichiers / Documents | Import PDF depuis stockage local |
| Notifications | Fiches prêtes + rappels |
| Background Processing | OCR en tâche de fond (`BGProcessingTask`) |

*Permissions supplémentaires (ex: microphone pour dictée) en Phase 2.*

### Considérations d'Implémentation

- `BGProcessingTask` pour OCR longue durée — reprend si interrompu
- `file_picker` Flutter pour import PDF
- PDFs copiés dans le dossier privé de l'app (50-500 MB)
- App native Flutter uniquement — pas de web view

## Scoping & Développement Phasé

### Stratégie MVP

**Approche :** Revenue MVP — prouver qu'un étudiant paie pour organiser ses révisions selon son propre cursus avec des fiches générées automatiquement.
**Ressources :** Développeur solo, rythme soutenable, pas de contrainte de délai.

### Phase 0 — Validation Pipeline (Pré-App)

Objectif : valider la qualité end-to-end (OCR → détection items → Claude → fiches) sur 1 collège réel avant d'investir dans le Flutter complet.

- Backend FastAPI + PostgreSQL opérationnel
- Pipeline OCR → stream → génération Claude fonctionnel
- Interface admin web sécurisée : déclenchement manuel, stats de génération (FR47, FR48)
- Interface testeur web (FR49, FR50) : visualisation fiches + feedback qualité
- **Go/No-Go :** qualité validée par la testeuse → décision de continuer vers le MVP Flutter

### Phase 1 — MVP Flutter (iOS + iPadOS, beta 3 collèges)

**Parcours couverts :** Léa, Camille, Maxime, Lesurmatthis

- Demo interactive (collège fictif, 3 fiches, 1 souvenir — toutes features visibles sauf import réel)
- Auth + abonnement in-app purchase App Store (paywall post-demo)
- Import limité à 3 collèges en beta
- Import PDF → OCR background → stream backend → détection items par Claude
- Génération fiches : flashcard classique + définition, Rang A/B/C
- **Mode Drill** : sessions quiz spaced repetition (3 niveaux : À revoir / Bien / Maîtrisé)
- Planning algorithmique local (priorité A→B→C, jours disponibles)
- Recherche full-text (PostgreSQL GIN index)
- Score de confiance OCR + badge warning
- Hash-sharing v1 modulaire (architecture prévue pour remplacement sans refonte)
- Feedback fiches (pouce haut/bas) + régénération ciblée ou suppression
- Anti-spam : `reload_count` max 2/collège + `monthly_reloads` max 3/mois, configurables backend
- Cache local automatique des fiches
- Notifications : "fiches prêtes" + rappel quotidien optionnel
- RGPD : suppression compte + données, politique de confidentialité, CGU
- **Validation mid-développement :** présentation du premier bloc fonctionnel à des étudiants réels

### Lancement Payant (post-validation beta)

Condition : pipeline + hash-sharing validés sur 3 collèges sans problème bloquant.

- Ouverture des 40 collèges
- Abonnement ~100€/an facturé ~9€/mois activé

### Phase 2 — Post-MVP

- **Mode Raisonnement** : Flashcard Chains activables (séquences de raisonnement clinique complet)
- Mode stage : point d'entrée rapide depuis la search (cas clinique → item → révision)
- Hash-sharing v2 : algorithme affiné (seuil 90%+ calibré sur vrais collèges)
- Phrase à compléter + dictée (2ème et 3ème types de cards)
- Android (Google Play Store)

### Vision — V2+

- Ancres épisodiques (notes personnelles par item, souvenir de stage)
- Re-planning adaptatif via LLM (après 2 semaines de données réelles)
- Onboarding par cas clinique simulé (démo dynamique)

### Analyse des Risques

| Risque | Probabilité | Mitigation |
|---|---|---|
| OCR + détection chapitres de mauvaise qualité | Haute | Phase 0 = go/no-go technique avant Flutter |
| Hash-sharing v1 peu efficace | Moyenne | Architecture modulaire, remplacement sans refonte |
| Rejet App Store | Faible | Demo gratuite sans compte, paywall après valeur |
| Adoption lente en beta | Faible | Beta contrôlée via réseau proche |

## Exigences Fonctionnelles

### Onboarding & Accès

- **FR1 :** L'utilisateur peut explorer l'app via une démo interactive avec un collège fictif et des fiches pré-chargées, sans créer de compte.
- **FR2 :** L'utilisateur peut ignorer la démo et accéder directement à l'inscription.
- **FR3 :** L'utilisateur peut créer un compte avec email et mot de passe.
- **FR4 :** L'utilisateur peut souscrire à un abonnement payant via l'in-app purchase App Store.
- **FR5 :** L'utilisateur ne peut pas accéder aux fonctionnalités principales sans abonnement actif.
- **FR6 :** L'utilisateur peut consulter le prix et la durée d'abonnement avant de confirmer l'achat.

### Gestion des Collèges & Import

- **FR7 :** L'utilisateur peut consulter la liste des 40 collèges médicaux prédéfinis dans l'app.
- **FR8 :** L'utilisateur peut importer un fichier PDF depuis son stockage local dans un collège sélectionné.
- **FR9 :** Le système extrait le texte de chaque page d'un PDF via OCR en tâche de fond, sans bloquer l'interface.
- **FR10 :** Le système reprend automatiquement le traitement OCR si interrompu.
- **FR11 :** Le système calcule un score de confiance OCR par item et affiche un badge d'alerte si la qualité est insuffisante.
- **FR12 :** Le système détecte automatiquement les items et chapitres du PDF côté backend.
- **FR13 :** L'utilisateur peut suivre la progression de l'import et de la génération en temps réel.
- **FR14 :** L'utilisateur peut re-importer un collège dans la limite de 2 re-traitements par collège et 3 re-traitements par mois. Le premier import est libre.
- **FR15 :** Le système bloque gracieusement les re-traitements au-delà des limites et informe l'utilisateur de la date de réinitialisation.

### Génération & Gestion des Fiches

- **FR16 :** Le système génère des flashcards classiques (recto/verso) et des fiches définition à partir du texte OCR via l'API Claude.
- **FR17 :** Le système tague automatiquement chaque fiche avec le rang de l'item source (A, B ou C).
- **FR18 :** Le système détecte si un PDF importé correspond à un traitement existant et sert les fiches sans nouvel appel Claude.
- **FR19 :** L'utilisateur peut signaler une fiche comme pertinente ou non pertinente.
- **FR20 :** L'utilisateur peut déclencher la régénération d'une fiche signalée négativement, avec le feedback transmis en contexte à Claude.
- **FR21 :** L'utilisateur peut supprimer une fiche jugée non pertinente.
- **FR22 :** Le système synchronise automatiquement les fiches générées en cache local sur l'appareil.
- **FR23 :** L'utilisateur reçoit une notification push à la fin de la génération d'un collège.

### Révision & Apprentissage

- **FR24 :** L'utilisateur peut lancer une session de quiz (Mode Drill) en sélectionnant collèges, items et rangs.
- **FR25 :** Le système présente les fiches en spaced repetition à 3 niveaux (À revoir / Bien / Maîtrisé).
- **FR26 :** L'utilisateur évalue chaque fiche selon son niveau de mémorisation.
- **FR27 :** Le système ajuste la fréquence de présentation selon le niveau déclaré.
- **FR28 :** L'utilisateur accède aux fiches générées et lance des sessions de quiz sans connexion internet.
- **FR29 :** Le système évalue la réponse à une fiche définition par proximité sémantique plutôt que correspondance textuelle exacte.
- **FR30 :** L'utilisateur configure un planning d'apprentissage en sélectionnant collèges, items, dates et disponibilité quotidienne.
- **FR31 :** Le système génère un planning algorithmique local, priorisé par rang (A→B→C).
- **FR32 :** L'utilisateur consulte sa session du jour (items, rangs, nombre de fiches).
- **FR33 :** L'utilisateur marque une session comme effectuée ou la décale.
- **FR34 :** L'utilisateur consulte sa progression par collège et par rang.
- **FR35 :** L'utilisateur configure un rappel quotidien de révision à l'heure de son choix.

### Recherche

- **FR36 :** L'utilisateur effectue une recherche full-text sur l'ensemble de ses collèges importés.
- **FR37 :** Le système affiche les résultats avec le passage contextuel et le chapitre source.
- **FR38 :** L'utilisateur lance une session de révision directement depuis un résultat de recherche.

### Compte & Conformité

- **FR39 :** L'utilisateur supprime son compte et toutes ses données associées depuis l'app.
- **FR40 :** L'utilisateur consulte la politique de confidentialité et les CGU depuis l'app.
- **FR41 :** L'utilisateur accède à la gestion de son abonnement (annulation) depuis les paramètres iOS.
- **FR42 :** Le système valide le statut d'abonnement actif avant chaque appel à l'API Claude.

### Administration & Opérateur

- **FR43 :** L'opérateur consulte l'état de la queue de génération (traitements en attente, statut, temps).
- **FR44 :** L'opérateur gère les accès beta (accès gratuit sans abonnement).
- **FR45 :** L'opérateur ajuste les limites anti-spam côté backend sans mise à jour de l'app.
- **FR46 :** L'opérateur surveille les statuts d'abonnement et les webhooks App Store.
- **FR47 :** L'opérateur déclenche manuellement la génération d'un collège via une interface admin web sécurisée.
- **FR48 :** L'opérateur consulte les statistiques de génération : nombre de fiches, score de confiance OCR par item, taux de similarité hash-sharing.

### Interface Testeur (Validation Phase 0)

- **FR49 :** Le testeur (accès restreint par authentification) parcourt et interagit avec les fiches d'un collège généré via une interface web.
- **FR50 :** Le testeur signale chaque fiche comme pertinente ou non (feedback transmis à l'opérateur).

## Exigences Non-Fonctionnelles

### Performance

- **NFR1 :** La recherche full-text retourne des résultats en moins d'une seconde pour un utilisateur avec 10 collèges indexés.
- **NFR2 :** La génération complète d'un collège (OCR → détection items → fiches Claude) se termine en moins de 2 heures.
- **NFR3 :** Les sessions quiz répondent en moins de 100ms (données locales).
- **NFR4 :** L'app démarre et affiche l'écran principal en moins de 3 secondes sur un iPhone supporté.

### Sécurité

- **NFR5 :** La clé API Claude n'est jamais incluse dans le bundle de l'app — exclusivement côté backend.
- **NFR6 :** Le statut d'abonnement est validé côté backend (receipt App Store) avant chaque appel Claude.
- **NFR7 :** Toutes les communications app ↔ backend transitent en HTTPS.
- **NFR8 :** Les données utilisateur sont stockées avec accès scopé par user_id — aucune donnée cross-user accessible.
- **NFR9 :** Le texte OCR est supprimé du backend après génération des fiches — rétention maximale : 24 heures.

### Fiabilité

- **NFR10 :** Si Claude API est indisponible, les demandes restent en queue et reprennent automatiquement — l'utilisateur est informé du délai.
- **NFR11 :** Si l'OCR est interrompu (background, crash), il reprend au dernier point de sauvegarde.
- **NFR12 :** Une panne backend n'empêche pas l'accès aux fiches synchronisées ni les sessions quiz en cours.
