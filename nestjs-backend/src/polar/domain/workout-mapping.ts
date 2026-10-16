import { formatHms, parseIsoDurationSeconds } from './iso-duration';
import {
  PolarExercise, PolarSample, SAMPLE_TYPE_ALTITUDE, SAMPLE_TYPE_HEART_RATE,
} from './polar-exercise';

/** Ein Training in der Form, die auch App-Aufzeichnungen haben. */
export interface WorkoutDraft {
  /** UTC, "YYYY-MM-DD HH:MM:SS" — wie bei App-Aufzeichnungen */
  date: string;
  trainingType: string;
  duration: string | null;
  heartRate: number | null;
  kcal: number | null;
  distanceMeters: number | null;
  elevationGain: number | null;
  hrSeries: { t: string; v: number }[];
  gpsTrack: { t: string; lat: number; lon: number; ele: number | null; acc: number | null }[];
}

/** Dieselben Obergrenzen wie beim App-Upload. */
const MAX_HR_POINTS = 50000;
const MAX_GPS_POINTS = 30000;
/** Höhenrauschen glätten: erst ab 3 m Anstieg gegenüber dem Tiefpunkt zählen. */
const ELEVATION_HYSTERESIS_M = 3;

/**
 * Bezeichnungen wie in der App (WorkoutActivity), damit Polar- und
 * App-Trainings in Analytics zusammen ausgewertet werden.
 */
const SPORT_LABELS: Record<string, string> = {
  RUNNING: 'Joggen',
  TREADMILL_RUNNING: 'Joggen',
  TRAIL_RUNNING: 'Joggen',
  ROAD_RUNNING: 'Joggen',
  JOGGING: 'Joggen',
  CYCLING: 'Radfahren',
  ROAD_BIKING: 'Radfahren',
  INDOOR_CYCLING: 'Radfahren',
  MOUNTAIN_BIKING: 'Mountainbike',
  HIKING: 'Wandern',
  WALKING: 'Wandern',
  NORDIC_WALKING: 'Wandern',
  MOUNTAINEERING: 'Bergtour',
  STRENGTH_TRAINING: 'Krafttraining',
  CIRCUIT_TRAINING: 'Krafttraining',
  SWIMMING: 'Schwimmen',
  OPEN_WATER_SWIMMING: 'Schwimmen',
  POOL_SWIMMING: 'Schwimmen',
  YOGA: 'Yoga',
  PILATES: 'Pilates',
  ROWING: 'Rudern',
  INDOOR_ROWING: 'Rudern',
  CROSS_COUNTRY_SKIING: 'Langlauf',
  DOWNHILL_SKIING: 'Ski',
};

export function sportLabel(ex: Pick<PolarExercise, 'sport' | 'detailed_sport_info'>): string {
  for (const key of [ex.detailed_sport_info, ex.sport]) {
    const k = String(key ?? '').trim().toUpperCase();
    if (k && SPORT_LABELS[k]) return SPORT_LABELS[k];
  }
  const raw = String(ex.detailed_sport_info || ex.sport || '').trim();
  if (!raw) return 'Training';
  // "OTHER_INDOOR" → "Other indoor"
  const words = raw.toLowerCase().replace(/_/g, ' ');
  return words.charAt(0).toUpperCase() + words.slice(1);
}

/** Startzeit in UTC (ms) aus lokaler Zeit + Offset — null, wenn unbrauchbar. */
export function startUtcMs(ex: Pick<PolarExercise, 'start_time' | 'start_time_utc_offset'>): number | null {
  const local = String(ex.start_time ?? '').trim();
  if (!/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}(:\d{2}(\.\d+)?)?$/.test(local)) return null;
  // Lokale Wanduhrzeit als UTC lesen, dann den Offset abziehen
  const asUtc = Date.parse(`${local}Z`);
  if (Number.isNaN(asUtc)) return null;
  const offsetMin = Number.isFinite(Number(ex.start_time_utc_offset)) ? Number(ex.start_time_utc_offset) : 0;
  return asUtc - offsetMin * 60_000;
}

function sqlUtc(ms: number): string {
  return new Date(ms).toISOString().slice(0, 19).replace('T', ' ');
}

