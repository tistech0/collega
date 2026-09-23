# Story 8.15 : Retrait de shadcn_ui, VoiceOver, contrastes

Status: done

## Story

En tant qu'**étudiante**, je veux une app cohérente de bout en bout et utilisable à VoiceOver, avec des textes
lisibles ; en tant que développeur, plus aucune trace du design system v1.

## Critères d'acceptance (epic 8 § 8.15, spec v2 § Accessibilité)

1. `shadcn_ui` et `google_fonts` retirés du `pubspec` ; `lib/core/theme/app_theme.dart` (v1) supprimé ; l'app est un
   `MaterialApp.router` technique thémé par `buildCgMaterialTheme` + `CgTheme` ; widgets orphelins v1 supprimés
   (`DrillEvaluationBar`, `ErrorView`). Un test garde-fou échoue si `lib/` réimporte shadcn ou le thème v1.
2. VoiceOver sur les 5 écrans cœur (Aujourd'hui, Bibliothèque, Drill, Progression, Profil) : guidelines Flutter
   `labeledTapTargetGuideline`, `iOSTapTargetGuideline` (44 pt) et `textContrastGuideline` vérifiées en test ;
   tout défaut trouvé est corrigé.
3. Contrastes : paires de tokens texte / fond vérifiées (≥ 4,5:1 texte courant, ≥ 3:1 grands textes / éléments
   graphiques) ; goldens des 5 écrans cœur à jour.

## Tâches

- [x] T1 Garde-fou + retrait shadcn / thème v1 / orphelins ; `MaterialApp.router` ; tests routeur
- [x] T2 Guidelines d'accessibilité sur les 5 écrans cœur + correctifs
- [x] T3 Contrastes des tokens + goldens ; revue adversariale ; build iPhone
