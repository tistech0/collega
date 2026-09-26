---
type: "Runbook"
title: "Logo Collega : source unique et régénération de l'icône iOS"
description: "The Collega logo ring of the three rank colours around a stack of cards, on the teal accent has a single source: collega app/assets/brand/logo.svg. It is embedded as CgLogo.svg lib/core/ui/brand/cg logo.dart ; a test che"
resource: "collega_app/assets/brand/logo.svg"
tags: ["session-learning", "brand", "logo", "ios-icon"]
timestamp: "2026-09-23T15:39:10.837Z"
x-kage-id: "repo:git-github-com-tistech0-collega:runbook:logo-collega-source-unique-et-r-g-n-ration-de-lic-ne-ios-1790177950839"
x-kage-type: "runbook"
x-kage-status: "approved"
x-kage-scope: "repo"
x-kage-visibility: "team"
x-kage-verified: "unverified"
x-kage-paths: ["collega_app/assets/brand/logo.svg", "collega_app/lib/core/ui/brand/cg_logo.dart", "collega_app/tool/icon/render_icon_test.dart", "collega_app/tool/icon/make_icons.py", "collega_app/ios/Runner/Base.lproj/LaunchScreen.storyboard"]
---

# Logo Collega : source unique et régénération de l'icône iOS

> The Collega logo ring of the three rank colours around a stack of cards, on the teal accent has a single source: coll…

The Collega logo (ring of the three rank colours around a stack of cards, on the teal accent) has a single source: collega_app/assets/brand/logo.svg. It is embedded as CgLogo.svg (lib/core/ui/brand/cg_logo.dart); a test checks the two stay identical.
- To change the logo: edit logo.svg, paste its content into CgLogo.svg, then run `flutter test tool/icon/render_icon_test.dart && python3 tool/icon/make_icons.py` from collega_app. This renders the 1024 px full-bleed icon and the 360 px rounded launch image with Flutter, then produces every AppIcon size (RGB, no alpha) and the LaunchImage images with PIL.
- The iOS launch screen has the stone background #ECEAE3 with the 120 pt logo centred. The /splash route shows the same logo at the same place, so the app opens without a jump.
- Also copy the logo to collega_backend/app/static/logo.svg and collega_backend/app/static/admin/logo.svg (favicons).
- There are no rsvg or ImageMagick tools on the Mac; PIL is available.
Verified by: icons generated and installed on iPhone (commit 87986a0)

## Verification

icons generated and installed on iPhone (commit 87986a0)

# Citations

[1] explicit_capture (2026-09-23T15:39:10.837Z)

## Kage state

Machine state for lossless round-trip; OKF consumers can ignore it.

