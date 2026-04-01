// Aurora Key System — Cloudflare Worker
// KV Namespace: AURORA_KEYS
// Deploy: wrangler deploy
// Single-use keys: claimed on first validate, locked to Roblox UserId

// Admin secret stored as Worker secret (env.ADMIN_SECRET)
// Set via: wrangler secret put ADMIN_SECRET
const DEFAULT_DURATION = 86400; // 24h in seconds (time AFTER claiming)
const SHELF_LIFE = 604800; // 7 days for unclaimed keys from /generate
const ADMIN_SHELF_LIFE = 2592000; // 30 days for unclaimed admin keys
const DAILY_COUNT_KEY = 'stats:daily:';

async function sendDiscordWebhook(env, key, ip, dailyCount, extra) {
  const webhook = env.DISCORD_WEBHOOK;
  if (!webhook) return;
  const now = new Date();
  const fields = [
    { name: 'Key', value: `\`${key}\``, inline: false },
    { name: 'IP', value: ip, inline: true },
    { name: 'Keys Today', value: `${dailyCount}`, inline: true },
    { name: 'Time', value: `<t:${Math.floor(now.getTime() / 1000)}:f>`, inline: true },
  ];
  if (extra) fields.push(extra);
  await fetch(webhook, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      embeds: [{
        title: '🌸 New Aurora Key Generated',
        color: 0xFC6E8E,
        fields,
        footer: { text: 'Aurora Key System' },
        timestamp: now.toISOString(),
      }],
    }),
  });
}

