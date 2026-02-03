# The Flutter tooling requires that developers have CMake 3.10 or later
# installed.
cmake_minimum_required(VERSION 3.10)

# Project-level configuration.
set(PROJECT_NAME "ffmpeg_kit_flutter")
project(${PROJECT_NAME} LANGUAGES CXX)

string(APPEND CMAKE_C_FLAGS " -Wl,--gc-sections")

# 1. Setup PkgConfig correctly so PkgConfig::GTK exists
find_package(PkgConfig REQUIRED)
pkg_check_modules(GTK REQUIRED IMPORTED_TARGET gtk+-3.0)

# This value is used when generating builds using this plugin, so it must
# not be changed.
set(PLUGIN_NAME "ffmpeg_kit_flutter_plugin")

# Any new source files that you add to the plugin should be added here.
list(APPEND PLUGIN_SOURCES
  "ffmpeg_kit_flutter_plugin.cc"
)

# Define the plugin library target.
add_library(${PLUGIN_NAME} SHARED
  ${PLUGIN_SOURCES}
)

# Symbols are hidden by default to reduce the chance of accidental conflicts
set_target_properties(${PLUGIN_NAME} PROPERTIES
  CXX_VISIBILITY_PRESET hidden)
target_compile_definitions(${PLUGIN_NAME} PRIVATE FLUTTER_PLUGIN_IMPL)

# ==============================================================================
# FFmpegKit Configuration Logic
# ==============================================================================

# 1. Initialize variables
set(FFMPEG_KIT_PATH "")
set(FFMPEG_KIT_URL "")

# 2. OPTIONAL: Include the generated config file from the Dart script
# We look in the App's linux directory (${CMAKE_SOURCE_DIR})
set(GENERATED_CONFIG "${CMAKE_SOURCE_DIR}/config.cmake")
if(EXISTS "${GENERATED_CONFIG}")
    message(STATUS "FFmpegKit: Including generated configuration from ${GENERATED_CONFIG}")
    include("${GENERATED_CONFIG}")
endif()

# 3. A. Check for User-Defined Variables (passed via cache or the include above)
if(DEFINED FFMPEG_KIT_Config_Path)
    message(STATUS "FFmpegKit: Custom path detected: ${FFMPEG_KIT_Config_Path}")
    set(FFMPEG_KIT_PATH "${FFMPEG_KIT_Config_Path}")
elseif(DEFINED FFMPEG_KIT_Config_Url)
    message(STATUS "FFmpegKit: Custom URL detected: ${FFMPEG_KIT_Config_Url}")
    set(FFMPEG_KIT_URL "${FFMPEG_KIT_Config_Url}")
endif()

# B. Handle URL Download (if URL provided and Path not set)
if(FFMPEG_KIT_URL AND NOT FFMPEG_KIT_PATH)
    set(DOWNLOAD_DIR "${CMAKE_CURRENT_BINARY_DIR}/ffmpeg_kit_download")
    set(EXTRACT_DIR "${CMAKE_CURRENT_BINARY_DIR}/ffmpeg_kit_extracted")
    set(ARCHIVE_FILE "${DOWNLOAD_DIR}/ffmpeg_kit_archive.tar.gz")

    if(NOT EXISTS "${EXTRACT_DIR}")
        message(STATUS "FFmpegKit: Downloading from ${FFMPEG_KIT_URL}...")
        file(MAKE_DIRECTORY "${DOWNLOAD_DIR}")
        file(MAKE_DIRECTORY "${EXTRACT_DIR}")
        
        file(DOWNLOAD "${FFMPEG_KIT_URL}" "${ARCHIVE_FILE}" SHOW_PROGRESS STATUS DOWNLOAD_STATUS)
        list(GET DOWNLOAD_STATUS 0 STATUS_CODE)
        if(NOT STATUS_CODE EQUAL 0)
            message(FATAL_ERROR "FFmpegKit: Download failed.")
        endif()

        message(STATUS "FFmpegKit: Extracting archive...")
        execute_process(
            COMMAND ${CMAKE_COMMAND} -E tar xzf "${ARCHIVE_FILE}"
            WORKING_DIRECTORY "${EXTRACT_DIR}"
            RESULT_VARIABLE EXTRACT_RESULT
        )
        if(NOT EXTRACT_RESULT EQUAL 0)
            message(FATAL_ERROR "FFmpegKit: Extraction failed.")
        endif()
    endif()

    # Find the library folder inside extraction
    # We look for the folder that contains 'lib' directory
    file(GLOB_RECURSE FOUND_LIB "${EXTRACT_DIR}/libffmpegkit.so")
    if(NOT FOUND_LIB)
        file(GLOB_RECURSE FOUND_LIB "${EXTRACT_DIR}/libffmpegkit.a")
    endif()
    
    if(FOUND_LIB)
        get_filename_component(LIB_DIR "${FOUND_LIB}" DIRECTORY) # gets /lib
        get_filename_component(FFMPEG_KIT_PATH "${LIB_DIR}/.." ABSOLUTE) # gets parent
    else
        # Fallback assumption: Root of extraction
        set(FFMPEG_KIT_PATH "${EXTRACT_DIR}")
    endif()
