# LibreChat on ai.ombhrum.com

This deployment keeps Cloudflare in DNS/proxy mode only. Do not create or attach a
Cloudflare Worker for `ai.ombhrum.com`.

## Topology

- `https://ai.ombhrum.com/` -> LibreChat Web on `127.0.0.1:3080`
- `https://ai.ombhrum.com/api/ai/*` -> Dacheng AI bridge on `127.0.0.1:8788`
- `https://ai.ombhrum.com/api/resources/*` -> Dacheng AI bridge resource tools
- `https://ai.ombhrum.com/health` -> Dacheng AI bridge health endpoint

Cloudflare may keep the record proxied. If SSE streaming or WebSocket upgrades
misbehave, switch only this DNS record to DNS-only and keep the same origin
configuration.

## Deploy

1. Point Cloudflare DNS at the VPS:

   ```bash
   CF_API_TOKEN=... CF_ZONE_ID=... AI_ORIGIN_IP=... ./upsert-cloudflare-dns.sh
   ```

2. Copy this directory to `bhrum1`, then run:

   ```bash
   sudo DOMAIN=ai.ombhrum.com ./install-on-bhrum1.sh
   ```

3. Configure LibreChat secrets in `/opt/librechat/current/.env`.

   Keep `DOMAIN_CLIENT=https://ai.ombhrum.com`, `DOMAIN_SERVER=https://ai.ombhrum.com`,
   and `TRUST_PROXY=1`. Generate fresh `CREDS_IV`, `CREDS_KEY`, `JWT_SECRET`,
   and `JWT_REFRESH_SECRET`; do not commit them.

4. Restart services:

   ```bash
   sudo systemctl restart dacheng-ai-backend
   sudo systemctl reload caddy
   cd /opt/librechat/current
   sudo docker compose up -d
   ```

## Verification

```bash
curl -I https://ai.ombhrum.com
curl -s https://ai.ombhrum.com/health
curl -N https://ai.ombhrum.com/api/ai/chat/stream \
  -H 'Content-Type: application/json' \
  -d '{"message":"请用一句话介绍大乘 AI","clientMembershipHint":true}'
```

The last command should stream server-sent events from the same bridge contract
the Flutter app already consumes.
