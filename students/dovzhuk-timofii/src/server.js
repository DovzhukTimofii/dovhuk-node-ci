const http = require('node:http');
const fs = require('node:fs');
const path = require('node:path');
const { Pool } = require('pg');

function calculate(voltage, resistance) {
  if (!Number.isFinite(voltage) || !Number.isFinite(resistance) || voltage < 0 || resistance <= 0) {
    throw new Error('Напруга має бути невід’ємною, опір — більшим за нуль.');
  }
  const current = voltage / resistance;
  const power = voltage * current;
  if (!Number.isFinite(current) || !Number.isFinite(power)) throw new Error('Завеликі значення.');
  return { voltage, resistance, current, power };
}

function createServer(databaseUrl = process.env.DATABASE_URL) {
  const pool = databaseUrl ? new Pool({ connectionString: databaseUrl, connectionTimeoutMillis: 2000, query_timeout: 2000 }) : null;
  const server = http.createServer(async (req, res) => {
    const url = new URL(req.url, 'http://localhost');
    function json(status, value) {
      res.writeHead(status, { 'Content-Type': 'application/json; charset=utf-8' });
      res.end(JSON.stringify(value));
    }
    if (req.method !== 'GET') return json(405, { error: 'Method not allowed' });
    if (url.pathname === '/health') return json(200, { status: 'ok' });
    if (url.pathname === '/ready') {
      try {
        if (pool) await pool.query('SELECT 1');
        return json(200, { status: 'ready', database: pool ? 'connected' : 'disabled' });
      } catch { return json(503, { status: 'not ready', database: 'unavailable' }); }
    }
    if (url.pathname === '/api/ohm') {
      try {
        const u = url.searchParams.get('voltage');
        const r = url.searchParams.get('resistance');
        if (u === null || r === null || !u.trim() || !r.trim()) throw new Error('Вкажіть voltage та resistance.');
        return json(200, calculate(Number(u), Number(r)));
      } catch (error) { return json(400, { error: error.message }); }
    }
    if (url.pathname === '/') {
      res.writeHead(200, { 'Content-Type': 'text/html; charset=utf-8' });
      return res.end(fs.readFileSync(path.join(__dirname, 'index.html')));
    }
    return json(404, { error: 'Not found' });
  });
  server.on('close', () => { if (pool) pool.end(); });
  return server;
}
if (require.main === module) {
  const server = createServer();
  server.listen(process.env.PORT || 3000, '0.0.0.0', () => console.log('Ohm Lab is running'));
  for (const signal of ['SIGTERM', 'SIGINT']) process.on(signal, () => {
    server.close(() => process.exit(0));
    setTimeout(() => process.exit(1), 5000).unref();
  });
}
module.exports = { createServer, calculate };
