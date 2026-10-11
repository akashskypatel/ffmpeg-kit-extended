import json
from pathlib import Path

path = Path("/home/vscode/ffmpeg-kit-builders/FFmpegKit/build/export-verification/linked-linux-x86_64.json")
data = json.loads(path.read_text())
for key in ("phase", "binary", "sha256", "build_flags", "cmake_cache", "exports", "baseline_delta", "checks", "errors", "pass"):
    print(f"{key}={data.get(key)}")