async function sendClaimWebhook(env, key, uid, duration) {
  const webhook = env.DISCORD_WEBHOOK;
  if (!webhook) return;
  const now = new Date();
  const hours = Math.round(duration / 3600);
  await fetch(webhook, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      embeds: [{
        title: '🔑 Key Claimed!',
        color: 0x32BE5A,
        fields: [
          { name: 'Key', value: `\`${key}\``, inline: false },
          { name: 'Roblox User', value: `${uid}`, inline: true },
          { name: 'Duration', value: `${hours}h`, inline: true },
          { name: 'Expires', value: `<t:${Math.floor(now.getTime() / 1000) + duration}:R>`, inline: true },
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

function keyPage(key, durationHours) {
  return `<!DOCTYPE html><html><head><title>Aurora Key</title><meta name="viewport" content="width=device-width,initial-scale=1"><style>${HTML_STYLES}</style></head><body>
<div class="card">
  <div class="logo">🌸</div>
  <h1>Aurora</h1>
  <p class="sub">by notCitruss</p>
  <p>Your key has been generated!</p>
  <div class="key-box" onclick="navigator.clipboard.writeText('${key}');document.getElementById('cb').textContent='Copied!'">${key}</div>
  <button class="copy-btn" id="cb" onclick="navigator.clipboard.writeText('${key}');this.textContent='Copied!'">Copy Key</button>
  <p class="expire">Valid for ${durationHours}h after first use &bull; Single use only</p>
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

    const corsHeaders = {
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Methods': 'GET, OPTIONS',
      'Access-Control-Allow-Headers': 'Content-Type',
    };

    if (request.method === 'OPTIONS') {
      return new Response(null, { headers: corsHeaders });
    }

    // GET /generate — create a single-use key (24h after claim)
    // Rate limited: 1 key per IP per 24h. Refresh returns same key.
    if (path === '/generate') {
      const ip = request.headers.get('CF-Connecting-IP') || 'unknown';
      const ipKey = `ip:${ip}`;

      // Check if this IP already has an unclaimed key
      const existing = await env.AURORA_KEYS.get(ipKey);
      if (existing) {
        const { key: existingKey } = JSON.parse(existing);
        const keyData = await env.AURORA_KEYS.get(existingKey);
        if (keyData) {
          const parsed = JSON.parse(keyData);
          if (parsed.status === 'unclaimed') {
            return new Response(keyPage(existingKey, parsed.duration / 3600), {
              headers: { 'Content-Type': 'text/html', ...corsHeaders },
            });
          }
        }
      }

      // Generate new single-use key
      const key = generateKey();
      const data = {
        created: Date.now(),
        ip,
        duration: DEFAULT_DURATION, // 24h after claiming
        status: 'unclaimed',
      };
      // Shelf life: 7 days to be claimed, then auto-expires
      await env.AURORA_KEYS.put(key, JSON.stringify(data), { expirationTtl: SHELF_LIFE });
      await env.AURORA_KEYS.put(ipKey, JSON.stringify({ key, created: Date.now() }), { expirationTtl: DEFAULT_DURATION });

      // Increment daily counter
      const today = new Date().toISOString().slice(0, 10);
      const countKey = DAILY_COUNT_KEY + today;
      const prev = parseInt(await env.AURORA_KEYS.get(countKey) || '0');
      const dailyCount = prev + 1;
      await env.AURORA_KEYS.put(countKey, String(dailyCount), { expirationTtl: 172800 });

      ctx.waitUntil(sendDiscordWebhook(env, key, ip, dailyCount));

      return new Response(keyPage(key, 24), {
        headers: { 'Content-Type': 'text/html', ...corsHeaders },
      });
    }

    // GET /validate?key=AURORA-XXXX&uid=12345 — validate + claim key
    // First call with a key: claims it for that uid, starts countdown
    // Subsequent calls: only valid if same uid
    if (path === '/validate') {
      const key = url.searchParams.get('key');
      const uid = url.searchParams.get('uid');
      if (!key) {
        return new Response(JSON.stringify({ valid: false, error: 'No key provided' }), {
          headers: { 'Content-Type': 'application/json', ...corsHeaders },
        });
      }

      // Rate limit
      const valIp = request.headers.get('CF-Connecting-IP') || 'unknown';
      const rateLimitKey = `ratelimit:validate:${valIp}`;
      const attempts = parseInt(await env.AURORA_KEYS.get(rateLimitKey) || '0');
      if (attempts >= 10) {
        return new Response(JSON.stringify({ valid: false, error: 'Too many attempts. Try again later.' }), {
          status: 429, headers: { 'Content-Type': 'application/json', ...corsHeaders },
        });
      }
      await env.AURORA_KEYS.put(rateLimitKey, String(attempts + 1), { expirationTtl: 3600 });

      // Format check
      if (!/^AURORA-[A-Z0-9]{4}-[A-Z0-9]{4}-[A-Z0-9]{4}-[A-Z0-9]{4}$/.test(key)) {
        return new Response(JSON.stringify({ valid: false }), {
          headers: { 'Content-Type': 'application/json', ...corsHeaders },
        });
      }

      const stored = await env.AURORA_KEYS.get(key);
      if (!stored) {
        return new Response(JSON.stringify({ valid: false }), {
          headers: { 'Content-Type': 'application/json', ...corsHeaders },
        });
      }

      const data = JSON.parse(stored);

      // Key is unclaimed — claim it now
      if (data.status === 'unclaimed') {
        if (!uid) {
          return new Response(JSON.stringify({ valid: false, error: 'uid required to claim key' }), {
            headers: { 'Content-Type': 'application/json', ...corsHeaders },
          });
        }
        const duration = data.duration || DEFAULT_DURATION;
        const claimed = {
          ...data,
          status: 'claimed',
          claimedBy: uid,
          claimedAt: Date.now(),
          expiresAt: Date.now() + (duration * 1000),
        };
        // Rewrite with TTL = duration from NOW (countdown starts)
        await env.AURORA_KEYS.put(key, JSON.stringify(claimed), { expirationTtl: duration });

        ctx.waitUntil(sendClaimWebhook(env, key, uid, duration));

        return new Response(JSON.stringify({ valid: true, claimed: true, duration }), {
          headers: { 'Content-Type': 'application/json', ...corsHeaders },
        });
      }

      // Key is already claimed
      if (data.status === 'claimed') {
        // Same user — still valid
        if (uid && data.claimedBy === uid) {
          return new Response(JSON.stringify({ valid: true, claimed: true }), {
            headers: { 'Content-Type': 'application/json', ...corsHeaders },
          });
        }
        // Different user — rejected
        return new Response(JSON.stringify({ valid: false, error: 'Key already claimed by another user' }), {
          headers: { 'Content-Type': 'application/json', ...corsHeaders },
        });
      }

      // Legacy keys (no status field) — treat as valid
      return new Response(JSON.stringify({ valid: true }), {
        headers: { 'Content-Type': 'application/json', ...corsHeaders },
      });
    }

    // GET /admin/create?secret=XXX&ttl=HOURS&count=N — admin custom keys
    if (path === '/admin/create') {
      const secret = url.searchParams.get('secret');
      if (secret !== env.ADMIN_SECRET) {
        return new Response('Unauthorized', { status: 401, headers: corsHeaders });
      }

      const ttlHours = Math.min(Math.max(parseInt(url.searchParams.get('ttl') || '24'), 1), 8760);
      const count = Math.min(Math.max(parseInt(url.searchParams.get('count') || '1'), 1), 50);
      const duration = ttlHours * 3600;
      const keys = [];

      for (let i = 0; i < count; i++) {
        const key = generateKey();
        await env.AURORA_KEYS.put(key, JSON.stringify({
          created: Date.now(),
          ip: 'admin',
          duration,
          status: 'unclaimed',
          admin: true,
        }), { expirationTtl: ADMIN_SHELF_LIFE }); // 30 day shelf life
        keys.push(key);
      }

      return new Response(JSON.stringify({
        created: keys.length,
        durationHours: ttlHours,
        shelfLife: '30 days',
        singleUse: true,
        keys,
      }, null, 2), {
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
      const keyDetails = [];
      for (const k of list.keys) {
        if (k.name.startsWith('AURORA-')) {
          const val = await env.AURORA_KEYS.get(k.name);
          if (val) {
            const d = JSON.parse(val);
            keyDetails.push({
              key: k.name,
              status: d.status || 'legacy',
              claimedBy: d.claimedBy || null,
              durationH: Math.round((d.duration || DEFAULT_DURATION) / 3600),
            });
          }
        }
      }

      return new Response(JSON.stringify({ total: keyDetails.length, keys: keyDetails }, null, 2), {
        headers: { 'Content-Type': 'application/json', ...corsHeaders },
      });
    }

    // Default — landing page
    return new Response(errorPage('Visit our Discord for the loadstring!'), {
      headers: { 'Content-Type': 'text/html', ...corsHeaders },
    });
  },
};
