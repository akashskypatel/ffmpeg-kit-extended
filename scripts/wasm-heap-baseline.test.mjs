import assert from 'node:assert/strict';
import test from 'node:test';
import {assertNativeHeapBaseline, clearNativeSessionHistory} from './fixtures/wasm-heap-baseline-contract.mjs';

const policy = {
  warmupCycles: 3,
  measuredCycles: 10,
  settleMs: 500,
  samplesPerSettlement: 5,
  sampleIntervalMs: 50,
  maxAboveBaselineBytes: 64 * 1024,
  maxTailDriftBytes: 16 * 1024,
  tailDriftDefinition: 'mean last three cycle maxima minus mean first three cycle maxima',
  metric: 'mallinfo().uordblks',
};
const fixturePath = '/tmp/wasm-heap-baseline.ts';
const command = `-autoexit ${fixturePath}`;

function validReport(cycleMaxima = Array(10).fill(100000), baselineSamples = Array(5).fill(100000)) {
  const warmups = Array.from({length: 3}, (_, index) => makeRun(index));
  const cycles = cycleMaxima.map((value, index) => ({
    index: index + 1,
    run: makeRun(index + 3),
    samples: Array(5).fill(value),
    maximumBytes: value,
  }));
  const allRuns = [...warmups, ...cycles.map((cycle) => cycle.run)];
  return {
    contract: 'wasm-heap-baseline',
    status: 'passed',
    artifactIdentity: {
      artifactRole: 'same-source-diagnostic-heap-only',
      sourceCommit: '779cecd74bb7b10ab9f0d28c1e14e2a440eacd4a',
      wasmSha256: 'a'.repeat(64),
      loaderSha256: 'b'.repeat(64),
      productionPinUsed: false,
    },
    heapSnapshotExport: '_ffmpeg_kit_test_http_io_heap_snapshot',
    hookPresent: true,
    metric: 'mallinfo().uordblks',
    policy: {...policy},
    fixture: {path: fixturePath, bytes: 1024, importedBeforeWarmupAndBaseline: true},
    callbackSlotRetained: true,
    warmups,
    baselineSamples,
    baselineMaximumBytes: Math.max(...baselineSamples),
    cycles,
    tailDriftBytes: mean(cycleMaxima.slice(-3)) - mean(cycleMaxima.slice(0, 3)),
    sessions: allRuns,
    callbackEvents: allRuns.map((run, runIndex) => ({
      runIndex, handle: run.handle, userData: run.callbackToken,
    })),
    callbackViolations: [],
    cleanup: {
      fileUnlinked: true,
      finalHistoryCleared: true,
      historyCountAfterClear: 0,
      callbackTokensFreed: 13,
      callbackSlotRetained: true,
    },
  };
}

function makeRun(index) {
  return {
    name: `cycle ${index}`,
    command,
    handle: index + 1,
    sessionId: String(index + 101),
    callbackToken: index + 4096,
    state: 2,
    returnCode: 0,
    callbackCount: 1,
    callbackObservedCount: 1,
    callbackHandles: [index + 1],
    handleReleased: true,
    messagesInTransmit: 0,
    callbackTokenFreed: true,
    sessionHistoryCleared: true,
    historyCountAfterClear: 0,
  };
}

function mean(values) {
  return values.reduce((sum, value) => sum + value, 0) / values.length;
}

test('accepts the exact fixed-policy native heap report', () => {
  const report = validReport();
  assert.equal(assertNativeHeapBaseline(report), report);
});

test('verifies empty native history and frees the owned readback array', () => {
  const freed = [];
  const module = {
    HEAPU32: new Uint32Array(16),
    _ffmpeg_kit_clear_sessions() {},
    _ffmpeg_kit_get_sessions: () => 4,
    _ffmpeg_kit_free: (pointer) => freed.push(pointer),
  };
  assert.equal(clearNativeSessionHistory(module), 0);
  assert.deepEqual(freed, [4]);
});

test('rejects silently failed clear and releases all returned handles and array', () => {
  const released = [];
  const freed = [];
  const module = {
    HEAPU32: new Uint32Array([0, 8, 12, 0]),
    _ffmpeg_kit_clear_sessions() {},
    _ffmpeg_kit_get_sessions: () => 4,
    _ffmpeg_kit_handle_release: (pointer) => released.push(pointer),
    _ffmpeg_kit_free: (pointer) => freed.push(pointer),
  };
  assert.throws(() => clearNativeSessionHistory(module), /history was not empty/);
  assert.deepEqual(released, [8, 12]);
  assert.deepEqual(freed, [4]);
  module._ffmpeg_kit_get_sessions = () => 0;
  assert.throws(() => clearNativeSessionHistory(module), /readback failed/);
});

test('rejects cleanup claims without a zero history readback', () => {
  const report = validReport();
  delete report.cycles[0].run.historyCountAfterClear;
  assert.throws(() => assertNativeHeapBaseline(report), /history was not cleared/);
});

test('accepts a measured maximum exactly at the baseline plus 64 KiB boundary', () => {
  const report = validReport([165536, ...Array(9).fill(100000)]);
  assert.equal(assertNativeHeapBaseline(report), report);
});

test('accepts lower allocation values', () => {
  const report = validReport(Array(10).fill(80000), Array(5).fill(100000));
  assert.equal(assertNativeHeapBaseline(report), report);
});

test('rejects a retained 300 KiB frame allocation above the fixed absolute band', () => {
  const report = validReport([407200, ...Array(9).fill(100000)]);
  assert.throws(() => assertNativeHeapBaseline(report), /exceeded the baseline band/);
});

test('rejects smaller cumulative drift that stays inside the absolute band', () => {
  const maxima = [100000, 100000, 100000, 100000, 100000, 100000, 120000, 120000, 120000, 120000];
  const report = validReport(maxima);
  assert.throws(() => assertNativeHeapBaseline(report), /Ten-cycle tail drift/);
});

test('rejects a report missing the native metric', () => {
  const report = validReport();
  report.metric = 'HEAPU8.buffer';
  assert.throws(() => assertNativeHeapBaseline(report), /native heap metric/);
});

test('rejects a report missing measured cycles', () => {
  const report = validReport();
  report.cycles.pop();
  assert.throws(() => assertNativeHeapBaseline(report), /exactly 10 measured cycles/);
});

