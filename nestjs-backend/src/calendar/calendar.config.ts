/**
 * Zugangsdaten der Kalender-Anbindung.
 *
 * Alle Werte kommen aus der Umgebung — ohne sie bleibt die Anbindung
 * schlicht abgeschaltet (`isConfigured` = false), die App läuft normal weiter.
 */
export const CalendarConfig = {
  google: {
    get clientId() { return process.env.GOOGLE_CLIENT_ID ?? ''; },
    get clientSecret() { return process.env.GOOGLE_CLIENT_SECRET ?? ''; },
    authUrl: 'https://accounts.google.com/o/oauth2/v2/auth',
    tokenUrl: 'https://oauth2.googleapis.com/token',
    apiBase: 'https://www.googleapis.com/calendar/v3',
    // calendar.events genügt: lesen und schreiben im eigenen Kalender
    scope: 'https://www.googleapis.com/auth/calendar.events openid email',
    get isConfigured() { return !!(this.clientId && this.clientSecret); },
  },
  microsoft: {
    get clientId() { return process.env.MS_CLIENT_ID ?? ''; },
    get clientSecret() { return process.env.MS_CLIENT_SECRET ?? ''; },
    get tenant() { return process.env.MS_TENANT ?? 'common'; },
    get authUrl() { return `https://login.microsoftonline.com/${this.tenant}/oauth2/v2.0/authorize`; },
    get tokenUrl() { return `https://login.microsoftonline.com/${this.tenant}/oauth2/v2.0/token`; },
    apiBase: 'https://graph.microsoft.com/v1.0',
    // NUR lesend — die App schreibt nie nach Outlook
    scope: 'offline_access openid email Calendars.Read',
    get isConfigured() { return !!(this.clientId && this.clientSecret); },
  },

  /** Öffentliche Basis-URL für den OAuth-Rückruf. */
  get baseUrl() {
    return (process.env.APP_BASE_URL ?? 'https://admin-backend-php-production.up.railway.app')
      .replace(/\/$/, '');
  },
  redirectUri(provider: 'google' | 'microsoft') {
    return `${this.baseUrl}/api/calendar/callback/${provider}`;
  },

  /** Wie weit im Voraus Termine gespiegelt werden. */
  syncDays: Number(process.env.CALENDAR_SYNC_DAYS ?? 60),
  /** Kennzeichen, an dem die App ihre eigenen Sperreinträge wiedererkennt. */
  markerKey: 'sihlmoveBlocker',
} as const;
