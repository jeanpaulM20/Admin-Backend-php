#!/bin/sh
# Einmalig auf dem Server ausführen: sh scripts/server-setup.sh
# Voraussetzung: Node.js >= 18 und npm verfügbar

set -e

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
NESTJS_DIR="$REPO_DIR/nestjs-backend"
ENV_FILE="$NESTJS_DIR/.env"

echo "==> Arbeitsverzeichnis: $NESTJS_DIR"

# 1. Node.js prüfen
node --version || { echo "ERROR: Node.js nicht gefunden. Bitte installieren."; exit 1; }

# 2. .env anlegen falls nicht vorhanden
if [ ! -f "$ENV_FILE" ]; then
  cp "$NESTJS_DIR/.env.example" "$ENV_FILE"
  echo ""
  echo "WICHTIG: $ENV_FILE wurde angelegt."
  echo "Bitte DB_PASSWORD und AUTH_SALT eintragen, dann dieses Script erneut ausführen."
  exit 0
fi

# 3. Abhängigkeiten installieren & bauen
cd "$NESTJS_DIR"
npm ci
npm run build

echo ""
echo "==> Build erfolgreich. NestJS kann gestartet werden mit:"
echo "    cd $NESTJS_DIR && npm start"
echo ""
echo "==> Für Dauerbetrieb mit pm2:"
echo "    npm install -g pm2"
echo "    pm2 start dist/main.js --name sihl-nestjs"
echo "    pm2 save && pm2 startup"
