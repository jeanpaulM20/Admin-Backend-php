# DALL-E Prompt — Slackline Walking Banner (Querformat)

Ziel: Das Datenbank-Icon „Slackline Walking (vorwärts/rückwärts)" im
Querformat für den Training-Screen-Banner neu generieren.

---

## Prompt (direkt in DALL-E / ChatGPT eingeben)

```
Flat fitness illustration, ultra-wide landscape format (2:1 ratio).
Exercise diagram showing a human figure performing "slackline walking" —
the person walks forward on a taut slackline stretched horizontally across
the frame, with movement arrows indicating both forward and backward direction.

Figure style: clean vector silhouette, athletic pose, arms spread wide for
balance, one foot on the line mid-stride. Body in olive green (#8fb339)
or white outline on a very dark background (#0d0d0d).

Composition: slackline spans the full width of the image with a slight
natural sag in the center. The walking figure is positioned center-left,
facing right. A small ghost/echo figure behind it (slightly transparent)
shows the return direction (rückwärts). Two small directional arrows — one
pointing right (vorwärts) and one pointing left (rückwärts) — placed
above the line.

Style: clean flat 2D fitness app icon illustration, no gradients,
no photorealism, no texture, no background details, no text labels.
Minimal, bold, legible at small sizes.

Color palette: very dark background #0a0a0a, figure color #8fb339 (olive
green) or bright white, slackline as a thin bright line, directional arrows
same color as figure.

Output format: wide rectangle, 2:1 landscape ratio.
```

---

## DALL-E Einstellungen

| Parameter | Wert |
|---|---|
| **Größe** | `1792 × 1024` (nächste 2:1-Option) |
| **Qualität** | `HD` |
| **Style** | `natural` (für flache Illustration, nicht fotorealistisch) |

---

## Falls das Ergebnis zu fotorealistisch ist — Alternative:

```
2D vector illustration for a fitness app, wide landscape banner (2:1).
Top-down simplified diagram of a person walking on a slackline.
Side view. Clean flat design. Dark background #0d0d0d.
Slackline in bright olive green stretching full width with slight droop.
Simplified human figure mid-walk: arms outstretched, one knee raised.
Two arrows on the line: right arrow (vorwärts) and left arrow (rückwärts).
No shading, no gradients, no textures, no photorealism.
Icon style like a fitness training app exercise card.
Palette: background #0a0a0a, line and figure #8fb339, arrows #ffffff.
```

---

## Nach der Generierung — in Xcode einbinden

1. Bild als `slackline-walking.jpg` (oder `.png`) speichern
2. In Xcode → `Assets.xcassets` → `banner-slackline-walking` öffnen
3. Datei ins **Universal**-Slot ziehen
4. Das SVG-Placeholder wird automatisch durch das neue Bild ersetzt
5. App neu bauen — kein Code-Änderung nötig

> Der Asset-Name `banner-slackline-walking` bleibt gleich.
> `Image("banner-slackline-walking")` in `TrainingListView` lädt automatisch
> das neue Bild (PNG/JPG hat höhere Priorität als SVG im selben Imageset).
