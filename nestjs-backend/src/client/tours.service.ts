import { Injectable } from '@nestjs/common';

/**
 * Touren-Domäne: OSM-Discovery (Overpass), Rundtouren-Generator und
 * A→B-Routing (BRouter), Geocoding (Nominatim) — mit Caches, Drosselung
 * und den Aktivitäts-Spezifikationen als einziger Quelle.
 * Aus ClientAppService extrahiert (Clean-Architecture-Check 2026-08-25).
 */
@Injectable()
export class ToursService {
  private tourListCache = new Map<string, { at: number; data: any }>();
  private tourDetailCache = new Map<string, { at: number; data: any }>();
  private static readonly TOUR_TTL_MS = 24 * 60 * 60 * 1000;

  // Overpass-Nutzungsrichtlinie verlangt einen identifizierenden User-Agent —
  // Node-fetch sendet keinen und bekommt sonst 406 Not Acceptable.
  private static readonly OSM_UA = 'SihlClient-Backend/1.0 (sihltraining.ch)';

  private async overpass(query: string): Promise<any> {
    // osm.ch zuerst: Schweizer Instanz, für unser Einzugsgebiet ~10x schneller
    // und ohne die Lastprobleme der Hauptinstanz. Sie deckt aber nur die
    // Schweiz ab und liefert anderswo ein leeres (aber gültiges) Ergebnis —
    // ein leeres Ergebnis probiert darum die nächste Instanz, bevor es zählt.
    const endpoints = [
      'https://overpass.osm.ch/api/interpreter',
      'https://overpass-api.de/api/interpreter',
    ];
    let lastErr: Error = new Error('Overpass nicht erreichbar');
    let emptyResult: any = null;
    for (const endpoint of endpoints) {
      try {
        const res = await fetch(endpoint, {
          method: 'POST',
          headers: {
            'Content-Type': 'application/x-www-form-urlencoded',
            'User-Agent': ToursService.OSM_UA,
            Accept: 'application/json',
          },
          body: 'data=' + encodeURIComponent(query),
          signal: AbortSignal.timeout(20000),
        });
        if (!res.ok) { lastErr = new Error(`Overpass ${res.status}`); continue; }
        const json = await res.json();
        if ((json?.elements ?? []).length > 0) return json;
        emptyResult = json;
      } catch (err: any) {
        lastErr = err;
      }
    }
    if (emptyResult) return emptyResult;
    throw lastErr;
  }

  private static haversine(aLat: number, aLon: number, bLat: number, bLon: number): number {
    const R = 6371000;
    const dLat = ((bLat - aLat) * Math.PI) / 180;
    const dLon = ((bLon - aLon) * Math.PI) / 180;
    const s =
      Math.sin(dLat / 2) ** 2 +
      Math.cos((aLat * Math.PI) / 180) * Math.cos((bLat * Math.PI) / 180) * Math.sin(dLon / 2) ** 2;
    return 2 * R * Math.asin(Math.sqrt(s));
  }

  /**
   * Overpass-Selektoren je Aktivität. Finnenbahnen sind in OSM Wege (keine
   * Relationen) und oft nur über den Namen erkennbar — daher zwei Selektoren
   * als Union; ihre IDs bekommen ein "w"-Präfix fürs Detail.
   */
  private static tourSpec(activity: string): { selectors: string[]; osm: string } {
    switch (activity) {
      case 'rad':
      case 'rennrad':
        return { selectors: ['relation["route"="bicycle"]["name"]'], osm: 'bicycle' };
      case 'mtb':
        return { selectors: ['relation["route"="mtb"]["name"]'], osm: 'mtb' };
      case 'joggen':
        return { selectors: ['relation["route"="running"]["name"]'], osm: 'running' };
      case 'vitaparcours':
        return { selectors: ['relation["route"="fitness_trail"]["name"]'], osm: 'fitness_trail' };
      case 'finnenbahn':
        // Laufbahn ist nicht gleich Finnenbahn: leisure=track+sport=running
        // allein erwischt auch Sprint-/Aschenbahnen. Echte Finnenbahnen sind
        // benannt oder haben Holzschnitzel-Belag (surface=woodchips/wood).
        return {
          selectors: [
            'way["leisure"="track"]["sport"="running"]["name"~"[Ff]innenbahn"]',
            'way["leisure"="track"]["sport"="running"]["surface"~"^wood"]',
          ],
          osm: 'finnenbahn',
        };
      default:
        return { selectors: ['relation["route"="hiking"]["name"]'], osm: 'hiking' };
    }
  }

