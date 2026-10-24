module.exports = async function handler(req, res) {
  // CORS & caching headers
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization');
  res.setHeader('Cache-Control', 'no-store, no-cache, must-revalidate, proxy-revalidate');

  if (req.method === 'OPTIONS') {
    return res.status(200).end();
  }

  if (req.method !== 'GET') {
    return res.status(405).json({ error: 'Method not allowed' });
  }

  // Authentication check
  const configuredPassword = process.env.ADMIN_PASSWORD;
  const authHeader = req.headers['authorization'] || '';
  const token = authHeader.replace(/^Bearer\s+/i, '').trim() || req.query.key || '';

  if (configuredPassword && token !== configuredPassword) {
    return res.status(401).json({ error: 'Unauthorized. Invalid password or token.' });
  }

  const UPSTASH_URL = process.env.UPSTASH_REDIS_REST_URL;
  const UPSTASH_TOKEN = process.env.UPSTASH_REDIS_REST_TOKEN;

  if (!UPSTASH_URL || !UPSTASH_TOKEN) {
    return res.status(200).json({
      pending_setup: true,
      message: 'Upstash Redis environment variables are not configured.',
      guide: {
        step1: 'Create a free database at https://upstash.com (takes 1 minute, 10,000 commands/day free).',
        step2: 'Go to your database details -> REST API tab.',
        step3: 'Copy UPSTASH_REDIS_REST_URL and UPSTASH_REDIS_REST_TOKEN into your Vercel Project Settings > Environment Variables.',
        step4: 'Add ADMIN_PASSWORD with your desired secret password.'
      }
    });
  }

  try {
    const daysParam = parseInt(req.query.days || '30', 10);
    const numDays = Math.min(Math.max(isNaN(daysParam) ? 30 : daysParam, 1), 90);

    // Build date array for the requested range (YYYY-MM-DD)
    const dates = [];
    const now = new Date();
    for (let i = numDays - 1; i >= 0; i--) {
      const d = new Date(now);
      d.setDate(d.getDate() - i);
      dates.push(d.toISOString().slice(0, 10));
    }

    const today = dates[dates.length - 1];

    // Build pipeline
    const pipeline = [
      ['GET', 'analytics:pv:total'],
      ['PFCOUNT', 'analytics:unique:all']
    ];

    // Add daily stats
    for (const d of dates) {
      pipeline.push(['GET', `analytics:pv:${d}`]);
      pipeline.push(['PFCOUNT', `analytics:unique:${d}`]);
    }

    // Add breakdowns
    pipeline.push(['ZREVRANGE', 'analytics:pages', 0, 9, 'WITHSCORES']);
    pipeline.push(['ZREVRANGE', 'analytics:referrers', 0, 9, 'WITHSCORES']);
    pipeline.push(['ZREVRANGE', 'analytics:countries', 0, 9, 'WITHSCORES']);
    pipeline.push(['ZREVRANGE', 'analytics:devices', 0, 4, 'WITHSCORES']);
    pipeline.push(['ZREVRANGE', 'analytics:browsers', 0, 4, 'WITHSCORES']);
    pipeline.push(['ZREVRANGE', 'analytics:os', 0, 4, 'WITHSCORES']);
    pipeline.push(['ZREVRANGE', 'analytics:events', 0, 9, 'WITHSCORES']);
    pipeline.push(['LRANGE', 'analytics:recent', 0, 49]);

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
      console.error('Stats query error:', err);
      return res.status(500).json({ error: 'Database read failed' });
    }

    const results = await upstashRes.json();
    let idx = 0;

    const totalPv = parseInt(results[idx++]?.result || '0', 10);
    const totalUnique = parseInt(results[idx++]?.result || '0', 10);

    const daily = [];
    let rangePv = 0;
    let rangeUnique = 0;
    let todayPv = 0;
    let todayUnique = 0;

    for (let i = 0; i < dates.length; i++) {
      const pv = parseInt(results[idx++]?.result || '0', 10);
      const unique = parseInt(results[idx++]?.result || '0', 10);
      const dateStr = dates[i];

      daily.push({ date: dateStr, pv, unique });
      rangePv += pv;
      rangeUnique += unique;

      if (dateStr === today) {
        todayPv = pv;
        todayUnique = unique;
      }
    }

    function parseZSet(rawArr) {
      if (!Array.isArray(rawArr)) return [];
      const list = [];
      for (let i = 0; i < rawArr.length; i += 2) {
        list.push({
          name: rawArr[i],
          count: parseInt(rawArr[i + 1] || '0', 10)
        });
      }
      return list;
    }

    const pages = parseZSet(results[idx++]?.result);
    const referrers = parseZSet(results[idx++]?.result);
    const countries = parseZSet(results[idx++]?.result);
    const devices = parseZSet(results[idx++]?.result);
    const browsers = parseZSet(results[idx++]?.result);
    const os = parseZSet(results[idx++]?.result);
    const events = parseZSet(results[idx++]?.result);

    const rawRecent = results[idx++]?.result || [];
    const recent = rawRecent.map(item => {
      try {
        return typeof item === 'string' ? JSON.parse(item) : item;
      } catch (e) {
        return null;
      }
    }).filter(Boolean);

    return res.status(200).json({
      pending_setup: false,
      summary: {
        totalPv,
        totalUnique,
        rangePv,
        rangeUnique,
        todayPv,
        todayUnique,
        days: numDays
      },
      daily,
      pages,
      referrers,
      countries,
      devices,
      browsers,
      os,
      events,
      recent
    });
  } catch (err) {
    console.error('Stats handler error:', err);
    return res.status(500).json({ error: 'Internal stats error' });
  }
};
