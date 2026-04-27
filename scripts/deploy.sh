#!/bin/sh
# Nach jedem git pull auf dem Server ausführen: sh scripts/deploy.sh
set -e

NESTJS_DIR="$(cd "$(dirname "$0")/../nestjs-backend" && pwd)"

echo "==> Deploying NestJS backend..."
cd "$NESTJS_DIR"

npm ci --only=production=false
npm run build

# pm2 neu laden falls installiert, sonst Hinweis ausgeben
if command -v pm2 > /dev/null 2>&1; then
  pm2 reload sihl-nestjs --update-env
  echo "==> pm2 reloaded"
else
  echo "==> Build fertig. Bitte den NestJS-Prozess manuell neu starten."
fi
