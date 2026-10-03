#!/bin/sh
# Startet den BRouter-Server. Fehlende oder veraltete Kartenkacheln werden
# vorher von brouter.de geladen (Schweiz = E5_N45 + E10_N45, ~450 MB).
set -u

DATA="${BROUTER_DATA:-/data}"
SEGMENTS="$DATA/segments4"
TILES="${BROUTER_SEGMENTS:-E5_N45 E10_N45}"
MAX_AGE_DAYS="${BROUTER_SEGMENTS_MAX_AGE_DAYS:-30}"
mkdir -p "$SEGMENTS"

for tile in $TILES; do
  file="$SEGMENTS/$tile.rd5"
  stale=""
  if [ -s "$file" ]; then
    stale="$(find "$file" -mtime +"$MAX_AGE_DAYS" 2>/dev/null)"
  fi
  if [ ! -s "$file" ] || [ -n "$stale" ]; then
    echo "[brouter] lade Kartenkachel $tile …"
    # Erst in eine Temporärdatei — eine alte Kachel bleibt bei einem
    # fehlgeschlagenen Download erhalten
    if curl -fsSL --retry 3 --retry-delay 5 -o "$file.tmp" \
         "https://brouter.de/brouter/segments4/$tile.rd5"; then
      mv "$file.tmp" "$file"
      echo "[brouter] $tile bereit ($(du -h "$file" | cut -f1))"
    else
      rm -f "$file.tmp"
      echo "[brouter] WARNUNG: $tile konnte nicht geladen werden" >&2
    fi
  else
    echo "[brouter] $tile vorhanden ($(du -h "$file" | cut -f1))"
  fi
done

PORT="${PORT:-17777}"
THREADS="${BROUTER_THREADS:-4}"
JAVA_OPTS="${JAVA_OPTS:--Xmx1024m -Xms256m -DmaxRunningTime=300}"

echo "[brouter] starte RouteServer auf Port $PORT mit $THREADS Threads"
exec java $JAVA_OPTS -cp /opt/brouter/brouter.jar btools.server.RouteServer \
  "$SEGMENTS" /opt/brouter/profiles2 /opt/brouter/customprofiles "$PORT" "$THREADS"
