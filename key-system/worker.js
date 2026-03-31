// Aurora Key System — Cloudflare Worker
// KV Namespace: AURORA_KEYS
// Deploy: wrangler deploy
// Routes: keys.dallaswebstudio.net/*

// Admin secret stored as Worker secret (env.ADMIN_SECRET)
// Set via: wrangler secret put ADMIN_SECRET
const KEY_TTL = 86400; // 24 hours in seconds
const DAILY_COUNT_KEY = 'stats:daily:';

async function sendDiscordWebhook(env, key, ip, dailyCount) {
  const webhook = env.DISCORD_WEBHOOK;
  if (!webhook) return;
  const now = new Date();
  await fetch(webhook, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      embeds: [{
        title: '🌸 New Aurora Key Generated',
        color: 0xFC6E8E,
        fields: [
          { name: 'Key', value: `\`${key}\``, inline: false },
          { name: 'IP', value: ip, inline: true },
          { name: 'Keys Today', value: `${dailyCount}`, inline: true },
          { name: 'Time', value: `<t:${Math.floor(now.getTime() / 1000)}:f>`, inline: true },
        ],
        footer: { text: 'Aurora Key System' },
        timestamp: now.toISOString(),
      }],
    }),
  });
}

function generateKey() {
  const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  const segment = () => Array.from({ length: 4 }, () => chars[Math.floor(Math.random() * chars.length)]).join('');
  return `AURORA-${segment()}-${segment()}-${segment()}-${segment()}`;
}

const HTML_STYLES = `
  body { margin: 0; font-family: 'Segoe UI', sans-serif; background: #1a1a2e; color: #fff; display: flex; justify-content: center; align-items: center; min-height: 100vh; }
  .card { background: #16213e; border-radius: 16px; padding: 40px; text-align: center; max-width: 420px; width: 90%; box-shadow: 0 8px 32px rgba(252,110,142,0.15); }
  .logo { font-size: 48px; margin-bottom: 8px; }
  h1 { color: #FC6E8E; margin: 0 0 8px; font-size: 28px; }
  .sub { color: #888; font-size: 13px; margin-bottom: 24px; }
  .key-box { background: #0f3460; border: 2px solid #FC6E8E; border-radius: 10px; padding: 16px; font-family: monospace; font-size: 22px; letter-spacing: 2px; color: #fff; margin: 20px 0; user-select: all; cursor: pointer; }
  .key-box:hover { background: #1a4a7a; }
  .copy-btn { background: #FC6E8E; color: #fff; border: none; border-radius: 8px; padding: 12px 32px; font-size: 15px; font-weight: bold; cursor: pointer; margin-top: 12px; }
  .copy-btn:hover { background: #e05a7a; }
  .info { color: #666; font-size: 12px; margin-top: 16px; }
  .expire { color: #FC6E8E; font-size: 13px; margin-top: 8px; }
`;

function keyPage(key) {
  return `<!DOCTYPE html><html><head><title>Aurora Key</title><meta name="viewport" content="width=device-width,initial-scale=1"><style>${HTML_STYLES}</style></head><body>
<div class="card">
  <div class="logo">🌸</div>
  <h1>Aurora</h1>
  <p class="sub">by notCitruss</p>
  <p>Your key has been generated!</p>
  <div class="key-box" onclick="navigator.clipboard.writeText('${key}');document.getElementById('cb').textContent='Copied!'">${key}</div>
  <button class="copy-btn" id="cb" onclick="navigator.clipboard.writeText('${key}');this.textContent='Copied!'">Copy Key</button>
  <p class="expire">Expires in 24 hours</p>
  <p class="info">Paste this key in the Aurora script UI in-game</p>
</div></body></html>`;
}

function errorPage(msg) {
  return `<!DOCTYPE html><html><head><title>Aurora</title><meta name="viewport" content="width=device-width,initial-scale=1"><style>${HTML_STYLES}</style></head><body>
<div class="card">
  <div class="logo">🌸</div>
  <h1>Aurora</h1>
  <p style="color:#e05a7a">${msg}</p>
</div></body></html>`;
}

export default {
  async fetch(request, env, ctx) {
    const url = new URL(request.url);
    const path = url.pathname;

    // CORS headers for in-game HTTP requests
    const corsHeaders = {
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Methods': 'GET, OPTIONS',
      'Access-Control-Allow-Headers': 'Content-Type',
    };

    if (request.method === 'OPTIONS') {
      return new Response(null, { headers: corsHeaders });
    }

    // GET /generate — create a new key (called after Work.ink completion)
    // Rate limited: 1 key per IP per 24h. Refresh returns the same key.
    if (path === '/generate') {
      const ip = request.headers.get('CF-Connecting-IP') || 'unknown';
      const ipKey = `ip:${ip}`;

      // Check if this IP already has a key
      const existing = await env.AURORA_KEYS.get(ipKey);
      if (existing) {
        const { key: existingKey } = JSON.parse(existing);
        // Verify the key itself is still valid
        const stillValid = await env.AURORA_KEYS.get(existingKey);
        if (stillValid) {
          return new Response(keyPage(existingKey), {
            headers: { 'Content-Type': 'text/html', ...corsHeaders },
          });
        }
      }

      // Generate new key
      const key = generateKey();
      const data = JSON.stringify({ created: Date.now(), ip });
      await env.AURORA_KEYS.put(key, data, { expirationTtl: KEY_TTL });
      await env.AURORA_KEYS.put(ipKey, JSON.stringify({ key, created: Date.now() }), { expirationTtl: KEY_TTL });

      // Increment daily counter
      const today = new Date().toISOString().slice(0, 10);
      const countKey = DAILY_COUNT_KEY + today;
      const prev = parseInt(await env.AURORA_KEYS.get(countKey) || '0');
      const dailyCount = prev + 1;
      await env.AURORA_KEYS.put(countKey, String(dailyCount), { expirationTtl: 172800 }); // 48h

      // Discord notification (non-blocking)
      ctx.waitUntil(sendDiscordWebhook(env, key, ip, dailyCount));

      return new Response(keyPage(key), {
        headers: { 'Content-Type': 'text/html', ...corsHeaders },
      });
    }

    // GET /validate?key=AURORA-XXXX-XXXX-XXXX — check if key is valid
    if (path === '/validate') {
      const key = url.searchParams.get('key');
      if (!key) {
        return new Response(JSON.stringify({ valid: false, error: 'No key provided' }), {
          headers: { 'Content-Type': 'application/json', ...corsHeaders },
        });
      }

      const stored = await env.AURORA_KEYS.get(key);
      if (stored) {
        return new Response(JSON.stringify({ valid: true }), {
          headers: { 'Content-Type': 'application/json', ...corsHeaders },
        });
      }

      return new Response(JSON.stringify({ valid: false }), {
        headers: { 'Content-Type': 'application/json', ...corsHeaders },
      });
    }

    // GET /stats?secret=XXX — admin stats
    if (path === '/stats') {
      const secret = url.searchParams.get('secret');
      if (secret !== env.ADMIN_SECRET) {
        return new Response('Unauthorized', { status: 401 });
      }

      const list = await env.AURORA_KEYS.list({ limit: 1000 });
      return new Response(JSON.stringify({
        activeKeys: list.keys.length,
        keys: list.keys.map(k => k.name),
      }), {
        headers: { 'Content-Type': 'application/json', ...corsHeaders },
      });
    }

    // Default — landing page
    return new Response(errorPage('Visit our Discord for the loadstring!'), {
      headers: { 'Content-Type': 'text/html', ...corsHeaders },
    });
  },
};
