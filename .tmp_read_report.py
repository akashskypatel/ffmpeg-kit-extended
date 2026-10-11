import json
import re
from pathlib import Path

for path in [
    Path("/tmp/ffmpeg-kit-wasm-b08.json"),
    Path("/home/vscode/ffmpeg-kit-builders/export-verification/baseline/wasm-wasm32/baseline.json"),
]:
    data = json.loads(path.read_text())
    print(f"--- {path} ---")
    print("keys=", sorted(data))
    print("errors=", data.get("errors"))
    print("checks=", data.get("checks"))
    print("baseline=", data.get("baseline"))
    exports = data.get("exports", [])
    print("Ho exports=", [name for name in exports if name == "Ho"])
    print("test names=", [name for name in exports if "test" in name.lower() or "log" in name.lower()][:30])

js_path = Path("/home/vscode/ffmpeg-kit-builders/export-verification/baseline/wasm-wasm32/ffmpegkit.mjs")
js = js_path.read_text()
for needle in ("ffmpeg_kit_test_emit_unattributed_log", "Ho:"):
    index = js.find(needle)
    print(f"--- {needle} at {index} ---")
    print(js[max(0, index - 220):index + 320])
for match in list(re.finditer(r"(?<![A-Za-z0-9_$])Ho(?![A-Za-z0-9_$])", js))[:10]:
    print("Ho token context=", js[max(0, match.start() - 120):match.end() + 180])
