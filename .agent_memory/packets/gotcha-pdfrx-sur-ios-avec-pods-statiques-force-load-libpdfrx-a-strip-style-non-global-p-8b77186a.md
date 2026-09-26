---
type: "Gotcha"
title: "pdfrx sur iOS avec pods statiques : force_load libpdfrx.a + STRIP_STYLE non-global + pdfiumModulePath"
description: "Le Podfile de collega app n'a pas use frameworks! pods statiques . pdfrx 1.0.103 fait DynamicLibrary.open 'pdfrx.framework/pdfrx' sur iOS → écran d'erreur « Failed to load dynamic library pdfrx.framework/pdfrx » à l'ouve"
resource: "collega_app/ios/Runner.xcodeproj/project.pbxproj"
tags: ["session-learning", "pdfrx", "ios", "ffi", "cocoapods"]
timestamp: "2026-09-26T13:06:11.594Z"
x-kage-id: "repo:git-github-com-tistech0-collega:gotcha:pdfrx-sur-ios-avec-pods-statiques-force-load-libpdfrx-a-strip-style-non-global-p"
x-kage-type: "gotcha"
x-kage-status: "approved"
x-kage-scope: "repo"
x-kage-visibility: "team"
x-kage-verified: "unverified"
x-kage-paths: ["collega_app/ios/Runner.xcodeproj/project.pbxproj", "collega_app/lib/main.dart", "collega_app/lib/features/pdf/presentation/pdf_document_view.dart", "collega_app/ios/Podfile"]
---

# pdfrx sur iOS avec pods statiques : force_load libpdfrx.a + STRIP_STYLE non-global + pdfiumModulePath

> Le Podfile de collega app n'a pas use frameworks! pods statiques . pdfrx 1.0.103 fait DynamicLibrary.open 'pdfrx.fram…

Le Podfile de collega_app n'a pas use_frameworks! (pods statiques). pdfrx 1.0.103 fait DynamicLibrary.open('pdfrx.framework/pdfrx') sur iOS → écran d'erreur « Failed to load dynamic library pdfrx.framework/pdfrx » à l'ouverture du lecteur, invisible en test (pdfium ne tourne pas sous flutter test). Rendre seulement le pod pdfrx dynamique via pre_install échoue (« transitive dependencies that include statically linked binaries (Flutter) »). Correctif en place : cible Runner, OTHER_LDFLAGS += -force_load "$(BUILT_PRODUCTS_DIR)/pdfrx/libpdfrx.a" (sans ça le linker écarte tout l'objet, aucune référence native) et STRIP_STYLE = non-global (3 configurations dans project.pbxproj), puis configurePdfium() dans main.dart pose Pdfrx.pdfiumModulePath = Platform.resolvedExecutable sur iOS. Contrôle : dyld_info -exports Runner.app/Runner | grep _FPDF_ doit lister les fonctions (46 FPDF + FORM, toutes celles utilisées par lib/src/pdfium).
Evidence: iPhone : erreur dlopen avant correctif ; après : dyld_info montre _FPDF_InitLibraryWithConfig et les 48 fonctions utilisées exportées, app réinstallée (commit f8cc1ab)

## Verification

iPhone : erreur dlopen avant correctif ; après : dyld_info montre _FPDF_InitLibraryWithConfig et les 48 fonctions utilisées exportées, app réinstallée (commit f8cc1ab)

# Citations

[1] explicit_capture (2026-09-26T13:06:11.594Z)

## Kage state

Machine state for lossless round-trip; OKF consumers can ignore it.

