# Politique de Confidentialité

**Version : 2026-05-22**

La présente politique décrit comment **Collega** (« l'Application ») collecte, traite et
protège tes données personnelles conformément au Règlement Général sur la Protection des Données
(RGPD — Règlement UE 2016/679) et à la loi Informatique et Libertés.

---

## 1. Responsable du traitement

**Lesurmatthis** — contact : `jerome.lesur@astraga.fr`.

L'éditeur agit seul comme responsable du traitement au sens du RGPD.

---

## 2. Données collectées

### 2.1. Données fournies par toi à l'inscription et à l'usage

| Donnée | Origine | Finalité |
|---|---|---|
| Adresse email | Inscription | Authentification, contact support |
| Prénom (facultatif) | Profil | Personnalisation de l'interface |
| Année d'études (facultatif) | Profil | Statistiques d'usage agrégées |
| Faculté (facultatif) | Profil | Statistiques d'usage agrégées |
| PDF de collèges importés | Import utilisateur | Génération de fiches de révision |
| Texte de fiches généré | Pipeline IA | Affichage et révision dans l'Application |
| Évaluations de drill (à revoir / bien / maîtrisé) | Usage | Planning adaptatif, statistiques de progression |
| Token APNs (notifications push) | iOS, sur autorisation explicite | Rappels quotidiens et notifications de fin de génération |
| Heure de rappel quotidien (UTC) | Réglage profil | Envoi du push de rappel à l'heure choisie |

### 2.2. Données techniques

- Logs serveur (date, IP partielle, route appelée, code de réponse) — usage : sécurité, debug.
- Métriques d'usage anonymisées (nombre de sessions, durée moyenne) — usage : amélioration produit.

### 2.3. Données de paiement

Les paiements sont gérés par **Apple (In-App Purchase)** et **RevenueCat**. L'Application **ne stocke
aucune donnée bancaire**. Seul un identifiant d'abonnement RevenueCat est associé à ton compte
pour vérifier l'état actif/inactif.

---

## 3. Finalités et bases légales

| Finalité | Base légale RGPD |
|---|---|
| Exécution du contrat (inscription, accès aux fiches, drill) | Art. 6.1.b — Contrat |
| Envoi des notifications push | Art. 6.1.a — Consentement (autorisation iOS) |
| Sécurité et lutte contre l'abus | Art. 6.1.f — Intérêt légitime |
| Amélioration produit (métriques agrégées) | Art. 6.1.f — Intérêt légitime |
| Réponse aux obligations légales (conservation logs) | Art. 6.1.c — Obligation légale |

---

## 4. Durée de conservation

- **Données du compte (email, profil, fiches, drills)** : conservées tant que ton compte est actif.
  Supprimées **définitivement et immédiatement** à la suppression du compte (cf. § 7).
- **PDF importés** : conservés tant que le collège associé est dans ton compte.
- **Logs serveur** : 12 mois maximum (rotation automatique).
- **Token APNs** : supprimé dès le revoke d'autorisation iOS ou la déconnexion.

---

## 5. Destinataires et sous-traitants

Tes données sont accessibles aux personnes suivantes, dans les limites strictes de leur mission :

| Destinataire | Rôle | Localisation | Garanties |
|---|---|---|---|
| Éditeur (Lesurmatthis) | Responsable du traitement | France | — |
| **Anthropic** (Claude API) | Génération des fiches à partir des PDF | États-Unis | Clauses contractuelles types UE (DPA Anthropic). Les PDF transmis sont traités pour la génération puis conservés selon la politique de rétention de l'API Anthropic (30 jours par défaut, prolongation possible en cas d'enquête liée aux conditions d'utilisation Anthropic). |
| **Apple** (APNs + IAP) | Notifications push et paiements | États-Unis | Sous-traitant standard iOS. |
| **RevenueCat** | Gestion des abonnements IAP | États-Unis | DPA RevenueCat ; aucune donnée médicale transmise. |
| Hébergeur (NAS auto-hébergé Unraid + Caddy + PostgreSQL) | Stockage et exécution serveur | France | Infrastructure auto-hébergée par l'éditeur. |

Aucune donnée n'est cédée ou vendue à des tiers à des fins commerciales.

---

## 6. Transferts hors UE

Les sous-traitants Anthropic, Apple et RevenueCat sont situés aux États-Unis. Les transferts
s'appuient sur les Clauses Contractuelles Types adoptées par la Commission Européenne et, le cas
échéant, sur le cadre Data Privacy Framework UE/US.

Tu peux à tout moment demander les copies des garanties contractuelles applicables via
`jerome.lesur@astraga.fr`.

---

## 7. Tes droits RGPD

Tu disposes, à tout moment, des droits suivants :

- **Droit d'accès** : obtenir une copie des données te concernant (`GET /v1/auth/me` + export sur demande).
- **Droit de rectification** : modifier ton prénom, ton année, ta faculté depuis l'écran Profil.
- **Droit à l'effacement (« droit à l'oubli »)** : supprimer définitivement ton compte et toutes
  les données associées via le bouton **« Supprimer mon compte »** de l'écran Profil. La suppression
  est **immédiate, irréversible et complète** (collèges, fiches, drills, planning, token APNs).
- **Droit à la portabilité** : sur demande à `jerome.lesur@astraga.fr`, un export structuré (JSON)
  de tes données te sera fourni sous 30 jours.
- **Droit d'opposition** : tu peux refuser les notifications push à tout moment depuis Réglages iOS
  → Notifications.
- **Droit de réclamation** : tu peux saisir la **CNIL** (Commission Nationale Informatique et Libertés)
  à l'adresse `https://www.cnil.fr/fr/plaintes`.

---

## 8. Sécurité

L'Application met en œuvre des mesures techniques et organisationnelles adaptées :

- chiffrement HTTPS / TLS de bout en bout côté API ;
- mots de passe stockés sous forme de **hash bcrypt** (jamais en clair) ;
- tokens JWT stockés dans le **Keychain iOS** (`flutter_secure_storage`) ;
- séparation backend / frontend ; rate limiting des routes sensibles (login, refresh, suppression de compte) ;
- backups réguliers de la base de données PostgreSQL côté éditeur.

En cas de violation de données, l'éditeur s'engage à notifier la CNIL et les utilisateurs concernés
dans les délais légaux (72h).

---

## 9. Modifications

La présente politique peut évoluer. Toute modification substantielle (nouveau sous-traitant,
nouvelle finalité) te sera notifiée via l'Application ; ton consentement explicite pourra être
demandé selon le cas.

---

## 10. Contact

Pour toute question relative au traitement de tes données ou à l'exercice de tes droits :

**Email** : `jerome.lesur@astraga.fr`

Un délai de réponse maximum d'**un mois** s'applique (extensible à deux mois pour les demandes
complexes, après information préalable).