  /** Markierte OSM-Routen im Umkreis (gecacht, Raster 0.01°). */
  async getTours(lat: number, lon: number, radiusKm: number, activity: string) {
    const spec = ToursService.tourSpec(activity);
    const r = Math.min(Math.max(radiusKm, 1), 30);
    const key = `${spec.osm}:${lat.toFixed(2)}:${lon.toFixed(2)}:${Math.round(r)}`;
    const hit = this.tourListCache.get(key);
    if (hit && Date.now() - hit.at < ToursService.TOUR_TTL_MS) return hit.data;

    const around = `(around:${Math.round(r * 1000)},${lat},${lon})`;
    if (spec.osm === 'finnenbahn') {
      const bahnen = await this.finnenbahnList(lat, lon, spec.selectors, around);
      this.tourListCache.set(key, { at: Date.now(), data: bahnen });
      return bahnen;
    }
    const query = `[out:json][timeout:25];
(${spec.selectors.map((sel) => sel + around + ';').join('')});
out tags center 80;`;
    const json = await this.overpass(query);

    const tours = (json?.elements ?? [])
      .filter((e: any) => e?.center && e?.tags?.name)
      .map((e: any) => {
        const distKm = parseFloat(String(e.tags?.distance ?? '').replace(',', '.')) || null;
        return {
          id: (e.type === 'way' ? 'w' : '') + e.id,
          name: String(e.tags.name),
          ref: e.tags?.ref ?? null,
          activity: spec.osm,
          network: e.tags?.network ?? null,    // lwn/rwn/nwn = lokal/regional/national
          distanceKm: distKm,
          durationMin: distKm ? ToursService.tourDuration(distKm, spec.osm) : null,
          difficulty: distKm ? ToursService.tourDifficulty(distKm) : null,
          lat: e.center.lat,
          lon: e.center.lon,
        };
      })
      .sort((a: any, b: any) =>
        ToursService.haversine(lat, lon, a.lat, a.lon) -
        ToursService.haversine(lat, lon, b.lat, b.lon));

    // OSM führt manche Route doppelt (Route + Superroute, geteilte Wege) —
    // pro Name bleibt nur der nächstgelegene Treffer
    const seenKeys = new Set<string>();
    const deduped = tours.filter((t: any) => {
      if (seenKeys.has(t.name)) return false;
      seenKeys.add(t.name);
      return true;
    });

    this.tourListCache.set(key, { at: Date.now(), data: deduped });
    return deduped;
  }

  /**
   * Finnenbahnen: kurze Rundbahnen aus einem oder mehreren OSM-Wegen.
   * Lädt die Geometrie mit (kleine Payload), berechnet echte Längen und
   * fasst gleichnamige Wege derselben Anlage (<500 m) zu einem Eintrag
   * zusammen — die ID trägt dann alle Weg-IDs ("w123+456").
   */
  private async finnenbahnList(lat: number, lon: number, selectors: string[], around: string) {
    const query = `[out:json][timeout:25];
(${selectors.map((sel) => sel + around + ';').join('')});
out geom 80;`;
    const json = await this.overpass(query);
    const ways = (json?.elements ?? []).filter(
      (e: any) => e.type === 'way' && Array.isArray(e.geometry) && e.geometry.length >= 2);

    type Bahn = { ids: number[]; name: string; lengthM: number; lat: number; lon: number; n: number };
    const groups: Bahn[] = [];
    for (const w of ways) {
      let lengthM = 0;
      for (let i = 1; i < w.geometry.length; i++) {
        lengthM += ToursService.haversine(
          w.geometry[i - 1].lat, w.geometry[i - 1].lon, w.geometry[i].lat, w.geometry[i].lon);
      }
      const cLat = w.geometry.reduce((a: number, g: any) => a + g.lat, 0) / w.geometry.length;
      const cLon = w.geometry.reduce((a: number, g: any) => a + g.lon, 0) / w.geometry.length;
      const name = w.tags?.name ?? 'Finnenbahn';
      const group = groups.find(
        (g) => g.name === name && ToursService.haversine(g.lat, g.lon, cLat, cLon) < 500);
      if (group) {
        group.ids.push(w.id);
        group.lengthM += lengthM;
        group.lat = (group.lat * group.n + cLat) / (group.n + 1);
        group.lon = (group.lon * group.n + cLon) / (group.n + 1);
        group.n += 1;
      } else {
        groups.push({ ids: [w.id], name, lengthM, lat: cLat, lon: cLon, n: 1 });
      }
    }
    return groups
      .map((g) => ({
        id: 'w' + g.ids.join('+'),
        name: g.name,
        ref: null,
        activity: 'finnenbahn',
        network: null,
        distanceKm: Math.round(g.lengthM) / 1000 || null,
        durationMin: null,   // Rundenbahn: eine "Tour-Dauer" wäre irreführend
        difficulty: null,
        lat: g.lat,
        lon: g.lon,
      }))
      .sort((a, b) =>
        ToursService.haversine(lat, lon, a.lat, a.lon) -
        ToursService.haversine(lat, lon, b.lat, b.lon));
  }

