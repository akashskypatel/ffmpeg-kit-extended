'use strict';

const assert = require('node:assert/strict');
const test = require('node:test');

const {CallbackDemandAuthority} = require('../.test-dist/callback-demand.js');

test('installs one bridge and keeps it through the last concurrent lease', async () => {
  const authority = new CallbackDemandAuthority();
  let installs = 0;
  let uninstalls = 0;
  const hooks = {
    install: () => { installs += 1; },
    uninstall: () => { uninstalls += 1; },
  };

  const first = await authority.acquire('log', hooks);
  const second = await authority.acquire('log', hooks);

  assert.equal(installs, 1);
  assert.equal(authority.leaseCount('log'), 2);
  assert.equal(authority.isActive('log'), true);

  await first.release();
  await first.release();
  assert.equal(uninstalls, 0);
  assert.equal(authority.leaseCount('log'), 1);

  await second.release();
  assert.equal(uninstalls, 1);
  assert.equal(authority.leaseCount('log'), 0);
  assert.equal(authority.isActive('log'), false);
});

test('completion, log, and statistics demand are independent', async () => {
  const authority = new CallbackDemandAuthority();
  const completion = await authority.acquire('completion');
  const log = await authority.acquire('log');
  const statistics = await authority.acquire('statistics');

  await log.release();
  assert.equal(authority.isActive('completion'), true);
  assert.equal(authority.isActive('log'), false);
  assert.equal(authority.isActive('statistics'), true);

  await statistics.release();
  await completion.release();
  assert.equal(authority.isActive('completion'), false);
  assert.equal(authority.isActive('statistics'), false);
});

test('failed installation leaves demand unowned and retryable', async () => {
  const authority = new CallbackDemandAuthority();
  const installError = new Error('install failed');

  await assert.rejects(
    authority.acquire('statistics', {
      install: () => { throw installError; },
      uninstall: () => {},
    }),
    error => error === installError,
  );
  assert.equal(authority.leaseCount('statistics'), 0);
  assert.equal(authority.isActive('statistics'), false);

  const retry = await authority.acquire('statistics');
  assert.equal(authority.leaseCount('statistics'), 1);
  await retry.release();
});

test('failed uninstall clears ownership without corrupting a later acquire', async () => {
  const authority = new CallbackDemandAuthority();
  let installs = 0;
  let shouldFail = true;
  const lease = await authority.acquire('completion', {
    install: () => { installs += 1; },
    uninstall: () => {
      if (shouldFail) {
        shouldFail = false;
        throw new Error('uninstall failed');
      }
    },
  });

  await assert.rejects(lease.release(), /uninstall failed/);
  assert.equal(authority.leaseCount('completion'), 0);
  assert.equal(authority.isActive('completion'), false);

  const retry = await authority.acquire('completion', {
    install: () => { installs += 1; },
    uninstall: () => {},
  });
  assert.equal(installs, 2);
  await retry.release();
});
