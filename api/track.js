const crypto = require('crypto');

module.exports = async function handler(req, res) {
  // Set CORS headers
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');

  if (req.method === 'OPTIONS') {
    return res.status(200).end();
  }

  if (req.method !== 'POST') {
    return res.status(405).json({ error: 'Method not allowed' });
  }

  const UPSTASH_URL = process.env.UPSTASH_REDIS_REST_URL;
  const UPSTASH_TOKEN = process.env.UPSTASH_REDIS_REST_TOKEN;

  // Graceful fallback if credentials are not yet configured in Vercel
  if (!UPSTASH_URL || !UPSTASH_TOKEN) {
    return res.status(200).json({
      status: 'pending_setup',
      message: 'Set UPSTASH_REDIS_REST_URL and UPSTASH_REDIS_REST_TOKEN in Vercel Environment Variables.'
    });
  }

  try {
    let body = req.body;
    if (typeof body === 'string') {
      try { body = JSON.parse(body); } catch (e) { body = {}; }
    }
    body = body || {};

    const isEvent = body.type === 'event';
    const eventName = (body.event || 'general_event').slice(0, 60);
    const rawPath = (body.path || '/').split('?')[0];
    const path = rawPath.endsWith('/') && rawPath.length > 1 ? rawPath.slice(0, -1) : rawPath;

    // Process Referrer
    const rawRef = body.referrer || 'Direct';
    let referrer = 'Direct';
    if (rawRef && rawRef !== 'Direct' && rawRef !== 'Internal') {
      try {
        referrer = rawRef.replace(/^https?:\/\//i, '').replace(/^www\./i, '').split('/')[0];
        if (referrer.includes(req.headers.host || 'usman.engineer')) {
          referrer = 'Internal';
        }
      } catch (e) {
        referrer = 'Direct';
      }
    }

    const device = body.screen || 'Desktop';
    const country = (req.headers['x-vercel-ip-country'] || 'Unknown').toUpperCase();
    const city = req.headers['x-vercel-ip-city'] ? decodeURIComponent(req.headers['x-vercel-ip-city']) : 'Unknown';
    const userAgent = req.headers['user-agent'] || '';

    // Device / Browser / OS detection from user-agent
    let browser = 'Other';
    if (/chrome|crios/i.test(userAgent) && !/edg|opr/i.test(userAgent)) browser = 'Chrome';
    else if (/safari/i.test(userAgent) && !/chrome/i.test(userAgent)) browser = 'Safari';
    else if (/firefox|fxios/i.test(userAgent)) browser = 'Firefox';
    else if (/edg/i.test(userAgent)) browser = 'Edge';
    else if (/opr\//i.test(userAgent)) browser = 'Opera';

    let os = 'Other';
    if (/windows/i.test(userAgent)) os = 'Windows';
    else if (/macintosh|mac os x/i.test(userAgent)) os = 'macOS';
    else if (/android/i.test(userAgent)) os = 'Android';
    else if (/iphone|ipad|ipod/i.test(userAgent)) os = 'iOS';
    else if (/linux/i.test(userAgent)) os = 'Linux';

    // Privacy-safe daily visitor hash (IP is never stored)
    const ip = (req.headers['x-forwarded-for'] || req.socket.remoteAddress || '').split(',')[0].trim();
    const today = new Date().toISOString().slice(0, 10); // YYYY-MM-DD
    const salt = process.env.ANALYTICS_SALT || 'usman-analytics-salt';
    const visitorHash = crypto.createHash('sha256')
      .update(`${ip}-${userAgent}-${today}-${salt}`)
      .digest('hex').slice(0, 16);

    const pipeline = [];

    if (isEvent) {
      // Record Custom Event
      pipeline.push(['ZINCRBY', 'analytics:events', 1, eventName]);
      pipeline.push(['INCR', 'analytics:events:total']);
    } else {
      // Pageview counters
      pipeline.push(['INCR', `analytics:pv:${today}`]);
      pipeline.push(['INCR', 'analytics:pv:total']);

      // Unique visitors via Redis HyperLogLog (PFADD)
      pipeline.push(['PFADD', `analytics:unique:${today}`, visitorHash]);
      pipeline.push(['PFADD', 'analytics:unique:all', visitorHash]);

      // Dimension Sorted Sets
      pipeline.push(['ZINCRBY', 'analytics:pages', 1, path]);
      if (referrer && referrer !== 'Internal') {
        pipeline.push(['ZINCRBY', 'analytics:referrers', 1, referrer]);
      }
      if (country && country !== 'Unknown') {
        pipeline.push(['ZINCRBY', 'analytics:countries', 1, country]);
      }
      pipeline.push(['ZINCRBY', 'analytics:devices', 1, device]);
      pipeline.push(['ZINCRBY', 'analytics:os', 1, os]);
      pipeline.push(['ZINCRBY', 'analytics:browsers', 1, browser]);

      // Recent visits stream (capped at latest 50 entries)
      const logEntry = JSON.stringify({
        ts: Date.now(),
        path,
        ref: referrer,
        c: country,
        city: city !== 'Unknown' ? city : null,
        d: device,
        b: browser,
        os
      });
      pipeline.push(['LPUSH', 'analytics:recent', logEntry]);
      pipeline.push(['LTRIM', 'analytics:recent', 0, 49]);
    }

    // Execute atomic batch in 1 HTTP roundtrip
    const upstashRes = await fetch(`${UPSTASH_URL}/pipeline`, {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${UPSTASH_TOKEN}`,
        'Content-Type': 'application/json'
      },
      body: JSON.stringify(pipeline)
    });

    if (!upstashRes.ok) {
      const err = await upstashRes.text();
      console.error('Upstash pipeline error:', err);
      return res.status(500).json({ error: 'Database write error' });
    }

    return res.status(200).json({ ok: true });
  } catch (err) {
    console.error('Track handler error:', err);
    return res.status(500).json({ error: 'Internal handler error' });
  }
};
