cmake_minimum_required(VERSION 3.20)
project(PrezefrenVirtualAudio VERSION 1.1.0 LANGUAGES CXX)

# Set C++17 standard (required for libASPL)
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Find required frameworks
find_library(COREAUDIO_FRAMEWORK CoreAudio)
find_library(FOUNDATION_FRAMEWORK Foundation)
find_library(COREFOUNDATION_FRAMEWORK CoreFoundation)

if(NOT COREAUDIO_FRAMEWORK OR NOT FOUNDATION_FRAMEWORK OR NOT COREFOUNDATION_FRAMEWORK)
    message(FATAL_ERROR "Required frameworks not found")
endif()

# Download and include libASPL
include(FetchContent)
FetchContent_Declare(
    libASPL
    GIT_REPOSITORY https://github.com/gavv/libASPL.git
    GIT_TAG main
)
FetchContent_MakeAvailable(libASPL)

# Create the virtual audio device plugin
add_library(PrezefrenVirtualAudio SHARED
    Source/PrezefrenVirtualDevice.cpp
    Source/PrezefrenDriver.cpp
    Source/AudioSplitter.cpp
    Source/VirtualAudioIntegration.cpp
    Source/SwiftBridge.cpp
)

# Set bundle properties for macOS plugin
set_target_properties(PrezefrenVirtualAudio PROPERTIES
    BUNDLE TRUE
    BUNDLE_EXTENSION "plugin"
    MACOSX_BUNDLE_INFO_PLIST ${CMAKE_CURRENT_SOURCE_DIR}/Info.plist.in
    MACOSX_BUNDLE_BUNDLE_NAME "Prezefren Virtual Audio"
    MACOSX_BUNDLE_BUNDLE_VERSION ${PROJECT_VERSION}
    MACOSX_BUNDLE_SHORT_VERSION_STRING ${PROJECT_VERSION}
    MACOSX_BUNDLE_IDENTIFIER "com.prezefren.virtualaudio"
)

# Link frameworks and libASPL
target_link_libraries(PrezefrenVirtualAudio
    ${COREAUDIO_FRAMEWORK}
    ${FOUNDATION_FRAMEWORK}
    ${COREFOUNDATION_FRAMEWORK}
    aspl
)

# Include directories
target_include_directories(PrezefrenVirtualAudio PRIVATE
    Headers
    ${libASPL_SOURCE_DIR}/include
)

# Compiler flags for macOS audio development
target_compile_options(PrezefrenVirtualAudio PRIVATE
    -Wall
    -Wextra
    -Wno-unused-parameter
    -fno-rtti
    -fno-exceptions
)

# Installation
install(TARGETS PrezefrenVirtualAudio
    BUNDLE DESTINATION "/Library/Audio/Plug-Ins/HAL"
)

# Custom target for easy installation
add_custom_target(install_plugin
    COMMAND ${CMAKE_COMMAND} --build . --target install
    COMMENT "Installing Prezefren Virtual Audio Plugin"
)