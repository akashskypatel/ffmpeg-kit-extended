from pathlib import Path

path = Path("FFmpegKit/scripts/verify-binary-exports.py")
text = path.read_text()
old = '''            permitted = set(forbidden_owned_metadata(removed))
'''
new = '''            permitted = set(forbidden_owned_metadata(removed))
            # This baseline-only test hook is deliberately removed from all
            # production binaries under B08; keep the exception exact so no
            # other public C ABI removal is implicitly approved.
            permitted.update(
                name
                for name in removed
                if name in {
                    "ffmpeg_kit_test_emit_unattributed_log",
                    "_ffmpeg_kit_test_emit_unattributed_log",
                }
            )
'''
if text.count(old) != 1:
    raise SystemExit(f"expected one baseline-removal policy point, found {text.count(old)}")
path.write_text(text.replace(old, new))