endif()

# C. Fallback to Default Bundled Version (Local Development)
if(NOT FFMPEG_KIT_PATH)
    # Search in ../../prebuilt/linux-x86_64/bundle-*-linux-x86_64-*
    file(GLOB DEFAULT_BUNDLES "${CMAKE_CURRENT_SOURCE_DIR}/../../prebuilt/linux-x86_64/bundle-*-linux-x86_64-*")
    
    # Sort to get the most recent or consistent one if multiple exist
    list(SORT DEFAULT_BUNDLES)
    list(REVERSE DEFAULT_BUNDLES) # Pick last (usually highest version or alphanumeric)
    list(GET DEFAULT_BUNDLES 0 DETECTED_BUNDLE)
    
    if(DETECTED_BUNDLE)
        set(FFMPEG_KIT_PATH "${DETECTED_BUNDLE}")
        message(STATUS "FFmpegKit: Using default local bundle: ${FFMPEG_KIT_PATH}")
    else
        message(WARNING "FFmpegKit: No bundle found in prebuilt/. Please run runner.sh or provide configuration.")
    endif()
endif()

# ==============================================================================
# Linking
# ==============================================================================

# 1. Include Headers
target_include_directories(${PLUGIN_NAME} PRIVATE
  "${CMAKE_CURRENT_SOURCE_DIR}/include"
  "${FFMPEG_KIT_PATH}/include"
)

# 2. Find and Link FFmpegKit Library
find_library(FFMPEG_LIB_FILE 
    NAMES ffmpegkit ffmpegkit_full 
    HINTS "${FFMPEG_KIT_PATH}/lib"
    NO_DEFAULT_PATH
)

if(NOT FFMPEG_LIB_FILE)
    message(FATAL_ERROR "FFmpegKit Library not found in ${FFMPEG_KIT_PATH}/lib. Please ensure the bundle exists.")
endif()

# 3. Link Libraries (Plugin + FFmpeg + System Deps)
target_link_libraries(${PLUGIN_NAME} PRIVATE flutter)
target_link_libraries(${PLUGIN_NAME} PRIVATE PkgConfig::GTK)
target_link_libraries(${PLUGIN_NAME} PRIVATE ${FFMPEG_LIB_FILE})

# Link system libraries required by FFmpeg static builds
# Note: If your bundle uses specific SSL libs, add -lssl -lcrypto here
target_link_libraries(${PLUGIN_NAME} PRIVATE 
    "-lz" 
    "-lm" 
    "-ldl" 
    "-lpthread"
)

# ==============================================================================
# Bundling and Scope Fix
# ==============================================================================

# 2. Fix: Wrap PARENT_SCOPE to prevent warning when building standalone
if(NOT CMAKE_CURRENT_SOURCE_DIR STREQUAL CMAKE_SOURCE_DIR)
    set(ffmpeg_kit_flutter_bundled_libraries
      "${FFMPEG_LIB_FILE}"
      PARENT_SCOPE
    )
endif()

# === Tests ===
if (${include_${PROJECT_NAME}_tests})
  if(${CMAKE_VERSION} VERSION_LESS "3.11.0")
    message("Unit tests require CMake 3.11.0 or later")
  else()
    set(TEST_RUNNER "${PROJECT_NAME}_test")
    enable_testing()

    include(FetchContent)
    FetchContent_Declare(
      googletest
      URL https://github.com/google/googletest/archive/release-1.11.0.zip
    )
    set(gtest_force_shared_crt ON CACHE BOOL "" FORCE)
    set(INSTALL_GTEST OFF CACHE BOOL "Disable installation of googletest" FORCE)

    FetchContent_MakeAvailable(googletest)

    add_executable(${TEST_RUNNER}
      test/ffmpeg_kit_flutter_plugin_test.cc
      ${PLUGIN_SOURCES}
    )
    
    target_include_directories(${TEST_RUNNER} PRIVATE "${CMAKE_CURRENT_SOURCE_DIR}")
    target_include_directories(${TEST_RUNNER} PRIVATE "${FFMPEG_KIT_PATH}/include")
    
    target_link_libraries(${TEST_RUNNER} PRIVATE flutter)
    target_link_libraries(${TEST_RUNNER} PRIVATE PkgConfig::GTK)
    target_link_libraries(${TEST_RUNNER} PRIVATE gtest_main gmock)
    target_link_libraries(${TEST_RUNNER} PRIVATE ${FFMPEG_LIB_FILE} "-lz" "-lm" "-ldl" "-lpthread")

    include(GoogleTest)
    gtest_discover_tests(${TEST_RUNNER})
  endif()
endif()