  /** Geometrie + berechnete Werte einer Route (gecacht). */
  async getTourDetail(id: string) {
    const hit = this.tourDetailCache.get(id);
    if (hit && Date.now() - hit.at < ToursService.TOUR_TTL_MS) return hit.data;

    const isWay = id.startsWith('w');
    let els: any[];
    if (isWay) {
      // Finnenbahn-Anlagen können aus mehreren Wegen bestehen ("w123+456")
      const ids = id.slice(1).split('+').map((v) => parseInt(v, 10));
      if (!ids.length || ids.some((n) => !Number.isFinite(n))) {
        throw new Error('Ungueltige Touren-ID');
      }
      const json = await this.overpass(
        `[out:json][timeout:60];(${ids.map((n) => `way(${n});`).join('')});out geom;`);
      els = (json?.elements ?? []).filter((e: any) => e.type === 'way');
    } else {
      const relId = parseInt(id, 10);
      if (!Number.isFinite(relId)) throw new Error('Ungueltige Touren-ID');
      const json = await this.overpass(`[out:json][timeout:60];relation(${relId});out geom;`);
      els = json?.elements ?? [];
    }
    const rel = els.find((e: any) => e.tags?.name) ?? els[0];
    if (!rel) throw new Error('Tour nicht gefunden');

    // Geometrie: Wege (Finnenbahnen) tragen sie direkt, Relationen über ihre
    // Member-Wege (Reihenfolge in OSM nicht garantiert — wir liefern Segmente;
    // Länge = Summe, korrekt unabhängig von Ordnung)
    const rawSegments: any[][] = isWay
      ? els.map((e: any) => e.geometry ?? [])
      : (rel.members ?? [])
          .filter((m: any) => m.type === 'way' && Array.isArray(m.geometry))
          .map((m: any) => m.geometry);
    const segments: { lat: number; lon: number }[][] = [];
    let distanceM = 0;
    for (const geometry of rawSegments) {
      if (geometry.length < 2) continue;
      const seg = geometry.map((g: any) => ({ lat: g.lat, lon: g.lon }));
      for (let i = 1; i < seg.length; i++) {
        distanceM += ToursService.haversine(seg[i - 1].lat, seg[i - 1].lon, seg[i].lat, seg[i].lon);
      }
      segments.push(seg);
    }
    // Payload begrenzen: lange Segmente ausdünnen (max ~4000 Punkte gesamt)
    const total = segments.reduce((n, s) => n + s.length, 0);
    const stride = Math.max(1, Math.ceil(total / 4000));
    const slim = segments.map((seg) =>
      seg.filter((_, i) => i % stride === 0 || i === seg.length - 1));

    const distKm = distanceM / 1000;
    const routeTag = rel.tags?.route;
    const osmRoute = isWay
      ? 'finnenbahn'
      : ['bicycle', 'mtb', 'running', 'fitness_trail'].includes(routeTag)
        ? routeTag
        : 'hiking';
    const detail = {
      id,
      name: rel.tags?.name ?? (isWay ? 'Finnenbahn' : 'Route'),
      ref: rel.tags?.ref ?? null,
      activity: osmRoute,
      network: rel.tags?.network ?? null,
      operator: rel.tags?.operator ?? null,
      description: rel.tags?.description ?? null,
      surface: rel.tags?.surface ?? null,
      lit: rel.tags?.lit === 'yes' ? true : rel.tags?.lit === 'no' ? false : null,
      distanceKm: isWay ? Math.round(distanceM) / 1000 : Math.round(distKm * 10) / 10,
      durationMin: isWay ? null : ToursService.tourDuration(distKm, osmRoute),
      difficulty: isWay ? null : ToursService.tourDifficulty(distKm),
      segments: slim,
    };
    this.tourDetailCache.set(id, { at: Date.now(), data: detail });
    return detail;
  }

