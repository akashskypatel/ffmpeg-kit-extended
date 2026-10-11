from pathlib import Path

header = Path("FFmpegKit/src/ffmpegkit_wrapper.h")
source = Path("FFmpegKit/src/ffmpegkit_wrapper.cpp")
h = header.read_text()
s = source.read_text()
old_header = """/**
 * Emits a synthetic unattributed log through the shared FFmpeg log callback.
 *
 * Test-only helper used by wrapper regression tests to verify that callbacks
 * routed to session `0` do not interfere with real session completion.
 *
 * @param message the message to emit
 */
FFMPEG_KIT_C_EXPORT void
ffmpeg_kit_test_emit_unattributed_log(const char *message);
"""
new_header = """#ifdef FFMPEG_KIT_TEST_HOOKS
/**
 * Emits a synthetic unattributed log through the shared FFmpeg log callback.
 *
 * Test-only helper used by wrapper regression tests to verify that callbacks
 * routed to session `0` do not interfere with real session completion.
 *
 * @param message the message to emit
 */
FFMPEG_KIT_C_EXPORT void
ffmpeg_kit_test_emit_unattributed_log(const char *message);
#endif
"""
old_source = """void DLL_ALIGN ffmpeg_kit_test_emit_unattributed_log(const char *message) {
    try {
        av_log(nullptr, AV_LOG_INFO, "%s\\n", message ? message : "");
    } catch (const std::exception &e) {
        std::cerr << "[" << getCurrentTimeStamp()
                  << "] [ffmpeg-kit] [Exception] in ffmpeg_kit_test_emit_unattributed_log: "
                  << e.what() << std::endl;
        PRINT_STACK_TRACE();
    }
}

void DLL_ALIGN ffmpeg_kit_set_log_callback"""
new_source = """#ifdef FFMPEG_KIT_TEST_HOOKS
void DLL_ALIGN ffmpeg_kit_test_emit_unattributed_log(const char *message) {
    try {
        av_log(nullptr, AV_LOG_INFO, "%s\\n", message ? message : "");
    } catch (const std::exception &e) {
        std::cerr << "[" << getCurrentTimeStamp()
                  << "] [ffmpeg-kit] [Exception] in ffmpeg_kit_test_emit_unattributed_log: "
                  << e.what() << std::endl;
        PRINT_STACK_TRACE();
    }
}
#endif

void DLL_ALIGN ffmpeg_kit_set_log_callback"""
if h.count(old_header) != 1:
    raise SystemExit(f"expected one header declaration, found {h.count(old_header)}")
if s.count(old_source) != 1:
    raise SystemExit(f"expected one source definition block, found {s.count(old_source)}")
header.write_text(h.replace(old_header, new_header))
source.write_text(s.replace(old_source, new_source))
