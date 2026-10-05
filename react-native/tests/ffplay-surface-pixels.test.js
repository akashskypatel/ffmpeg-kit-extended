const assert = require("node:assert/strict");
const test = require("node:test");

function readSurfaceRect(value) {
  if (!value) return undefined;
  const values = value.split(",").map(Number);
  assert.equal(
    values.length,
    4,
    "FFMPEG_KIT_SURFACE_RECT must be x,y,width,height"
  );
  assert.ok(
    values.every(Number.isFinite),
    "FFMPEG_KIT_SURFACE_RECT must be numeric"
  );
  return { x: values[0], y: values[1], width: values[2], height: values[3] };
}

test("FFplay playback contract accepts each changing source-frame phase", async () => {
  const { evaluateFrameSequence, readContract } = await import(
    "../../scripts/ffplay-surface-pixels.mjs"
  );
  const contract = readContract();
  const frames = contract.phases.map((phase) => ({
    width: contract.width,
    height: contract.height,
    samples: contract.samples.map((sample) => ({
      name: sample.name,
      rgba: [...phase.rgba],
    })),
  }));

  assert.doesNotThrow(() =>
    evaluateFrameSequence(frames, contract)
  );
});

test("FFplay playback contract rejects a static frame across all timestamps", async () => {
  const { evaluateFrameSequence, readContract } = await import(
    "../../scripts/ffplay-surface-pixels.mjs"
  );
  const contract = readContract();
  const staticFrame = {
    width: contract.width,
    height: contract.height,
    samples: contract.samples.map((sample) => ({
      name: sample.name,
      rgba: [...contract.phases[0].rgba],
    })),
  };

  assert.throws(
    () => evaluateFrameSequence(contract.phases.map(() => staticFrame), contract),
    /FFplay (green|blue|white) frame pixel mismatch|did not change/
  );
});

test("FFplay playback contract rejects black frames at every timestamp", async () => {
  const { evaluateFrameSequence, readContract } = await import(
    "../../scripts/ffplay-surface-pixels.mjs"
  );
  const contract = readContract();
  const blackFrame = {
    width: contract.width,
    height: contract.height,
    samples: contract.samples.map((sample) => ({
      name: sample.name,
      rgba: [0, 0, 0, 255],
    })),
  };

  assert.throws(
    () => evaluateFrameSequence(contract.phases.map(() => blackFrame), contract),
    /FFplay .* frame pixel mismatch/
  );
});

function readSurfaceScreenshots() {
  const configured = process.env.FFMPEG_KIT_SURFACE_SCREENSHOTS;
  if (configured) return JSON.parse(configured);
  const legacy = process.env.FFMPEG_KIT_SURFACE_SCREENSHOT;
  return legacy ? [legacy] : undefined;
}

test(
  "FFplay playback screenshots match all changing frame phases",
  { skip: !readSurfaceScreenshots() },
  async () => {
    const { assertFrameSequence } = await import(
      "../../scripts/ffplay-surface-pixels.mjs"
    );
    const result = assertFrameSequence({
      imagePaths: readSurfaceScreenshots(),
      rect: readSurfaceRect(process.env.FFMPEG_KIT_SURFACE_RECT),
      label: "React Native FFplay playback surface",
    });
    assert.equal(result.phases.length, 4);
  }
);
