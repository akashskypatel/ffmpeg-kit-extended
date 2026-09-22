'use strict';

const assert = require('node:assert/strict');
const test = require('node:test');

const {CallbackDemandAuthority} = require('../.test-dist/callback-demand.js');

test('installs one bridge and keeps it through the last concurrent lease', () => {
  const authority = new CallbackDemandAuthority();
  let installs = 0;
  let uninstalls = 0;
  const hooks = {
    install: () => { installs += 1; },
    uninstall: () => { uninstalls += 1; },
  };

  const first = authority.acquire('log', hooks);
  const second = authority.acquire('log', hooks);

  assert.equal(installs, 1);
  assert.equal(authority.leaseCount('log'), 2);
  assert.equal(authority.isActive('log'), true);

  first.release();
  first.release();
  assert.equal(uninstalls, 0);
  assert.equal(authority.leaseCount('log'), 1);

  second.release();
  assert.equal(uninstalls, 1);
  assert.equal(authority.leaseCount('log'), 0);
  assert.equal(authority.isActive('log'), false);
});

test('completion, log, and statistics demand are independent', () => {
  const authority = new CallbackDemandAuthority();
  const completion = authority.acquire('completion');
  const log = authority.acquire('log');
  const statistics = authority.acquire('statistics');

  log.release();
  assert.equal(authority.isActive('completion'), true);
  assert.equal(authority.isActive('log'), false);
  assert.equal(authority.isActive('statistics'), true);

  statistics.release();
  completion.release();
  assert.equal(authority.isActive('completion'), false);
  assert.equal(authority.isActive('statistics'), false);
});

test('failed installation leaves demand unowned and retryable', () => {
  const authority = new CallbackDemandAuthority();
  const installError = new Error('install failed');

  assert.throws(
    () => authority.acquire('statistics', {
      install: () => { throw installError; },
      uninstall: () => {},
    }),
    error => error === installError,
  );
  assert.equal(authority.leaseCount('statistics'), 0);
  assert.equal(authority.isActive('statistics'), false);

  const retry = authority.acquire('statistics');
  assert.equal(authority.leaseCount('statistics'), 1);
  retry.release();
});

test('failed uninstall clears ownership without corrupting a later acquire', () => {
  const authority = new CallbackDemandAuthority();
  let installs = 0;
  let shouldFail = true;
  const lease = authority.acquire('completion', {
    install: () => { installs += 1; },
    uninstall: () => {
      if (shouldFail) {
        shouldFail = false;
        throw new Error('uninstall failed');
      }
    },
  });

  assert.throws(() => lease.release(), /uninstall failed/);
  assert.equal(authority.leaseCount('completion'), 0);
  assert.equal(authority.isActive('completion'), false);

  const retry = authority.acquire('completion', {
    install: () => { installs += 1; },
    uninstall: () => {},
  });
  assert.equal(installs, 2);
  retry.release();
});
