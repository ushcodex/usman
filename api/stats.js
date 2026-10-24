module.exports = async function handler(req, res) {
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
        step1: 'Create a free database at https://upstash.com (10,000 commands/day free).',
        step2: 'Go to your database details -> REST API tab.',
        step3: 'Copy UPSTASH_REDIS_REST_URL and UPSTASH_REDIS_REST_TOKEN into your Vercel Project Settings > Environment Variables.',
        step4: 'Add ADMIN_PASSWORD with your desired secret password.'
      }
    });
  }

  async function execPipeline(pipeline) {
    const upRes = await fetch(`${UPSTASH_URL}/pipeline`, {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${UPSTASH_TOKEN}`,
        'Content-Type': 'application/json'
      },
      body: JSON.stringify(pipeline)
    });
    if (!upRes.ok) throw new Error(await upRes.text());
    return await upRes.json();
  }

  try {
    const rangeParam = req.query.range || req.query.days || '30';
    const now = new Date();
    let dates = [];

    if (rangeParam === 'all' || rangeParam === 'infinite') {
      // Query all recorded dates from the analytics:dates sorted set
      const dateRes = await fetch(`${UPSTASH_URL}/zrange/analytics:dates/0/-1`, {
        headers: { Authorization: `Bearer ${UPSTASH_TOKEN}` }
      });
      const dateJson = await dateRes.json();
      dates = Array.isArray(dateJson.result) ? dateJson.result : [];

      // Fallback if no dates indexed yet
      if (dates.length === 0) {
        for (let i = 29; i >= 0; i--) {
          const d = new Date(now);
          d.setDate(d.getDate() - i);
          dates.push(d.toISOString().slice(0, 10));
        }
      }
    } else {
      let numDays = parseInt(rangeParam, 10);
      if (isNaN(numDays)) {
        if (rangeParam === '7d') numDays = 7;
        else if (rangeParam === '90d') numDays = 90;
        else if (rangeParam === '1y') numDays = 365;
        else numDays = 30;
      }
      numDays = Math.min(Math.max(numDays, 1), 730); // up to 2 years daily

      for (let i = numDays - 1; i >= 0; i--) {
        const d = new Date(now);
        d.setDate(d.getDate() - i);
        dates.push(d.toISOString().slice(0, 10));
      }
    }

    const today = now.toISOString().slice(0, 10);

    // Initial pipeline for all-time totals and breakdowns
    const pipeline = [
      ['GET', 'analytics:pv:total'],
      ['PFCOUNT', 'analytics:unique:all'],
      ['ZREVRANGE', 'analytics:pages', 0, 9, 'WITHSCORES'],
      ['ZREVRANGE', 'analytics:referrers', 0, 9, 'WITHSCORES'],
      ['ZREVRANGE', 'analytics:countries', 0, 9, 'WITHSCORES'],
      ['ZREVRANGE', 'analytics:devices', 0, 4, 'WITHSCORES'],
      ['ZREVRANGE', 'analytics:browsers', 0, 4, 'WITHSCORES'],
      ['ZREVRANGE', 'analytics:os', 0, 4, 'WITHSCORES'],
      ['ZREVRANGE', 'analytics:events', 0, 9, 'WITHSCORES'],
      ['LRANGE', 'analytics:recent', 0, 49]
    ];

    // Add daily stats in the same pipeline (up to 120 dates per request)
    const queryDates = dates.slice(-120);
    for (const d of queryDates) {
      pipeline.push(['GET', `analytics:pv:${d}`]);
      pipeline.push(['PFCOUNT', `analytics:unique:${d}`]);
    }

    const results = await execPipeline(pipeline);
    let idx = 0;

    const totalPv = parseInt(results[idx++]?.result || '0', 10);
    const totalUnique = parseInt(results[idx++]?.result || '0', 10);

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

    const daily = [];
    let rangePv = 0;
    let rangeUnique = 0;
    let todayPv = 0;
    let todayUnique = 0;

    for (let i = 0; i < queryDates.length; i++) {
      const pv = parseInt(results[idx++]?.result || '0', 10);
      const unique = parseInt(results[idx++]?.result || '0', 10);
      const dateStr = queryDates[i];

      daily.push({ date: dateStr, pv, unique });
      rangePv += pv;
      rangeUnique += unique;

      if (dateStr === today) {
        todayPv = pv;
        todayUnique = unique;
      }
    }

    return res.status(200).json({
      pending_setup: false,
      summary: {
        totalPv,
        totalUnique,
        rangePv,
        rangeUnique,
        todayPv,
        todayUnique,
        timeframe: rangeParam,
        totalDatesRecorded: dates.length
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
