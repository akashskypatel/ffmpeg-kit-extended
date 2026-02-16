# The Flutter tooling requires that developers have a version of Visual Studio
# installed that includes CMake 3.14 or later. You should not increase this
# version, as doing so will cause the plugin to fail to compile for some
# customers of the plugin.
cmake_policy(VERSION 3.14...3.25)

# Project-level configuration.
set(PROJECT_NAME "ffmpeg_kit_extended_flutter")
project(${PROJECT_NAME} LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Export compile_commands.json for Clangd
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)
set(CMAKE_EXPORT_COMPILE_COMMANDS_DEBUG ON)
set(CMAKE_EXPORT_COMPILE_COMMANDS_RELEASE ON)

# Run configure.dart to ensure binaries are present
# We pass the App's root explicitly
function(run_configure)
  # Detect App Root: CMAKE_SOURCE_DIR is <App>/windows, so parent is <App>
  get_filename_component(APP_ROOT "${CMAKE_SOURCE_DIR}/.." ABSOLUTE)

  message(STATUS "FFmpegKit: Configuring for Windows (App Root: ${APP_ROOT})...")

  execute_process(
      COMMAND dart run ffmpeg_kit_extended_flutter:configure "windows" "--app-root=${APP_ROOT}" "--verbose"
      WORKING_DIRECTORY "${APP_ROOT}"
      RESULT_VARIABLE configure_result
      OUTPUT_VARIABLE configure_output
      ERROR_VARIABLE configure_error
  )

  if(NOT configure_result EQUAL 0)
      message(WARNING "FFmpegKit: configure.dart failed (exit ${configure_result}).")
      message(WARNING "Output: ${configure_output}")
      message(WARNING "Error: ${configure_error}")
      message(FATAL_ERROR "FFmpegKit: Failed to configure binaries. Please check your pubspec.yaml configuration.")
  else()
      # Parse FFMPEG_KIT_PATH from output
      string(REGEX MATCH "FFMPEG_KIT_PATH=([^\r\n]+)" MATCHED "${configure_output}")
      if(MATCHED)
          set(FFMPEG_KIT_PATH_FOUND ${CMAKE_MATCH_1})
          string(STRIP "${FFMPEG_KIT_PATH_FOUND}" FFMPEG_KIT_PATH_FOUND)
          
          # Export to parent scope
          set(FFMPEG_KIT_PATH "${FFMPEG_KIT_PATH_FOUND}" PARENT_SCOPE)
          message(STATUS "FFmpegKit: Configured at ${FFMPEG_KIT_PATH_FOUND}")
      else()
          message(WARNING "FFmpegKit: configure.dart did not output path.")
          message(WARNING "Output: ${configure_output}")
      endif()
  endif()
endfunction()

run_configure()

if(NOT DEFINED FFMPEG_KIT_PATH)
    message(FATAL_ERROR "FFmpegKit: library path not set.")
endif()

function(find_ffmpeg_kit)
  # Find and Link FFmpegKit Library (Linker)
  find_library(FFMPEG_LIB_FILE 
      NAMES libffmpegkit libffmpegkit.dll libffmpegkit.dll.a
      HINTS "${FFMPEG_KIT_PATH}/lib" "${FFMPEG_KIT_PATH}/bin" "${FFMPEG_KIT_PATH}"
      NO_DEFAULT_PATH
  )
  set(FFMPEG_LIB_FILE ${FFMPEG_LIB_FILE} PARENT_SCOPE)
endfunction()
message(STATUS "FFMPEG_KIT_PATH: ${FFMPEG_KIT_PATH}")

# This value is used when generating builds using this plugin, so it must
# not be changed
set(PLUGIN_NAME "ffmpeg_kit_extended_flutter_plugin")

# Any new source files that you add to the plugin should be added here.
list(APPEND PLUGIN_SOURCES
  "ffmpeg_kit_flutter_plugin.cpp"
)

# Define the plugin library target. Its name must not be changed (see comment
# on PLUGIN_NAME above).
add_library(${PLUGIN_NAME} SHARED
  "include/ffmpeg_kit_extended_flutter/ffmpeg_kit_flutter_plugin.h"
  "ffmpeg_kit_flutter_plugin_c_api.cpp"
  ${PLUGIN_SOURCES}
)

# Apply a standard set of build settings that are configured in the
# application-level CMakeLists.txt. This can be removed for plugins that want
# full control over build settings.
apply_standard_settings(${PLUGIN_NAME})

# Symbols are hidden by default to reduce the chance of accidental conflicts
# between plugins. This should not be removed; any symbols that should be
# exported should be explicitly exported with the FLUTTER_PLUGIN_EXPORT macro.
set_target_properties(${PLUGIN_NAME} PROPERTIES
  CXX_VISIBILITY_PRESET hidden)
