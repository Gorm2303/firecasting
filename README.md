# firecasting

This repo contains the local dev deployment setup for Firecasting (frontend + backend + Postgres + Traefik).

## Dev stack

From the repo root:

- `docker compose -f deploy/dev/compose.yml up --build -d`

Logs (run from the repo root):

- `docker compose -f deploy/dev/compose.yml logs -f api`
- `docker compose -f deploy/dev/compose.yml logs -f frontend`

Black-box public API verification (includes SSE/export/import/diff):

- `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/verify-public-api.ps1`

Stop / reset helpers (PowerShell):

- Stop stack: `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev-stack-stop.ps1 -Force`
- Reset DB (deletes Postgres volume): `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev-stack-reset-db.ps1 -Force`

The frontend and API are routed via Traefik. By default the compose file expects:

- Frontend: `https://fire.local.test`
- API: `https://api.local.test`

You can override these with `FRONT_HOST` and `API_HOST` environment variables.

## UI notes

- Simulation results are shown as charts (phase charts + failed-cases summary). The legacy results “Table” view has been removed.

