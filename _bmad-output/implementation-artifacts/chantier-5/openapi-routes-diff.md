# Routes OpenAPI — avant / après chantier 5 (tâche 5, découpage en paquets)

Générées avec DATABASE_URL=sqlite+aiosqlite:///x.db REDIS_URL=redis://x SECRET_KEY=x CLAUDE_API_KEY=x ADMIN_PASSWORD=x REVENUECAT_WEBHOOK_SECRET=x, « MÉTHODE chemin » triés par chemin puis méthode sur app.openapi()["paths"].

`diff openapi-routes-before.txt openapi-routes-after.txt` :

```
48,51d47
< GET /v1/tester/colleges
< GET /v1/tester/colleges/{college_id}/items
< GET /v1/tester/colleges/{college_id}/summary
< POST /v1/tester/flash-cards/{card_id}/feedback
```

Seules les 4 routes /v1/tester/* (supprimées en tâche 1) disparaissent. Contrôle complémentaire : la spec OpenAPI complète (chemins, paramètres, schémas, tags) est identique avant/après le découpage ; seul l'ordre d'enregistrement des routes admin change (regroupées par sous-module), sans effet puisqu'aucun chemin admin ne se recoupe. L'ordre des routes collèges est inchangé.
