# Beta TestFlight : check-list et passation (préparée le 2026-09-25)

**Objectif :** une vraie beta via TestFlight pour la sœur de Matthis et N testeurs. **Pas d'abonnement App Store pour l'instant** : l'accès passe par le drapeau `is_beta` (garde backend `is_subscribed OR is_beta`, `app/deps.py`), activé depuis la console admin.

**Point de départ :**
- `main` @ `001f7ec` : refonte back/infra mergée, CI verte.
- Prod `df1e4ef` (même backend).
- 3 collèges importés (PNEUMO, CANCERO, HEMATO), 2 186 fiches p2.
- Inscription fermée volontairement (403 `REGISTRATION_DISABLED`) : les comptes sont créés depuis la console admin.

---

## 1. Ce que Matthis doit faire (Claude ne peut pas le faire à sa place)

Ordre conseillé. Les durées sont indicatives.

### A. Compte Apple Developer (bloquant, 24 à 48 h de validation)
- [ ] S'inscrire au **Apple Developer Program** (99 €/an, en individuel : « Matthis Lesur » apparaît comme vendeur).
- [ ] Donner à Claude le **Team ID** de ce compte : il remplace `QKZD5PQK4U` dans le projet Xcode s'il est différent.

### B. App Store Connect (environ 15 min)
- [ ] **Certificates, Identifiers & Profiles → Identifiers :** enregistrer `com.lesurmatthis.collegaApp` avec la capacité **Push Notifications**. Xcode peut aussi le faire lors de la première signature automatique.
- [ ] **App Store Connect → Mes apps → + :**
  - nom « Collega » (s'il est pris, prendre une variante, par exemple « Collega EDN ») ;
  - langue principale français ;
  - bundle `com.lesurmatthis.collegaApp` ;
  - SKU `collega-ios`.
- [ ] Aucun contrat payant, aucune banque, aucune fiscalité à remplir : pas d'abonnement pour la beta.

### C. Clés Apple (environ 10 min)
- [ ] **Clé APNs (push) :**
  - Keys → + → cocher *Apple Push Notifications service (APNs)* ;
  - télécharger le `.p8` (téléchargeable **une seule fois**) et noter le **Key ID** ;
  - ne **pas** coller la clé dans le chat : Claude dira où la déposer sur le NAS.
- [ ] **(Recommandé) Clé API App Store Connect :**
  - Users and Access → Integrations → App Store Connect API → + ;
  - rôle *App Manager* ;
  - garder le `.p8`, le **Key ID** et l'**Issuer ID**.
  - Avec ces trois éléments, Claude envoie les builds tout seul (`xcrun altool` ou `fastlane`). Sans eux, Matthis envoie chaque build via Xcode → Organizer.

### D. TestFlight (après le premier build envoyé)
- [ ] **Informations de test** (onglet TestFlight). Claude prépare les textes :
  - description de la beta ;
  - « quoi tester » ;
  - e-mail de contact `contact@matthislesur.com` ;
  - URL de la politique de confidentialité ;
  - **compte de démo** pour la revue d'Apple, créé par Claude.
- [ ] Créer un **groupe externe** (par exemple « Beta ») et ajouter le build. Le **premier build externe passe la Beta App Review** (souvent moins de 24 à 48 h). Les suivants passent en général sans attendre.
- [ ] Inviter les testeurs par e-mail, ou activer le **lien public** (plus simple pour N personnes).
- [ ] Les testeurs installent **TestFlight** sur leur iPhone, puis acceptent l'invitation.

### E. Testeurs et budget
- [ ] Donner la **liste des testeurs** (prénom et e-mail) : Claude crée leurs comptes Collega avec `is_beta` et un mot de passe provisoire, et Matthis les leur transmet.
- [ ] Fixer un **budget Claude** :
  - environ **1,5 à 2 € par collège importé** (mesuré le 2026-09-25) ;
  - limites réglables dans la console admin (Config → anti-spam et réimports).
- [ ] Faire le **test hors du Wi-Fi de la maison** (4G) sur le build TestFlight : import d'un gros PDF, puis révision. Ce parcours n'a jamais été testé.

---

## 2. Ce que Claude fait (session suivante)

### App (branche dédiée, TDD, tests par dossier)
1. **Push :**
   - capacité *Push Notifications* et *Background Modes → Remote notifications* ;
   - fichier `Runner.entitlements` avec `aps-environment` ;
   - aujourd'hui aucun entitlement n'existe : les push ne peuvent pas marcher.
2. **`Info.plist` :** `ITSAppUsesNonExemptEncryption = false` (HTTPS standard seulement), sinon App Store Connect pose la question à chaque build.
3. **Script `tool/build_ipa.sh` :**
   - `flutter build ipa --release` avec les `--dart-define` Cloudflare Access lus dans `.env.local`, comme `tool/run_device.sh` ;
   - numéro de build incrémenté à chaque envoi (`version: 1.0.0+N`) ;
   - envoi via la clé API si elle est fournie.
4. **Paywall et RevenueCat :**
   - un testeur `is_beta` ne doit jamais voir de paywall ;
   - `Purchases.configure` avec la clé provisoire de `env.dart` (pas une clé iOS `appl_…`) ne doit ni planter ni afficher d'erreur ;
   - sinon, désactiver RevenueCat tant qu'il n'y a pas d'abonnement.
5. **Parcours d'un nouvel utilisateur :** premier lancement, connexion avec le compte fourni, import, révision. Vérifier les textes (CGU et confidentialité : éditeur Matthis Lesur, contact@matthislesur.com).

### Backend et infra
6. **APNs en prod :**
   - ajouter les lignes `APNS_KEY_PATH`, `APNS_KEY_ID`, `APNS_TEAM_ID`, `APNS_BUNDLE_ID=com.lesurmatthis.collegaApp`, `APNS_USE_SANDBOX=false` dans le `.env` du NAS (ajout seulement, jamais d'écrasement) ;
   - corriger le défaut `apns_bundle_id = "com.lesurmatthis.collega"` dans `app/core/config.py`, qui ne correspond pas au bundle de l'app ;
   - piège : TestFlight utilise l'APNs **de production**, alors qu'une build installée depuis Xcode donne un jeton **sandbox**. Soit tous les iPhones passent par TestFlight, soit le backend mémorise l'environnement de chaque jeton.
7. **Pages publiques** de confidentialité et de support (exigées par App Store Connect) :
   - servies par l'API ou par NPM ;
   - chemin laissé **hors Cloudflare Access** (bypass sur le chemin) ;
   - contact `contact@matthislesur.com`.
8. **Comptes :** compte de démo pour la revue d'Apple (avec `is_beta`, un collège déjà importé) et comptes des testeurs.
9. **Charge :**
   - un seul worker OCR et `generation_concurrency` 2 : plusieurs imports simultanés font la queue ;
   - vérifier que la supervision (`collega-health`, alerte Telegram) couvre la beta ;
   - surveiller les coûts dans la console (Usage).
10. **Test hors LAN** depuis le Mac (`--cloudflare-ip`) avant la revue, en complément du test 4G de Matthis.

### Hors périmètre de la beta (plus tard)
- Abonnement App Store et RevenueCat (produits, webhook, sandbox).
- Captures et fiche App Store publique.
- Correctif proposé : tronquer le rang B avant le rang A au-delà de 40 fiches (14 items concernés), en attente du retour de la sœur.

---

## 3. Prompt de départ (à coller dans la nouvelle session)

> On prépare la beta TestFlight de Collega. Lis `_bmad-output/planning-artifacts/beta-testflight-handoff.md` et suis-le. Pas d'abonnement App Store : l'accès beta passe par `is_beta`. Fais toute la partie « Ce que Claude fait » sur une branche `feat/beta-testflight` (plan, puis TDD, revue, déploiement du backend par `deploy.sh`), et guide-moi pas à pas sur la partie « Ce que Matthis doit faire » en me disant à chaque étape exactement quoi cliquer. Ma situation : [compte Apple Developer : fait / en cours / pas fait] ; [clé API App Store Connect : oui / non] ; testeurs : [liste ou nombre].