target_compile_definitions(${PLUGIN_NAME} PRIVATE FLUTTER_PLUGIN_IMPL)

find_ffmpeg_kit()

if(NOT FFMPEG_LIB_FILE)
    message(WARNING "FFmpegKit: Library not found. Trying re-configure.")
    run_configure()
    find_ffmpeg_kit()
    if(NOT FFMPEG_LIB_FILE)
        message(FATAL_ERROR "FFmpegKit Library not found in ${FFMPEG_KIT_PATH}/lib. Please ensure the bundle exists.")
    endif()
endif()

target_link_libraries(${PLUGIN_NAME} PRIVATE ${FFMPEG_LIB_FILE})

# Source include directories and library dependencies. Add any plugin-specific
# dependencies here.
target_include_directories(${PLUGIN_NAME} PUBLIC
  "${CMAKE_CURRENT_SOURCE_DIR}/include"
)
target_include_directories(${PLUGIN_NAME} PRIVATE
  "${FFMPEG_KIT_PATH}/include"
)

# Link system libraries required by FFmpeg static builds (Windows specific)
target_link_libraries(${PLUGIN_NAME} PRIVATE 
    bcrypt
)

target_link_libraries(${PLUGIN_NAME} PRIVATE flutter flutter_wrapper_plugin)

# List of absolute paths to libraries that should be bundled with the plugin.
# This list could contain prebuilt libraries, or libraries created by an
# external build triggered from this build file.
# For Windows, we need the runtime DLL which is usually in bin/
find_file(FFMPEG_KIT_LIB_FILE
    NAMES libffmpegkit.dll libffmpegkit.a
    HINTS "${FFMPEG_KIT_PATH}/bin" "${FFMPEG_KIT_PATH}/lib"
    NO_DEFAULT_PATH
)

if (FFMPEG_KIT_LIB_FILE)
    set(${PROJECT_NAME}_bundled_libraries
      "${FFMPEG_KIT_LIB_FILE}"
      PARENT_SCOPE
    )
else()
     message(WARNING "FFmpegKit DLL not found in ${FFMPEG_KIT_PATH}/bin. Runtime might fail.")
     set(${PROJECT_NAME}_bundled_libraries
       ""
       PARENT_SCOPE
     )
endif()

# === Tests ===
# These unit tests can be run from a terminal after building the example, or
# from Visual Studio after opening the generated solution file.

# Only enable test builds when building the example (which sets this variable)
# so that plugin clients aren't building the tests.
if (${include_${PROJECT_NAME}_tests})
  set(TEST_RUNNER "${PROJECT_NAME}_test")
  enable_testing()

  # Add the Google Test dependency.
  include(FetchContent)
  FetchContent_Declare(
    googletest
    URL https://github.com/google/googletest/archive/refs/tags/v1.14.0.zip
  )
  # Prevent overriding the parent project's compiler/linker settings
  set(gtest_force_shared_crt ON CACHE BOOL "" FORCE)
  # Disable install commands for gtest so it doesn't end up in the bundle.
  set(INSTALL_GTEST OFF CACHE BOOL "Disable installation of googletest" FORCE)
  FetchContent_MakeAvailable(googletest)

  # The plugin's C API is not very useful for unit testing, so build the sources
  # directly into the test binary rather than using the DLL.
  add_executable(${TEST_RUNNER}
    test/ffmpeg_kit_flutter_plugin_test.cpp
    ${PLUGIN_SOURCES}
  )
  apply_standard_settings(${TEST_RUNNER})
  target_include_directories(${TEST_RUNNER} PRIVATE "${CMAKE_CURRENT_SOURCE_DIR}" "${FFMPEG_KIT_PATH}/include")
  target_link_libraries(${TEST_RUNNER} PRIVATE flutter_wrapper_plugin)
  target_link_libraries(${TEST_RUNNER} PRIVATE gtest_main gmock)
  target_link_libraries(${TEST_RUNNER} PRIVATE ${FFMPEG_LIB_FILE})

  # Copy libffmpegkit.dll to the test runner directory
  add_custom_command(TARGET ${TEST_RUNNER} POST_BUILD
    COMMAND ${CMAKE_COMMAND} -E copy_if_different
    "${FFMPEG_KIT_LIB_FILE}"
    "$<TARGET_FILE_DIR:${TEST_RUNNER}>"
    VERBATIM)
  # flutter_wrapper_plugin has link dependencies on the Flutter DLL.
  add_custom_command(TARGET ${TEST_RUNNER} POST_BUILD
    COMMAND ${CMAKE_COMMAND} -E copy_if_different
    "${FLUTTER_LIBRARY}" $<TARGET_FILE_DIR:${TEST_RUNNER}>
  )

  # Enable automatic test discovery.
  include(GoogleTest)
  gtest_discover_tests(${TEST_RUNNER})
endif()
