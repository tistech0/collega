# Story 8.13 : Import et import en cours (livrée avec la 8.12)

Status: review

## Story

En tant qu'**étudiante**, avant d'importer je veux savoir quoi envoyer et ce qui va se passer ; pendant l'import, voir mes fiches
arriver ; à la fin, tomber sur mon collège prêt.

## Critères d'acceptance (spec v2 § Parcours 4, § Import, audit « Import »)

1. Écran d'import Collega UI (hors onglets) : « ‹ Retour », icône + nom + éditeur du collège, **bloc d'information** : PDF officiel attendu (éditeur), 500 Mo au plus, ~3 à 10 min, quota (« Premier import » / « Réimport 1/2 · 1/3 ce mois »), « tu peux fermer Collega pendant l'import » ; un seul primaire ancré « Choisir le PDF ».
2. Envoi : barre + « Envoi 42 % · continue en arrière-plan » ; **erreurs inline** (plus de toasts) au format du spec, « Tes fiches restent » quand c'est un réimport : fichier trop lourd (« Ce fichier fait 612 Mo, maximum 500 »), déjà en cours, limites de réimport (collège / mois + date), envoi interrompu (« L'envoi reprendra tout seul »), expiré, fichier introuvable, session expirée, autre ; abonnement requis → paywall.
3. Import en cours (plein écran, sans tab bar) : étapes Envoi · Lecture du PDF (page x / y) · Génération des fiches · Classement ; **compteur « N fiches prêtes »** et **aperçu des 3 dernières fiches** au fil de l'eau (événement serveur `generation_progress`, déployé : migrations 016-017) ; « Tu peux fermer Collega : on te prévient. » ; « Fermer » (quiet) → le collège (« Les fiches arrivent »).
4. **Fin d'import → détail du collège prêt** (haptique succès), plus de retour au catalogue ni de toast ; échec → `CgState.error` avec relancer.
5. Lien direct vers l'import en cours sans contexte → détail du collège (plus « Navigation invalide »).
6. Accessibilité : étapes lues (« Lecture du PDF, en cours, page 12 sur 80 »), compteur en région vivante, 44 pt, Dynamic Type 1,6. Goldens 3×2 : import (premier), import en cours (génération).

## Tâches

- [x] T1 Serveur : avancement de génération (items / fiches) diffusé par SSE — image `8f5476d`, migration 016 appliquée
- [x] T2 `CollegeImportNotifier` : `generation_progress` → `ImportStreaming.cards / itemsDone / itemsTotal`
- [x] T3 `CollegeImportScreen` (bloc d'information, quota, erreurs inline)
- [x] T4 `ImportProgressScreen` (étapes, compteur, fin → détail) + tests + goldens, revue, build iPhone

## Dev Agent Record

### Completion Notes List

- Serveur : avancement de génération publié item par item (session séparée, échec sans effet), diffusé par le flux SSE, remis à zéro à chaque import ; aperçu des 3 dernières questions (migrations 016, 017 ; images `8f5476d`, `7420304`). Suite backend entièrement verte (tests périmés d'inscription / jeton APNs alignés).
- App : écran d'import (bloc d'information, quota, erreurs inline via `importErrorMessage`, envoi en %), import en cours (étapes lues par VoiceOver, compteur, aperçu, « tu peux fermer »), fin → collège prêt ; lien sans contexte → collège.
- **Revue adversariale — corrigé** : fin d'un premier import renvoyait vers l'écran d'import (le détail lisait l'ancienne liste pendant son rechargement) ; second écran de progression poussé après erreur puis reprise (écoute coupée quand l'écran est recouvert) ; « Fermer » mène au collège, pas à l'import ; « Reprise de l'import… » ne reste jamais sans fin (erreur + Réessayer) ; compteur conservé à la reprise ; « Tes fiches restent » sur l'écran de progression en réimport ; ouvrir l'import ne coupe plus un import suivi ; envoi d'un autre collège dit et bloque ; échec du sélecteur de fichiers dit.
- Tests : app 1 172 verts (par dossiers), backend 476 verts ; goldens marque, connexion (erreur), récap démo, import, import en cours 3×2.
