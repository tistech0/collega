# Story 8.14 : Profil, paywall, CGU

Status: in-progress

## Story

En tant qu'**étudiante**, je veux un Profil lisible où je vois et règle mon compte, mon accès, mes préférences de
révision et mon rappel ; un paywall qui dit ce que l'abonnement donne ; des CGU lisibles aux styles de l'app.

## Critères d'acceptance (spec v2 § Profil, § Paywall, § Hiérarchie des actions ; audit « Profil », « Paywall, CGU »)

1. **Profil** (onglet, Collega UI, plus aucune carte shadcn / Material) : `CgPage` « Profil », groupes `CgListGroup.inset`
   avec intertitres :
   - **Compte** : prénom (ou « Ajoute ton prénom » en invitation, jamais « — »), email ; tap → sheet « Modifier le profil »
     (prénom requis, année, faculté ; erreurs inline ; « Enregistrer »). Badge `CgBadge.beta` avec explication
     « Accès offert pendant la beta privée ».
   - **Abonnement** : abonné → « Collega Premium · actif », renouvellement / résiliation datés, « Gérer mon abonnement » ;
     beta sans abonnement → pas de « Gérer » (on n'a rien à gérer). **Réimports ce mois : « 0 sur 3 »**, barre vide à 0,
     pleine à 3/3, « se renouvelle le 1er octobre » (jamais « reimports »).
   - **Révision** : rangs par défaut = trois lignes cochables A / B / C (état visible sans la couleur : coche), au moins un ;
     tous cochés = « tous » ; fiches par session (Toutes, 10, 20, 30, 50 ; valeur hors liste conservée) ; chronomètre
     (segmented Désactivé / Activé / Demander) et durée par carte si actif.
   - **Rappel** : `CupertinoSwitch` « Rappel quotidien », heure **locale** (« 08:00 ») choisie à la roue iOS ;
     l'état vient du serveur (plus d'interrupteur qui repart éteint à chaque ouverture).
   - **Application** : CGU, Confidentialité (chevrons), version.
   - « Se déconnecter » = `CgButton.secondary` (neutre, jamais rouge) ; « Supprimer mon compte » = action quiet qui ouvre
     une **action sheet** avec l'action destructive et la conséquence écrite (abonnement actif : l'annuler dans Réglages).
2. Données fraîches : ouvrir le Profil (et tirer pour rafraîchir) relit `/v1/auth/me` ; échec réseau = on garde l'affiché.
   Serveur : `/me` renvoie le quota **du mois en cours** (0 si la date de renouvellement est passée),
   `monthly_reloads_reset_at` et `reminder_hour_utc`.
3. Erreurs dites sur place (toast Collega pour une préférence non enregistrée, inline dans la sheet), jamais `e.toString()`.
4. **Paywall** : bloc `accent` (wordmark, « Collega Premium »), liste de bénéfices (`CgListRow`), prix (« 9,99 €/mois »
   du Store, sinon rien d'inventé), « Sans engagement, résiliable dans Réglages », un primaire « S'abonner »,
   quiet « Restaurer mes achats », quiet « Se déconnecter », liens CGU / Confidentialité (App Store 3.1.2).
   Offre indisponible → message + « Réessayer ». Achat annulé = rien d'affiché ; erreurs inline.
5. **CGU / Confidentialité** : `CgPage` avec « ‹ Retour », Markdown aux styles `CgType`, chargement `CgSkeleton`,
   erreur `CgState.error` + « Réessayer » (plus de `snapshot.error`).
6. Shell : le Profil n'est plus « legacy » (réserve lui-même la tab bar, re-tap remonte en haut).
7. Accessibilité : lignes = un nœud (titre, valeur), switch étiqueté, 44 pt, Dynamic Type 1,6 sans débordement.
   Goldens 3 largeurs × 2 échelles : Profil (beta), paywall, CGU.

## Tâches

- [x] T1 Serveur `/me` : quota du mois en cours, date de renouvellement, heure du rappel (+ tests)
- [ ] T2 App : `AuthUser.reminderHourUtc / monthlyResetAt`, `AuthNotifier.refreshProfile()` et `setReminderHour()`
- [ ] T3 `ProfileScreen` Collega UI (+ sheet profil, rangs, fiches, rappel, suppression) + tests + goldens
- [ ] T4 `PaywallScreen` Collega UI + tests + goldens
- [ ] T5 `LegalScreen` Collega UI + tests + goldens
- [ ] T6 Shell : Profil hors legacy ; revue adversariale ; déploiement serveur ; build iPhone

## Dev Notes

- Composants : `CgPage`, `CgListGroup(variant: inset)`, `CgListRow` (`value`, `check`, `custom` + `CupertinoSwitch`),
  `CgSectionTitle`, `CgSegmented`, `CgField`, `showCgSheet`, `showCgActionSheet`, `showCgToast`, `CgBadge.beta`, `CgButton`.
- Heure du rappel : le serveur stocke une heure UTC ; l'app convertit avec le décalage du jour
  (`DateTime(y, m, d, h).toUtc().hour`), affiche l'heure locale.
- `refreshFromMe` échoue → `AuthState(errorMessage)` sans user : ne **jamais** l'appliquer (déconnecterait).
