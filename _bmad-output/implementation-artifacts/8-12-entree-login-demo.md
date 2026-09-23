# Story 8.12 : Entrée — marque, connexion, démo (livrée avec la 8.13)

Status: done

> Regroupée avec la 8.13 (Import) à la demande de l'utilisateur (2026-09-23).

## Story

En tant que **beta-testeuse invitée**, à la première ouverture je veux voir une vraie app, me connecter sans friction
(ou essayer la démo), et comprendre tout de suite pourquoi une connexion échoue.

## Critères d'acceptance (spec v2 § Parcours 1, audit « Entrée »)

1. Écran de marque `/welcome` (nouvelle entrée des non-connectés) : wordmark animé (apparition, statique en mouvement réduit), une phrase, « Se connecter » (primaire), « Essayer la démo » (quiet), « Beta privée · accès sur invitation ». Aucun Material/shadcn.
2. Connexion `/auth/login` : wordmark, `CgField` email + mot de passe dans un `AutofillGroup` (Trousseau / Face ID), « Suivant » → mot de passe → « Se connecter » ; **erreurs inline** : champ vide, identifiants incorrects (sous le mot de passe), réseau absent, trop d'essais (429), autre ; « Mot de passe oublié ? » → sheet (beta : demander à la personne qui t'a invitée) ; « Essayer la démo » en quiet.
3. **`/auth/register` retiré** (écran supprimé ; l'inscription est fermée côté serveur, 403) ; plus aucun lien « Créer un compte ».
4. Démo `/demo` : les 3 fiches de démo dans le vrai drill (`CgDrillCard`, gestes + boutons), puis un récap (maîtrisées / bien / à revoir) avec « Se connecter » (primaire) et « Recommencer » ; ✕ → retour à l'écran de marque. Un compte connecté ne voit jamais la démo (R3).
5. Accessibilité : champs étiquetés, erreurs annoncées, 44 pt, Dynamic Type 1,6. Goldens 3×2 : marque, connexion (avec erreur), récap de démo.

## Tâches

- [x] T1 Erreur de connexion typée (`LoginError`) dans `AuthState`
- [x] T2 `WelcomeScreen`, `AuthLoginScreen` Collega UI, routes (`/welcome`, register retiré)
- [x] T3 Démo sur `CgDrillCard` + récap ; anciens widgets démo supprimés

## Dev Agent Record

### Completion Notes List

- `/welcome` (wordmark qui apparaît, « Se connecter », « Essayer la démo », beta privée), connexion Collega UI (wordmark, `AutofillGroup`, erreurs inline typées `LoginError` : champ vide, email mal formé / 422, identifiants, réseau, 429, autre ; mot de passe oublié en sheet), inscription retirée (`/auth/register` → `/welcome`), démo sur `CgDrillCard` + récap.
- **Revue adversariale — tous les points corrigés** : le routeur était recréé à chaque changement de connexion (écran de marque réaffiché pendant la requête, erreur de connexion jamais visible, Profil renvoyé sur Aujourd'hui) → routeur unique avec `refreshListenable`, `login()` garde la valeur précédente ; écran neutre `/splash` au démarrage (jamais l'écran de marque pour un compte connecté) ; 422 → « Cet email n'est pas valide. » + contrôle local ; wordmark sur la connexion ; paywall : « Retour à la démo » (sans issue) → « Se déconnecter ».