```json kage-state
{"schema_version":2,"id":"repo:git-github-com-tistech0-collega:gotcha:pdfrx-sur-ios-avec-pods-statiques-force-load-libpdfrx-a-strip-style-non-global-p","title":"pdfrx sur iOS avec pods statiques : force_load libpdfrx.a + STRIP_STYLE non-global + pdfiumModulePath","summary":"Le Podfile de collega app n'a pas use frameworks! pods statiques . pdfrx 1.0.103 fait DynamicLibrary.open 'pdfrx.framework/pdfrx' sur iOS → écran d'erreur « Failed to load dynamic library pdfrx.framework/pdfrx » à l'ouve","body":"Le Podfile de collega_app n'a pas use_frameworks! (pods statiques). pdfrx 1.0.103 fait DynamicLibrary.open('pdfrx.framework/pdfrx') sur iOS → écran d'erreur « Failed to load dynamic library pdfrx.framework/pdfrx » à l'ouverture du lecteur, invisible en test (pdfium ne tourne pas sous flutter test). Rendre seulement le pod pdfrx dynamique via pre_install échoue (« transitive dependencies that include statically linked binaries (Flutter) »). Correctif en place : cible Runner, OTHER_LDFLAGS += -force_load \"$(BUILT_PRODUCTS_DIR)/pdfrx/libpdfrx.a\" (sans ça le linker écarte tout l'objet, aucune référence native) et STRIP_STYLE = non-global (3 configurations dans project.pbxproj), puis configurePdfium() dans main.dart pose Pdfrx.pdfiumModulePath = Platform.resolvedExecutable sur iOS. Contrôle : dyld_info -exports Runner.app/Runner | grep _FPDF_ doit lister les fonctions (46 FPDF + FORM, toutes celles utilisées par lib/src/pdfium).\nEvidence: iPhone : erreur dlopen avant correctif ; après : dyld_info montre _FPDF_InitLibraryWithConfig et les 48 fonctions utilisées exportées, app réinstallée (commit f8cc1ab)","type":"gotcha","scope":"repo","visibility":"team","sensitivity":"internal","status":"approved","confidence":0.7,"tags":["session-learning","pdfrx","ios","ffi","cocoapods"],"paths":["collega_app/ios/Runner.xcodeproj/project.pbxproj","collega_app/lib/main.dart","collega_app/lib/features/pdf/presentation/pdf_document_view.dart","collega_app/ios/Podfile"],"stack":[],"source_refs":[{"kind":"explicit_capture","captured_at":"2026-09-26T13:06:11.594Z"}],"context":{"fact":"Le Podfile de collega_app n'a pas use_frameworks! (pods statiques). pdfrx 1.0.103 fait DynamicLibrary.open('pdfrx.framework/pdfrx') sur iOS → écran d'erreur « Failed to load dynamic library pdfrx.framework/pdfrx » à l'ouverture du lecteur, invisible en test (pdfium ne tourne pas sous flutter test). Rendre seulement le pod pdfrx dynamique via pre_install échoue (« transitive dependencies that include statically linked binaries (Flutter) »). Correctif en place : cible Runner, OTHER_LDFLAGS += -force_load \"$(BUILT_PRODUCTS_DIR)/pdfrx/libpdfrx.a\" (sans ça le linker écarte tout l'objet, aucune référence native) et STRIP_STYLE = non-global (3 configurations dans project.pbxproj), puis configurePdfium() dans main.dart pose Pdfrx.pdfiumModulePath = Platform.resolvedExecutable sur iOS. Contrôle : dyld_info -exports Runner.app/Runner | grep _FPDF_ doit lister les fonctions (46 FPDF + FORM, toutes celles utilisées par lib/src/pdfium).\nEvidence: iPhone : erreur dlopen avant correctif ; après : dyld_info montre _FPDF_InitLibraryWithConfig et les 48 fonctions utilisées exportées, app réinstallée (commit f8cc1ab)","verification":"iPhone : erreur dlopen avant correctif ; après : dyld_info montre _FPDF_InitLibraryWithConfig et les 48 fonctions utilisées exportées, app réinstallée (commit f8cc1ab)"},"freshness":{"ttl_days":365,"last_verified_at":"2026-09-26T13:06:11.594Z","path_fingerprints":[{"path":"collega_app/ios/Runner.xcodeproj/project.pbxproj","sha256":"cccbec953d0c07d460ca85e3acdbef68395455e458f72f2887126a7c5d08030a","size":32025},{"path":"collega_app/lib/main.dart","sha256":"0cd63a1b5d0dd9a42ba152129f6691c9d2c98789ac84950b6bca58620c5e9ac6","size":786},{"path":"collega_app/lib/features/pdf/presentation/pdf_document_view.dart","sha256":"861d160303135dfcdad705cd3bde963694fca608d2208fde78c7efecb0a5ebdc","size":2284},{"path":"collega_app/ios/Podfile","sha256":"c0a81546f5652bb65a0dfb2276483154cda3a4f90240f889f9df0f1acede282d","size":1457}],"path_fingerprint_policy":"source_hash_staleness","verification":"repo_local_agent_capture"},"edges":[],"quality":{"reviewer":"repo-local-agent","votes_up":0,"votes_down":0,"uses_30d":0,"reports_stale":0,"review_boundary":"git_or_pr","promotion_requires_review":true,"discovery_tokens":8000,"discovery_tokens_estimated":true,"score":100,"reasons":["high-value memory type","has source evidence","grounded to repo paths","tagged","concise but substantive","actionable rationale or verification"],"risks":[],"duplicate_candidates":[],"estimated_tokens_saved":279,"total_uses":0},"created_at":"2026-09-26T13:06:11.594Z","updated_at":"2026-09-26T13:06:11.594Z","author_branch":"feat/recherche-pdf-drill-accueil"}
```