function isoUtc(ms: number): string {
  return new Date(ms).toISOString().replace(/\.\d{3}Z$/, 'Z');
}

function positiveRounded(value: unknown): number | null {
  const n = Number(value);
  return Number.isFinite(n) && n > 0 ? Math.round(n) : null;
}

/** Werte einer Sample-Serie — leere oder ungültige Einträge bleiben als null stehen, damit die Zeitachse stimmt. */
function sampleValues(sample: PolarSample | undefined): (number | null)[] {
  if (!sample?.data) return [];
  return sample.data.split(',').map((v) => {
    const t = v.trim();
    if (!t) return null;
    const n = Number(t);
    return Number.isFinite(n) ? n : null;
  });
}

function findSample(ex: PolarExercise, type: string): PolarSample | undefined {
  return (ex.samples ?? []).find((s) => String(s?.['sample-type']) === type);
}

function rateSeconds(sample: PolarSample | undefined): number {
  const r = Number(sample?.['recording-rate']);
  return Number.isFinite(r) && r > 0 ? r : 1;
}

/** Positiver Höhengewinn mit Hysterese — einzelne Ausreisser zählen nicht. */
export function elevationGain(altitudes: (number | null)[]): number | null {
  const values = altitudes.filter((v): v is number => v !== null);
  if (values.length < 2) return null;
  let gain = 0;
  let base = values[0];
  for (const v of values.slice(1)) {
    if (v < base) {
      base = v;
    } else if (v - base >= ELEVATION_HYSTERESIS_M) {
      gain += v - base;
      base = v;
    }
  }
  return Math.round(gain);
}

/**
 * Polar-Training → Training im App-Format. null, wenn die Startzeit fehlt
 * (ohne Datum lässt sich das Training nirgends einordnen).
 */
export function toWorkoutDraft(ex: PolarExercise): WorkoutDraft | null {
  const start = startUtcMs(ex);
  if (start === null) return null;

  const durationSec = parseIsoDurationSeconds(ex.duration);

  const hrSample = findSample(ex, SAMPLE_TYPE_HEART_RATE);
  const hrRate = rateSeconds(hrSample);
  const hrSeries = sampleValues(hrSample)
    .map((v, i) => ({ t: isoUtc(start + i * hrRate * 1000), v: v === null ? 0 : Math.round(v) }))
    .filter((p) => p.v > 20 && p.v < 250)
    .slice(0, MAX_HR_POINTS);

  const altSample = findSample(ex, SAMPLE_TYPE_ALTITUDE);
  const altRate = rateSeconds(altSample);
  const altitudes = sampleValues(altSample);
  const altitudeAt = (offsetSec: number): number | null => {
    if (!altitudes.length) return null;
    const v = altitudes[Math.min(altitudes.length - 1, Math.max(0, Math.round(offsetSec / altRate)))];
    return v === undefined ? null : v;
  };

  const gpsTrack = (ex.route ?? [])
    .map((p) => {
      const offset = parseIsoDurationSeconds(p?.time);
      const lat = Number(p?.latitude);
      const lon = Number(p?.longitude);
      if (offset === null || !Number.isFinite(lat) || !Number.isFinite(lon)) return null;
      if (Math.abs(lat) > 90 || Math.abs(lon) > 180 || (lat === 0 && lon === 0)) return null;
      return { t: isoUtc(start + offset * 1000), lat, lon, ele: altitudeAt(offset), acc: null };
    })
    .filter((p): p is NonNullable<typeof p> => p !== null)
    .slice(0, MAX_GPS_POINTS);

  const avgHr = positiveRounded(ex.heart_rate?.average);
  const fallbackHr = hrSeries.length
    ? Math.round(hrSeries.reduce((a, p) => a + p.v, 0) / hrSeries.length)
    : null;

  return {
    date: sqlUtc(start),
    trainingType: sportLabel(ex),
    duration: durationSec !== null && durationSec > 0 ? formatHms(durationSec) : null,
    heartRate: avgHr ?? fallbackHr,
    kcal: positiveRounded(ex.calories),
    distanceMeters: positiveRounded(ex.distance),
    elevationGain: elevationGain(altitudes),
    hrSeries,
    gpsTrack,
  };
}
