# Dev TLS certificates (mkcert)

Goal: make `https://fire.local.test.dk` and `https://api.local.test.dk` work in the browser without certificate warnings.

## Prereqs
- Windows: run PowerShell as your normal user; `mkcert -install` may prompt for elevation to trust the local CA.
- Install `mkcert`:
  - `winget install --id FiloSottile.mkcert`
  - or `choco install mkcert`

## Generate + trust certs
From the repo root `firecasting/`:

- `powershell -ExecutionPolicy Bypass -File .\deploy\dev\traefik\generate-dev-certs.ps1`

This writes:
- `deploy/dev/traefik/certs/dev-local.crt`
- `deploy/dev/traefik/certs/dev-local.key`

These files are gitignored.

## Restart Traefik
- `docker compose --project-name firecasting-dev -f .\deploy\dev\compose.yml --env-file .\deploy\dev\.env up -d --force-recreate traefik`

## Verify
- Open `https://fire.local.test.dk/` (should show a normal lock)
- Open `https://api.local.test.dk/actuator/health`

## Notes
- Traefik is configured (file provider) in `deploy/dev/traefik/dynamic.yml` to load the above cert/key.
- If you change hostnames in `.env`, re-run the script with `-Hosts` including the new names.
