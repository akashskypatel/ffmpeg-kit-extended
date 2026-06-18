cmake_minimum_required(VERSION 3.4.1)
add_library(ffmpeg_kit_extended_dummy SHARED dummy.cpp)

# Align ELF LOAD segments to 16 KB so the library is compatible with 16 KB
# page-size Android devices (required by Google Play for apps targeting
# Android 15+). NDK r28+ does this by default; adding the flag explicitly keeps
# older NDKs (r27 and below) compliant as well.
target_link_options(ffmpeg_kit_extended_dummy PRIVATE "-Wl,-z,max-page-size=16384")