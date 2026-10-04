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

test("FFplay surface pixel contract accepts the source-frame samples", async () => {
  const { evaluateFrameSamples, readContract } = await import(
    "../../scripts/ffplay-surface-pixels.mjs"
  );
  const contract = readContract();
  const samples = contract.samples.map((sample) => ({
    name: sample.name,
    rgba: [...sample.rgba],
  }));

  assert.doesNotThrow(() =>
    evaluateFrameSamples(
      { width: contract.width, height: contract.height, samples },
      contract
    )
  );
});

test("FFplay surface pixel contract rejects an all-black final frame", async () => {
  const { evaluateFrameSamples, readContract } = await import(
    "../../scripts/ffplay-surface-pixels.mjs"
  );
  const contract = readContract();
  const samples = contract.samples.map((sample) => ({
    name: sample.name,
    rgba: [0, 0, 0, 255],
  }));

  assert.throws(
    () =>
      evaluateFrameSamples(
        { width: contract.width, height: contract.height, samples },
        contract
      ),
    /FFplay frame pixel mismatch/
  );
});

test(
  "FFplay playback screenshot matches the original frame pixel contract",
  { skip: !process.env.FFMPEG_KIT_SURFACE_SCREENSHOT },
  async () => {
    const { assertFramePixels } = await import(
      "../../scripts/ffplay-surface-pixels.mjs"
    );
    const result = assertFramePixels({
      imagePath: process.env.FFMPEG_KIT_SURFACE_SCREENSHOT,
      rect: readSurfaceRect(process.env.FFMPEG_KIT_SURFACE_RECT),
      label: "React Native FFplay playback surface",
    });
    assert.equal(result.results.length, 4);
  }
);
