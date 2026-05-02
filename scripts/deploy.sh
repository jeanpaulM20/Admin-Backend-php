#!/bin/sh
# Nach jedem git pull auf dem Server ausfuehren: sh scripts/deploy.sh
set -e

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
NESTJS_DIR="$ROOT_DIR/nestjs-backend"

echo "==> Deploying NestJS backend..."
cd "$NESTJS_DIR"

npm ci
npm run build

# pm2 neu laden falls installiert, sonst Hinweis ausgeben
if command -v pm2 > /dev/null 2>&1; then
  pm2 reload sihl-nestjs --update-env
  echo "==> pm2 reloaded"
else
  echo "==> Build fertig. Bitte den NestJS-Prozess manuell neu starten."
fi

# Flutter Client-App deployen (pre-built im client/ Ordner)
echo ""
echo "==> Deploying Flutter client app..."
CLIENT_SRC="$ROOT_DIR/client"
# Standard Apache Webroot fuer client
CLIENT_DEST="/var/www/html/client"

if [ -d "$CLIENT_SRC" ] && [ -f "$CLIENT_SRC/main.dart.js" ]; then
  if [ -d "$(dirname "$CLIENT_DEST")" ]; then
    mkdir -p "$CLIENT_DEST"
    rsync -a --delete "$CLIENT_SRC/" "$CLIENT_DEST/"
    echo "==> Flutter client deployed to $CLIENT_DEST"
  else
    echo "==> SKIP: Zielordner $(dirname "$CLIENT_DEST") existiert nicht."
    echo "   Bitte manuell kopieren: cp -r $CLIENT_SRC/* /pfad/zum/webroot/client/"
  fi
else
  echo "==> SKIP: Keine gebauten Flutter-Dateien in $CLIENT_SRC gefunden."
fi

echo ""
echo "==> Deploy abgeschlossen!"
