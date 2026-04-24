# 
# FFmpegKit Flutter Extended Plugin - A wrapper library for FFmpeg
# Copyright (C) 2026 Akash Patel
# 
# This library is free software; you can redistribute it and/or
# modify it under the terms of the GNU Lesser General Public
# License as published by the Free Software Foundation; either
# version 2.1 of the License, or (at your option) any later version.
# 
# This library is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
# Lesser General Public License for more details.
# 
# You should have received a copy of the GNU Lesser General Public
# License along with this library; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA
# 

cmake_policy(VERSION 3.14...3.25)

project(ffmpeg_kit_extended_flutter LANGUAGES CXX)

# Export compile_commands.json for Clangd
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

# This value is used when generating builds using this plugin, so it must
# not be changed.
set(PLUGIN_NAME "ffmpeg_kit_extended_flutter_plugin")

# Any new source files that you add to the plugin should be added here.
list(APPEND PLUGIN_SOURCES
  "ffmpeg_kit_extended_flutter_plugin.cc"
)

# Setup PkgConfig correctly so PkgConfig::GTK exists
find_package(PkgConfig REQUIRED)
pkg_check_modules(GTK REQUIRED IMPORTED_TARGET gtk+-3.0)

# Define the plugin library target.
add_library(${PLUGIN_NAME} SHARED
  "include/ffmpeg_kit_extended_flutter/ffmpeg_kit_extended_flutter_plugin.h"
  ${PLUGIN_SOURCES}
)

# Symbols are hidden by default to reduce the chance of accidental conflicts
set_target_properties(${PLUGIN_NAME} PROPERTIES
  CXX_VISIBILITY_PRESET hidden)
target_compile_definitions(${PLUGIN_NAME} PRIVATE FLUTTER_PLUGIN_IMPL)

# Include Headers
target_include_directories(${PLUGIN_NAME} PUBLIC
  "${CMAKE_CURRENT_SOURCE_DIR}/include"
)

# Link Libraries
# Note: The plugin does NOT link against libffmpegkit.so at build-time.
# It declares the symbols as weak (extern "C" __attribute__((weak))) and
# expects the dynamic linker to resolve them from the process space at
# runtime.  libffmpegkit.so is bundled via hook/build.dart and CodeAssets.
target_link_libraries(${PLUGIN_NAME} PRIVATE flutter)
target_link_libraries(${PLUGIN_NAME} PRIVATE PkgConfig::GTK)

# Link system libraries required by FFmpeg static builds
target_link_libraries(${PLUGIN_NAME} PRIVATE 
    "-lz" 
    "-lm" 
    "-ldl" 
    "-lpthread"
)
