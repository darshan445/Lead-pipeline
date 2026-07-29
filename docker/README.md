# Docker

## Solid Queue

**No separate worker.** `SOLID_QUEUE_IN_PUMA=true` runs background jobs inside Puma (discovery, pitches, staggered Gmail sends).

## Development

```bash
docker compose up --build
```

Open http://localhost:3000

## Production (Vultr — IP only, plain HTTP)

No domain, SSL, Caddy, or nginx. Just the VPS IP.

```bash
cp docker/env.production.example .env.production
# set SECRET_KEY_BASE, POSTGRES_PASSWORD, API/Gmail keys
# set GMAIL_REDIRECT_URI=http://YOUR_VULTR_IP/gmail/oauth/callback

docker compose -f docker-compose.production.yml --env-file .env.production up -d --build
```

Open: **http://YOUR_VULTR_IP/**

Generate secret:

```bash
openssl rand -hex 64
```

### Gmail OAuth on IP

In Google Cloud → OAuth client → Authorized redirect URIs, add:

`http://YOUR_VULTR_IP/gmail/oauth/callback`

(Must match `GMAIL_REDIRECT_URI` exactly, including `http://`.)