  /**
   * Rundtouren-Generator (T4): Wegpunkte auf einem Kreis durch den Start,
   * Routing über die freie BRouter-Instanz (OSM, inkl. Höhendaten).
   */
  async generateRoundtrip(lat: number, lon: number, distanceKm: number, activity: string, seed?: number) {
    const dist = Math.min(Math.max(distanceKm, 3), 60);
    const spec = ToursService.roundtripSpec(activity);
    const profile = spec.profile;
    const bearing = ((seed ?? Math.floor(Math.random() * 360)) % 360) * (Math.PI / 180);

    // Kreis mit Umfang ≈ Zieldistanz, Start liegt AUF dem Kreis
    const rKm = dist / (2 * Math.PI);
    const latKm = 110.574;
    const lonKm = 111.32 * Math.cos((lat * Math.PI) / 180);
    const cLat = lat + (rKm / latKm) * Math.cos(bearing);
    const cLon = lon + (rKm / lonKm) * Math.sin(bearing);
    const points: [number, number][] = [[lon, lat]];
    for (let i = 1; i < 4; i++) {
      const phi = bearing + Math.PI + (i * 2 * Math.PI) / 4;
      points.push([
        cLon + (rKm / lonKm) * Math.sin(phi),
        cLat + (rKm / latKm) * Math.cos(phi),
      ]);
    }
    points.push([lon, lat]);

    const lonlats = points.map((p) => `${p[0].toFixed(6)},${p[1].toFixed(6)}`).join('|');
    const { coords, lengthM, ascend } = await ToursService.brouter(lonlats, profile);

    // Geordnete Route → ein Segment; auf ≤2000 Punkte ausdünnen
    const stride = Math.max(1, Math.ceil(coords.length / 2000));
    const segment = coords
      .filter((_, i) => i % stride === 0 || i === coords.length - 1)
      .map((c) => ({ lat: c[1], lon: c[0], ele: c[2] ?? null }));

    const distOut = lengthM / 1000;
    return {
      id: `rt-${Date.now()}`,
      name: `Rundtour · ${distOut.toFixed(1)} km`,
      activity: spec.osm,
      generated: true,
      distanceKm: Math.round(distOut * 10) / 10,
      elevationGain: ascend,
      durationMin: ToursService.tourDurationWithClimb(distOut, ascend, spec.kmh, spec.climbPerH),
      difficulty: ToursService.tourDifficulty(distOut),
      segments: [segment],
    };
  }

  /**
   * BRouter-Profil, Richtgeschwindigkeit und Steigleistung je
   * Generator-Aktivität (alle Profile auf brouter.de verifiziert).
   */
  private static roundtripSpec(activity: string): {
    profile: string; kmh: number; climbPerH: number; osm: string;
  } {
    switch (activity) {
      case 'rad':
      case 'velo':    return { profile: 'trekking',    kmh: 15,  climbPerH: 600, osm: 'bicycle' };
      case 'rennrad': return { profile: 'fastbike',    kmh: 20,  climbPerH: 800, osm: 'bicycle' };
      case 'gravel':  return { profile: 'gravel',      kmh: 16,  climbPerH: 600, osm: 'bicycle' };
      case 'mtb':     return { profile: 'mtb',         kmh: 12,  climbPerH: 500, osm: 'mtb' };
      case 'joggen':  return { profile: 'hiking-beta', kmh: 8,   climbPerH: 500, osm: 'running' };
      default:        return { profile: 'hiking-beta', kmh: 4.2, climbPerH: 400, osm: 'hiking' };
    }
  }

  /** SAC-Formel MIT Höhenmetern: t = max(a,b) + min(a,b)/2. */
  private static tourDurationWithClimb(
    distKm: number, ascendM: number, kmh: number, climbPerH: number,
  ): number {
    const horiz = distKm / kmh;
    const climb = ascendM / climbPerH;
    const hours = Math.max(horiz, climb) + Math.min(horiz, climb) / 2;
    return Math.round(hours * 60);
  }

  /** SAC-Basisformel ohne Höhenmeter (T1; Höhenprofil folgt mit ORS). */
  private static tourDuration(distKm: number, osmRoute: string): number {
    const kmh =
      osmRoute === 'bicycle' ? 15 :
      osmRoute === 'mtb' ? 12 :
      osmRoute === 'running' || osmRoute === 'finnenbahn' ? 8 :
      4.2; // hiking, fitness_trail
    return Math.round((distKm / kmh) * 60);
  }

