# TestFlight-Testnotizen — SIHLMOVE 1.0 (Build 3)

Zum Einfügen in App Store Connect → TestFlight → Build 3 → „Testdetails" (Was zu testen ist).

---

Neu in diesem Build: „Tour starten" führt direkt in die Aufzeichnung, und die App leitet dich unterwegs der Route entlang — wie ein Navi. Bitte vor allem diese Punkte draussen ausprobieren:

TOUR STARTEN
1. Im Touren-Tab eine Route planen (oder eine gespeicherte Route bzw. eine Tour öffnen) und „Tour starten" tippen. Die App soll auf den Tab „Start" wechseln, die Route als Karte anzeigen und nach einem Countdown (3 Sekunden) die Aufzeichnung von selbst beginnen. Kein Rücksprung mehr in den Planer.
2. Vor dem Start die Route über das X auf der Karte entfernen: Die Aufzeichnung startet dann ohne Leitlinie.
3. Aufzeichnung beenden und speichern: Die Startseite ist danach leer und bereit für die nächste Tour.

UNTERWEGS AUF DER ROUTE
4. Der zurückgelegte Teil der Route wird grau, der Rest bleibt blau gestrichelt. Die Karte schaut in Laufrichtung voraus.
5. In der Statuszeile: „Noch · nächster Punkt" (bei Zwischenzielen) bzw. „Noch bis Ziel", Resthöhenmeter auf/ab und „Ankunft ca." (Uhrzeit). Die Ankunftszeit soll sich nach etwa 500 m an dein eigenes Tempo anpassen.
6. Im Höhenprofil wandert eine Markierung mit deiner Position mit.
7. Bewusst 100 m von der Route abweichen: Es erscheint „… m zur Route" mit einem Pfeil Richtung Route. Zurück auf dem Weg verschwindet der Hinweis wieder.
8. Am Ziel ankommen: Haptik und Banner „Ziel erreicht" mit Knopf „Beenden". Bei einer Rundtour darf das Banner nicht schon am Start erscheinen.

ABBIEGEHINWEISE
9. Vor Abzweigungen erscheint oben ein Banner (z. B. „Links abbiegen", mit Distanz) ab etwa 150 m, dann 30 m, dann am Abbiegepunkt — am Abbiegepunkt mit kurzem Vibrieren.
10. Lautsprecher-Knopf in der Aufzeichnung: Ansagen auf Schweizerdeutsch-nahes Deutsch einschalten. Musik oder Podcast sollen während der Ansage leiser werden und danach normal weiterlaufen. Ansagen auch bei gesperrtem Bildschirm und in der Hosentasche prüfen.
11. Die Wahl (Ansagen an/aus) soll beim nächsten Start noch gelten.

ROUTENPLANER (seit Build 2, bitte weiter testen)
12. Rundkurs, Pins verschieben, Zwischenpunkt auf der Linie einfügen, gespeicherte Routen, Touren-Assistent mit „Im Planer anpassen", Ortssuche mit genauem Pin.

BEKANNTE GRENZEN
- Abbiegehinweise gibt es nur bei geplanten Routen (Planer, Assistent), nicht bei Touren aus der Tourenliste.
- Bei Touren, deren Wegabschnitte nicht in Reihenfolge vorliegen, zeigt die App nur den Abstand zur Route, keine Restdistanz.
- Die Ankunftszeit ist eine Schätzung (Wanderformel, gemischt mit deinem Tempo).
- Der Assistent beantwortet 30 Fragen pro Tag.
- Routen lassen sich noch nicht teilen.

BITTE MELDEN
- „… m zur Route", obwohl du klar auf dem Weg bist — mit Ort und Aktivität.
- „Ziel erreicht" zu früh oder gar nicht (bitte sagen, wie weit du vom Ziel warst).
- Abbiegehinweise an der falschen Stelle, in die falsche Richtung oder zu spät.
- Ansagen, die nicht kommen, oder Musik, die nach der Ansage leise bleibt.
- Höherer Akkuverbrauch als bei Build 2 auf derselben Strecke.
- Jede Stelle, an der die App hängt, abstürzt oder ein Knopf nichts tut.

Feedback bitte direkt über TestFlight (Screenshot + Kommentar) oder per Nachricht.
