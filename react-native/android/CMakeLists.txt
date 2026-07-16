cmake_minimum_required(VERSION 3.13)
project(FFmpegKitExtended)

set(CMAKE_VERBOSE_MAKEFILE ON)

add_library(
  react_native_ffmpeg_kit_extended
  STATIC
  ../cpp/FFmpegKitExtendedImpl.cpp
  ../cpp/FFmpegKitDynamicApi.cpp
)

set_target_properties(
  react_native_ffmpeg_kit_extended PROPERTIES
  CXX_STANDARD 20
  CXX_STANDARD_REQUIRED ON
  CXX_EXTENSIONS OFF
)

target_include_directories(
  react_native_ffmpeg_kit_extended
  PUBLIC
  ../cpp
)

target_link_libraries(
  react_native_ffmpeg_kit_extended
  jsi
  reactnative
  react_codegen_FFmpegKitExtendedSpec
  dl
)