  private static tourDifficulty(distKm: number): string {
    if (distKm < 8) return 'Leicht';
    if (distKm < 16) return 'Mittel';
    return 'Schwer';
  }


  /** Geocode-Cache + Zeitstempel der letzten Anfrage (Nominatim-Drosselung). */
  private readonly geocodeCache = new Map<string, any>();
  private lastGeocodeAt = 0;

  async geocode(ort: string) {
    if (!ort.trim()) return { fehler: 'Leerer Ortsname' };
    const key = ort.trim().toLowerCase();
    const cached = this.geocodeCache.get(key);
    if (cached) return cached;

    // Nominatim-Nutzungsrichtlinie: max. 1 Anfrage/Sekunde — Verstösse
    // führen zur IP-Sperre (gleiche Fehlerklasse wie damals Overpass 406)
    const wait = this.lastGeocodeAt + 1100 - Date.now();
    if (wait > 0) await new Promise((r) => setTimeout(r, wait));
    this.lastGeocodeAt = Date.now();

    const url =
      'https://nominatim.openstreetmap.org/search?format=json&limit=1' +
      '&countrycodes=ch,li,at,de,fr,it&q=' + encodeURIComponent(ort);
    const res = await fetch(url, {
      headers: { 'User-Agent': ToursService.OSM_UA },
      signal: AbortSignal.timeout(10000),
    });
    if (!res.ok) throw new Error(`Geocoding ${res.status}`);
    const arr: any[] = await res.json();
    const result = !arr.length
      ? { fehler: `"${ort}" nicht gefunden` }
      : {
          name: String(arr[0].display_name ?? ort).split(',').slice(0, 2).join(','),
          lat: parseFloat(arr[0].lat),
          lon: parseFloat(arr[0].lon),
        };
    if (this.geocodeCache.size > 500) this.geocodeCache.clear();
    this.geocodeCache.set(key, result);
    return result;
  }

  /** A→B-Route über BRouter, gleiche Detail-Form wie der Rundtouren-Endpoint. */
  async routeAB(aLat: number, aLon: number, bLat: number, bLon: number, aktivitaet: string) {
    if (![aLat, aLon, bLat, bLon].every(Number.isFinite)) throw new Error('Ungültige Koordinaten');
    const spec = ToursService.roundtripSpec(aktivitaet === 'velo' ? 'rad' : aktivitaet);
    const lonlats = `${aLon.toFixed(6)},${aLat.toFixed(6)}|${bLon.toFixed(6)},${bLat.toFixed(6)}`;
    const { coords, lengthM, ascend } = await ToursService.brouter(lonlats, spec.profile);

    const distKm = lengthM / 1000;
    const stride = Math.max(1, Math.ceil(coords.length / 2000));
    const segment = coords
      .filter((_, i) => i % stride === 0 || i === coords.length - 1)
      .map((c) => ({ lat: c[1], lon: c[0], ele: c[2] ?? null }));

    return {
      id: `ab-${Date.now()}`,
      name: 'Route',
      activity: spec.osm,
      generated: true,
      distanceKm: Math.round(distKm * 10) / 10,
      elevationGain: ascend,
      durationMin: ToursService.tourDurationWithClimb(distKm, ascend, spec.kmh, spec.climbPerH),
      difficulty: ToursService.tourDifficulty(distKm),
      segments: [segment],
    };
  }

  /** Gemeinsamer BRouter-Aufruf (auch vom Rundtouren-Generator genutzt). */
  private static async brouter(lonlats: string, profile: string): Promise<{
    coords: number[][]; lengthM: number; ascend: number;
  }> {
    const url = `https://brouter.de/brouter?lonlats=${lonlats}&profile=${profile}&alternativeidx=0&format=geojson`;
    const res = await fetch(url, {
      headers: { 'User-Agent': ToursService.OSM_UA },
      signal: AbortSignal.timeout(30000),
    });
    if (!res.ok) throw new Error(`Routing fehlgeschlagen (${res.status})`);
    const geo = await res.json();
    const feature = geo?.features?.[0];
    const coords: number[][] = feature?.geometry?.coordinates ?? [];
    if (coords.length < 2) throw new Error('Keine Route gefunden');
    const props = feature.properties ?? {};
    return {
      coords,
      lengthM: parseFloat(props['track-length'] ?? '0') || 0,
      ascend: parseInt(props['filtered ascend'] ?? '0', 10) || 0,
    };
  }
}
