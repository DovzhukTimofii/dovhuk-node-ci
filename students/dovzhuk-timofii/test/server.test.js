const { test } = require('node:test');
const assert = require('node:assert/strict');
const { createServer, calculate } = require('../src/server');
test('Ohm law and power, including zero voltage', () => {
  assert.deepEqual(calculate(12, 100), { voltage: 12, resistance: 100, current: 0.12, power: 1.44 });
  assert.equal(calculate(0, 10).power, 0);
  for (const pair of [[12,0],[12,-1],[-1,10],[Infinity,1],[1,NaN]]) assert.throws(() => calculate(...pair));
});
test('HTTP contract and validation', async t => {
  const server = createServer('');
  await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
  t.after(() => new Promise(resolve => server.close(resolve)));
  const base = `http://127.0.0.1:${server.address().port}`;
  assert.match(await (await fetch(base)).text(), /Ohm Lab/);
  const response = await fetch(base + '/api/ohm?voltage=12&resistance=100');
  assert.equal(response.status, 200);
  assert.equal((await response.json()).current, 0.12);
  for (const query of ['voltage=12&resistance=0','voltage=&resistance=10','voltage=abc&resistance=10','resistance=10']) {
    assert.equal((await fetch(base + '/api/ohm?' + query)).status, 400);
  }
  assert.equal((await fetch(base + '/health')).status, 200);
  assert.equal((await fetch(base + '/ready')).status, 200);
  assert.equal((await fetch(base + '/missing')).status, 404);
  assert.equal((await fetch(base + '/', {method:'POST'})).status, 405);
});
test('readiness fails when configured database is unreachable', async t => {
  const server = createServer('postgres://nobody:invalid@127.0.0.1:1/missing');
  await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
  t.after(() => new Promise(resolve => server.close(resolve)));
  assert.equal((await fetch(`http://127.0.0.1:${server.address().port}/ready`)).status, 503);
});
