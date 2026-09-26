# Console de pilotage de la beta — design

Date : 2026-09-26 · Statut : validé en brainstorming, en relecture

## 1. Intention

La console admin (`collega_backend/app/static/admin/index.html`, 1148 lignes HTML/JS
d'un seul tenant, style MVP) devient **le poste de pilotage de la beta TestFlight** :
plus belle, plus pratique, plus pro, visiblement le même produit que l'app (direction
« Feuille × Bloc » de l'epic 8), et capable de montrer ce que vit chaque testeuse.

Une seule utilisatrice de la console : l'éditeur. Usage sur ordinateur d'abord,
téléphone possible.

Questions auxquelles l'accueil doit répondre en un coup d'œil, par priorité :

1. Est-ce que les testeuses utilisent l'app ? (activité, série, inactives)
2. Est-ce que les imports marchent ? (en cours, en échec, bloqués)
3. Gérer les testeuses (créer un compte en deux clics, voir l'état de chacune)
4. Puis : les fiches sont-elles bonnes ? (avis négatifs) et combien ça coûte ?

### Hors périmètre

Thème sombre, exports CSV, comptes admin multiples ou rôles (on garde Basic Auth
applicatif + Cloudflare Access `collega-admin`), notifications push vers l'éditeur
autres que Telegram.

## 2. Données et backend

### 2.1 Dernière activité : `users.last_seen_at`

- Nouvelle colonne `users.last_seen_at TIMESTAMPTZ NULL` (migration Alembic).
- Mise à jour dans `POST /v1/auth/refresh` et `GET /v1/auth/me`, **au plus une
  écriture toutes les 10 minutes** par utilisatrice (comparaison avec la valeur
  courante, pas de cache externe).
- `NULL` = jamais connectée depuis la création du compte. Le login lui-même met à
  jour la valeur (une testeuse qui se connecte puis ne revient pas est « vue »).

### 2.2 Résumé d'activité envoyé par l'app : `activity_days`

Aujourd'hui, les séances, verdicts et séries vivent uniquement dans la base locale
de l'app (drift, `DailySessionRepository`). Le backend n'en sait rien.

- Nouvelle table `activity_days` : `user_id` (FK, `ON DELETE CASCADE`), `day`
  (DATE, jour local de l'app), `cards_reviewed` (int ≥ 0), `session_completed`
  (bool), `streak` (int ≥ 0), `updated_at`. Clé primaire `(user_id, day)`.
- Route `PUT /v1/activity/{day}` (utilisatrice authentifiée), corps
  `{"cards_reviewed": int, "session_completed": bool, "streak": int}`.
  - **Remplacement idempotent** (upsert) : renvoyer deux fois le même jour ne
    double rien. L'app envoie toujours le total du jour.
  - Refus `422` si `day` est à plus d'un jour dans le futur (fuseaux) ou à plus de
    30 jours dans le passé ; bornes raisonnables sur les compteurs
    (`cards_reviewed` ≤ 5000, `streak` ≤ 3650).
  - Met aussi à jour `last_seen_at` (même règle de 10 minutes).
  - Réponse `{"data": {...}}` ; erreurs via `AppError` (`detail.code`).
- Aucun contenu de fiche n'est transmis : uniquement ces trois compteurs.
- Suppression de compte (`DELETE /v1/auth/account`) : les lignes partent en
  cascade.

### 2.3 Pastilles du menu : `GET /v1/admin/badges`

Chaque pastille compte des choses **qui demandent une action**. Calcul sur l'état
réel, sans « marquer comme lu » sauf pour la qualité.

| Pastille | Compte | Disparaît quand |
|---|---|---|
| Testeuses | comptes beta jamais connectés (`last_seen_at` NULL) + comptes beta inactifs depuis plus de `inactivity_days` jours (défaut 5) | elles reviennent dans l'app |
| Imports | jobs `failed` depuis moins de 7 jours + jobs actifs (`pending`/`processing`/`ocr_complete`) sans événement depuis plus de 15 minutes | relance, suppression, ou 7 jours écoulés |
| Qualité | fiches passées en `user_feedback = 'negative'` depuis la dernière visite de l'écran Qualité | ouverture de l'écran Qualité |

- `inactivity_days` et `quality_seen_at` sont stockés dans `app_settings`
  (`get_setting`/`set_setting`, cache 30 s existant).
- `POST /v1/admin/badges/quality-seen` enregistre la visite (appelé par l'écran
  Qualité à l'ouverture).
- L'horodatage d'un avis négatif : `flash_cards.updated_at` (`onupdate`). Pas de
  nouvelle colonne : la seule autre écriture d'une fiche, la régénération
  (`app/api/v1/flash_cards.py`), remet `user_feedback` à `NULL`, donc une fiche
  encore négative a bien son `updated_at` fixé par l'avis.

### 2.4 Accueil : `GET /v1/admin/pilot`

Une seule requête pour l'écran Pilotage :

- chiffres clés : testeuses actives sur 7 j / total beta, fiches révisées sur 7 j,
  imports en échec (même règle que la pastille), coût Claude sur 30 j ; chacun avec
  sa valeur de la période précédente pour afficher l'évolution ;
- liste des testeuses beta : nom, e-mail, `last_seen_at`, série (dernier `streak`
  connu), fiches révisées sur 7 j, statut dérivé (`active`, `inactive`,
  `never_seen`) ;
- « À surveiller » : imports en échec ou bloqués (collège, utilisatrice, étape,
  message), nouveaux avis négatifs (collège, nombre), imports en cours
  (progression).

### 2.5 Fiche testeuse : `GET /v1/admin/users/{id}` enrichi

Ajouts à la réponse existante : `last_seen_at`, série courante, totaux 30 j (fiches
révisées, jours avec séance terminée), **série quotidienne sur 30 jours**
(`[{day, cards_reviewed, session_completed}]`, jours manquants = 0), collèges avec
statut d'import et nombre de fiches, derniers avis (item, recto tronqué, positif ou
négatif, date).

### 2.6 Alerte Telegram sur import en échec

On réutilise le mécanisme existant : le User Script Unraid `collega-health` (chaque
minute) et l'agent Telegram du NAS, qui n'envoie immédiatement que le niveau
`alert`.

- Nouvelle commande versionnée et testée `python -m scripts.import_alerts` dans
  l'image backend : affiche une ligne par job passé en `failed` depuis le dernier
  passage (« collège — e-mail : étape, message court »). Le point de reprise
  (dernier `updated_at` traité) est stocké dans Redis (`collega:import_alerts:since`) ;
  au tout premier passage il est initialisé à « maintenant » (pas de rafale
  historique).
- `collega-health.sh` lance `docker exec collega-api-1 python -m scripts.import_alerts`
  et, si la sortie n'est pas vide, envoie `notify "Collega : import en échec" "<lignes>" "alert"`.
  Une erreur de la commande n'interrompt pas la sonde de santé.
- Aucun secret Telegram dans le backend, aucun service externe.
- Aucun emoji dans les messages.

### 2.7 Conventions

Logique dans `app/services` (nouveau `app/services/activity.py` et
`app/services/admin_pilot.py`), routes HTTP minces (`app/api/v1/activity.py`,
`app/api/v1/admin/pilot.py`), `AppError` et fabriques de `app/core/errors.py`,
réponses `{"data": …}`, `mypy app/core app/services` à 0 erreur, `alembic check`.

## 3. Console (front)

### 3.1 Technique

HTML/CSS/JS sans framework, modules ES natifs, **aucune étape de build**, aucune
dépendance npm ; toujours servi par le `StaticFiles` monté sur `/admin`.

```
app/static/admin/
  index.html            coquille : menu latéral + zone de contenu
  logo.svg              (existant)
  css/tokens.css        couleurs, typo, espacements, rayons repris de l'app
  css/ui.css            composants : bloc, chiffre clé, pastille, tag, tableau,
                        bouton, segmenté, panneau latéral, bandeau d'erreur
  js/api.js             fetch + Basic Auth, lecture de detail.code, messages FR
  js/router.js          routes hash (#/pilotage, #/testeuses/<id>, …)
  js/icons.js           SVG de l'app, générés depuis cg_icon.dart
  js/ui.js              petites fabriques DOM partagées (chiffre clé, graphique en
                        barres SVG, tag de statut, formatage dates et euros)
  js/views/<écran>.js   un module par écran
  fonts/                Instrument Sans (woff2) servie localement
```

- Tokens repris de `collega_app/lib/core/ui/tokens/` (`cg_colors.dart`,
  `cg_type.dart`, `cg_space.dart`, `cg_radius.dart`) : fond `ground` #ECEAE3,
  `surface` #F7F6F2, `ink` #17201F, accent `accent` #0E5E63, etc.
- Icônes : exactement celles de `CgIcons` (`collega_app/lib/core/ui/foundation/cg_icon.dart`,
  trait 1,8, grille 24). Deux icônes nouvelles dans le même style pour Coûts et
  Réglages, ajoutées **aussi** à `cg_icon.dart` pour garder une seule source.
  `icons.js` est généré par un petit script (`scripts/gen_admin_icons.py`) et un
  test vérifie qu'il est à jour.
- **Aucun emoji** dans toute la console.
- Graphiques : barres en SVG faites main, pas de bibliothèque.
- Session : identifiants Basic Auth gardés en `sessionStorage` (comme aujourd'hui) ;
  un `401` renvoie à l'écran de connexion.
- Adaptation téléphone : sous 760 px, le menu devient un tiroir ; les tableaux
  deviennent des listes.

### 3.2 Écrans

Menu latéral : Pilotage, Testeuses, Imports, Qualité des fiches, Coûts, Réglages,
avec pastilles centrées et discrètes (§ 2.3). Maquettes validées :
`.superpowers/brainstorm/65355-1790432466/content/layout.html` (option A) et
`screens-v2.html`.

1. **Connexion** : style de l'app, logo, bandeau d'erreur.
2. **Pilotage** (accueil) : 4 chiffres clés avec évolution ; bloc Testeuses
   (dernière activité, série, tag inactive / jamais connectée) ; bloc
   « À surveiller » (imports en échec ou bloqués, nouveaux avis négatifs, imports en
   cours). Chaque ligne mène au détail.
3. **Testeuses** : liste (nom, e-mail, création, dernière activité, série,
   collèges, beta) avec filtres Toutes / Actives / Inactives / Jamais connectées.
   Bouton « Nouvelle testeuse » → panneau latéral (e-mail, nom) qui crée le compte
   beta (`POST /v1/admin/users`) et affiche un **message d'invitation à copier**
   (lien TestFlight public tiré de `app_settings.testflight_url`, identifiant, mot
   de passe provisoire).
4. **Fiche testeuse** : en-tête (avatar initiales, e-mail, création, tag beta,
   actions Réinitialiser le mot de passe / le quota, Retirer la beta) ; 4 chiffres
   (dernière activité, série, fiches révisées 30 j, jours avec séance 30 j) ;
   graphique fiches révisées par jour sur 30 j ; ses collèges (statut, fiches,
   progression) ; ses derniers avis (icônes pouce de l'app).
5. **Imports** : en cours (progression rafraîchie toutes les 5 s tant que l'écran
   est ouvert) et historique filtrable (en échec, terminés) ; détail d'un import =
   timeline existante mise en forme, actions Arrêter et Supprimer.
6. **Qualité des fiches** : sélecteur de collège, segmenté Toutes / Avis négatifs /
   Confiance OCR faible, stats (fiches, items, % d'avis positifs, OCR faible),
   fiches rendues en cartes comme dans l'app (rang A/B/C, item, recto, verso, type,
   auteur de l'avis).
7. **Coûts** : coût Claude par jour sur 30 j (barres), par utilisatrice, par
   collège, coût moyen d'un import (données de `/v1/admin/usage` existant).
8. **Réglages** : limites anti-spam existantes + `inactivity_days` +
   `testflight_url`, formulaire avec explications.

### 3.3 Erreurs

Le client lit `detail.code` et affiche un message français dans un bandeau
(table de correspondance dans `api.js`, repli sur `detail.message`). Erreur réseau :
bandeau « Serveur injoignable » avec bouton Réessayer.

## 4. App (Flutter)

- Nouveau `ActivityReporter` (`collega_app/lib/features/today/data/activity_reporter.dart`) :
  calcule pour un jour `cards_reviewed` (somme de `verdictCounts(day)`),
  `session_completed` (jour dans `completedDays`) et `streak` (`streakLength`
  existant) et appelle `PUT /v1/activity/{day}`.
- Déclenché après `complete(day)` et après chaque verdict, avec un anti-rebond
  (30 s) pour ne pas envoyer à chaque fiche ; et au lancement de l'app, qui
  renvoie les **7 derniers jours** ayant de l'activité locale. L'envoi étant
  idempotent, pas besoin de mémoriser ce qui a déjà été confirmé.
- Hors ligne : échec silencieux, reprise au prochain déclenchement.
- Les builds de validation (`COLLEGA_TEST_TOOLS=true`) envoient comme les autres.
- `privacy.md` (app `assets/legal/` et backend `app/static/legal/`) : une phrase
  sur l'envoi des compteurs de révision quotidiens (nombre de fiches revues, séance
  terminée, série) pour le suivi de la beta et l'amélioration du service.

## 5. Tests

- **Backend (TDD)** : `last_seen_at` (écrit au login/refresh/me, pas plus d'une
  fois par 10 min) ; `PUT /v1/activity` (upsert idempotent, bornes, 401 sans
  jeton, cascade à la suppression de compte) ; `badges` (chaque règle, seuil
  réglable, `quality-seen`) ; `pilot` (chiffres et évolutions, statuts dérivés) ;
  fiche testeuse enrichie (série quotidienne avec jours vides) ;
  `scripts.import_alerts` (premier passage silencieux, nouvelles lignes,
  point de reprise) ; migration + `alembic check`.
- **Console** : test pytest qui vérifie que chaque fichier référencé par
  `index.html` et par les imports des modules existe ; test que `icons.js`
  correspond à `cg_icon.dart` ; puis vérification manuelle en local contre le
  backend de test, écran par écran, en largeur ordinateur et téléphone.
- **App** : tests de `ActivityReporter` (compteurs, anti-rebond, reprise hors ligne),
  `flutter test` par dossier.
- **Telegram** : essai réel en prod avec un import volontairement en échec.

## 6. Livraison

Branche `feat/console-pilotage`, commits par étape :

1. Backend données : migration (`last_seen_at`, `activity_days`), service et route
   d'activité, mise à jour de `last_seen_at`.
2. Routes admin : `pilot`, `badges`, fiche testeuse enrichie, réglages ajoutés.
3. Console front (tous les écrans).
4. App : `ActivityReporter` + `privacy.md`.
5. Alerte Telegram : `scripts.import_alerts` + `collega-health.sh`.

Puis CI verte, merge, déploiement par `scripts/deploy.sh` (dump avant migration),
copie du script de santé à jour sur le NAS, essai Telegram, et un build TestFlight
qui embarque à la fois le nouveau domaine et l'envoi d'activité.
