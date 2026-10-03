# Eigene BRouter-Instanz (Railway)

Routing-Server für den Routenplaner, die Rundtour, A→B und den Touren-
Assistenten. Ersetzt die öffentliche Instanz brouter.de, die bei schnellen
Anfragefolgen mit „Please, retry later!" drosselt — und zwar für die
gemeinsame Server-IP, also für alle Nutzer gleichzeitig.

## Was der Container tut

- Lädt beim Bau das offizielle BRouter-Release 1.7.10 (Server-Jar und
  Standardprofile) und legt das Zusatzprofil `hiking-beta` dazu
  (`profiles/`, siehe dortiges README).
- Lädt beim Start fehlende oder über 30 Tage alte Kartenkacheln von
  brouter.de nach `/data/segments4`. Schweiz samt Grenzgebiet =
  `E5_N45` + `E10_N45`, zusammen rund 450 MB.
- Startet `btools.server.RouteServer` auf `$PORT` (Railway setzt die
  Variable), Standard 17777.

Das Backend spricht die Instanz über `BROUTER_URL` an und fällt bei Ausfall
oder Überlast automatisch auf brouter.de zurück (`ToursService.brouter`).

## Einrichtung auf Railway (einmalig)

Im Projekt `sincere-abundance`, Ordner `brouter/` als eigener Dienst:

```bash
cd brouter
railway add --service brouter
railway volume add --service brouter --mount-path /data
railway up --service brouter --detach
```

`railway up` lädt den Ordner hoch und baut das Dockerfile. Ohne Volume
funktioniert der Dienst auch, lädt die Kacheln dann aber bei jedem Start
neu (rund zwei Minuten).

Danach im Backend-Dienst (`Admin-Backend-php`) die Variable setzen:

```bash
railway variables --service Admin-Backend-php --set "BROUTER_URL=http://brouter.railway.internal:17777"
```

Private Networking ist in Railway-Projekten standardmässig aktiv; der Name
`brouter.railway.internal` entspricht dem Dienstnamen. Alternativ eine
öffentliche Domain für den Dienst erzeugen und `https://…` eintragen.

## Variablen des Dienstes

| Variable | Standard | Bedeutung |
|---|---|---|
| `PORT` | 17777 | setzt Railway selbst |
| `BROUTER_SEGMENTS` | `E5_N45 E10_N45` | Kacheln (5°×5°), durch Leerzeichen getrennt |
| `BROUTER_SEGMENTS_MAX_AGE_DAYS` | 30 | danach werden Kacheln beim Start erneuert |
| `BROUTER_THREADS` | 4 | gleichzeitige Berechnungen |
| `JAVA_OPTS` | `-Xmx1024m -Xms256m -DmaxRunningTime=300` | Heap; bei weiteren Kacheln erhöhen |

## Ressourcen und Kosten

- Arbeitsspeicher: etwa 1–1.5 GB im Betrieb (Heap plus Kacheln im
  Dateicache). Railway rechnet nach Verbrauch ab; bei durchgehendem Betrieb
  grob 10–15 USD pro Monat für Speicher plus wenig CPU.
- Volume: 1 GB reicht für die Schweiz.
- Weitere Länder: Kachelnamen aus `https://brouter.de/brouter/segments4/`
  ergänzen, Heap entsprechend anheben.

## Prüfen

```bash
curl "https://<domain-oder-tunnel>/brouter?lonlats=8.4948,47.3499|8.5200,47.3406&profile=hiking-beta&alternativeidx=0&format=geojson" | head -c 400
```

Antwortet GeoJSON mit `track-length`, läuft die Instanz. Im Backend-Log
erscheint danach kein „ausgelastet" mehr; fällt die Instanz aus, übernimmt
brouter.de ohne Eingriff.

## Grenzen

- Der Container wurde ohne lokales Docker vorbereitet; der erste Bau auf
  Railway zeigt, ob alles passt (Logs: „[brouter] starte RouteServer …").
- Die Kacheln stammen weiterhin von brouter.de (einmal pro Monat,
  450 MB) — das belastet die öffentliche Instanz nicht nennenswert.