```json kage-state
{"schema_version":2,"id":"repo:git-github-com-tistech0-collega:runbook:logo-collega-source-unique-et-r-g-n-ration-de-lic-ne-ios-1790177950839","title":"Logo Collega : source unique et régénération de l'icône iOS","summary":"The Collega logo ring of the three rank colours around a stack of cards, on the teal accent has a single source: collega app/assets/brand/logo.svg. It is embedded as CgLogo.svg lib/core/ui/brand/cg logo.dart ; a test che","body":"The Collega logo (ring of the three rank colours around a stack of cards, on the teal accent) has a single source: collega_app/assets/brand/logo.svg. It is embedded as CgLogo.svg (lib/core/ui/brand/cg_logo.dart); a test checks the two stay identical.\n- To change the logo: edit logo.svg, paste its content into CgLogo.svg, then run `flutter test tool/icon/render_icon_test.dart && python3 tool/icon/make_icons.py` from collega_app. This renders the 1024 px full-bleed icon and the 360 px rounded launch image with Flutter, then produces every AppIcon size (RGB, no alpha) and the LaunchImage images with PIL.\n- The iOS launch screen has the stone background #ECEAE3 with the 120 pt logo centred. The /splash route shows the same logo at the same place, so the app opens without a jump.\n- Also copy the logo to collega_backend/app/static/logo.svg and collega_backend/app/static/admin/logo.svg (favicons).\n- There are no rsvg or ImageMagick tools on the Mac; PIL is available.\nVerified by: icons generated and installed on iPhone (commit 87986a0)","type":"runbook","scope":"repo","visibility":"team","sensitivity":"internal","status":"approved","confidence":0.7,"tags":["session-learning","brand","logo","ios-icon"],"paths":["collega_app/assets/brand/logo.svg","collega_app/lib/core/ui/brand/cg_logo.dart","collega_app/tool/icon/render_icon_test.dart","collega_app/tool/icon/make_icons.py","collega_app/ios/Runner/Base.lproj/LaunchScreen.storyboard"],"stack":[],"source_refs":[{"kind":"explicit_capture","captured_at":"2026-09-23T15:39:10.837Z"}],"context":{"fact":"The Collega logo (ring of the three rank colours around a stack of cards, on the teal accent) has a single source: collega_app/assets/brand/logo.svg. It is embedded as CgLogo.svg (lib/core/ui/brand/cg_logo.dart); a test checks the two stay identical.\n- To change the logo: edit logo.svg, paste its content into CgLogo.svg, then run `flutter test tool/icon/render_icon_test.dart && python3 tool/icon/make_icons.py` from collega_app. This renders the 1024 px full-bleed icon and the 360 px rounded launch image with Flutter, then produces every AppIcon size (RGB, no alpha) and the LaunchImage images with PIL.\n- The iOS launch screen has the stone background #ECEAE3 with the 120 pt logo centred. The /splash route shows the same logo at the same place, so the app opens without a jump.\n- Also copy the logo to collega_backend/app/static/logo.svg and collega_backend/app/static/admin/logo.svg (favicons).\n- There are no rsvg or ImageMagick tools on the Mac; PIL is available.\nVerified by: icons generated and installed on iPhone (commit 87986a0)","verification":"icons generated and installed on iPhone (commit 87986a0)"},"freshness":{"ttl_days":365,"last_verified_at":"2026-09-23T15:39:10.837Z","path_fingerprints":[{"path":"collega_app/assets/brand/logo.svg","sha256":"209042bd71294cfb1bbf15fc2393406458be2be7c9ce53a38c22ba5c70626903","size":660},{"path":"collega_app/lib/core/ui/brand/cg_logo.dart","sha256":"9e7e889f1303921444293e4aea0ef32cc3937f81572841ac816141451d7e1884","size":1742},{"path":"collega_app/tool/icon/render_icon_test.dart","sha256":"a547f32d3145e8acc5ca6858cd93a4d66b3d7f8ae65311af3cfa985b508c9ac1","size":1726},{"path":"collega_app/tool/icon/make_icons.py","sha256":"8c344afe0363d5ea0a09dfefb646f520a2e37416f1b2a3a9e3aa588ed7d2a877","size":975},{"path":"collega_app/ios/Runner/Base.lproj/LaunchScreen.storyboard","sha256":"2c2df2e8d766b485ae0cc94ffdd50a57678ca9f3629ef01584c625016602f2a2","size":2430}],"path_fingerprint_policy":"source_hash_staleness","verification":"repo_local_agent_capture"},"edges":[],"quality":{"reviewer":"repo-local-agent","votes_up":0,"votes_down":0,"uses_30d":20,"reports_stale":0,"review_boundary":"git_or_pr","promotion_requires_review":true,"discovery_tokens":2000,"discovery_tokens_estimated":true,"score":100,"reasons":["high-value memory type","has source evidence","grounded to repo paths","tagged","concise but substantive","actionable rationale or verification"],"risks":[],"duplicate_candidates":[],"estimated_tokens_saved":261,"total_uses":42,"last_accessed_at":"2026-09-26T13:06:11.374Z"},"created_at":"2026-09-23T15:39:10.837Z","updated_at":"2026-09-23T15:39:10.837Z","author_branch":"feat/redesign-ux-ui"}
```

