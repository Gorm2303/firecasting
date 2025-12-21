# firecasting

This repo contains the local dev deployment setup for Firecasting (frontend + backend + Postgres + Traefik).

## Dev stack

From the repo root:

- `docker compose -f deploy/dev/compose.yml up --build -d`

The frontend and API are routed via Traefik. By default the compose file expects:

- Frontend: `https://fire.local.test`
- API: `https://api.local.test`

You can override these with `FRONT_HOST` and `API_HOST` environment variables.

## UI notes

- Simulation results are shown as charts (phase charts + failed-cases summary). The legacy results “Table” view has been removed.

