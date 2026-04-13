# Cloudflare Relay Setup (Fix CORS for Flutter Web)

Use this when Flutter runs in Chrome and direct Apps Script call fails with CORS.

## 1) Create Worker

1. Open Cloudflare dashboard.
2. Go to Workers & Pages -> Create -> Worker.
3. Replace worker code with this:

```javascript
export default {
  async fetch(request, env) {
    if (request.method === 'OPTIONS') {
      return new Response(null, {
        status: 204,
        headers: corsHeaders(),
      });
    }

    if (request.method !== 'POST') {
      return json({ ok: false, error: 'Method not allowed' }, 405);
    }

    try {
      const payload = await request.json();

      const appsScriptUrl = env.APPS_SCRIPT_URL;
      if (!appsScriptUrl) {
        return json({ ok: false, error: 'APPS_SCRIPT_URL is missing' }, 500);
      }

      const upstream = await fetch(appsScriptUrl, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(payload),
      });

      const text = await upstream.text();
      return new Response(text || JSON.stringify({ ok: true }), {
        status: upstream.status,
        headers: {
          ...corsHeaders(),
          'Content-Type': 'application/json',
        },
      });
    } catch (err) {
      return json({ ok: false, error: String(err) }, 500);
    }
  },
};

function corsHeaders() {
  return {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Methods': 'POST, OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type',
  };
}

function json(data, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: {
      ...corsHeaders(),
      'Content-Type': 'application/json',
    },
  });
}
```

## 2) Add Worker secret/variable

In Worker settings -> Variables:
- Name: `APPS_SCRIPT_URL`
- Value: your Apps Script `/exec` URL

## 3) Deploy Worker

Deploy and copy Worker URL, for example:
`https://neurolearn-mail-relay.<your-subdomain>.workers.dev`

## 4) Connect Flutter Web

Run once with relay URL:

```powershell
flutter run -d chrome --dart-define=CLOUDFLARE_RELAY_URL="https://neurolearn-mail-relay.<your-subdomain>.workers.dev"
```

After confirming it works, set that URL as default in `email_webhook_service.dart`:
- `_defaultRelayWebhookUrl = 'https://...workers.dev';`

## 5) Test

1. Complete assessment.
2. In Firestore `assessment_reports`, check `email.status` is `sent`.
3. Verify mail in parent inbox/spam.
