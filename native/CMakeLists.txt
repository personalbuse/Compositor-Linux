cmake_minimum_required(VERSION 3.16)
project(compositor_core LANGUAGES C)

set(CMAKE_C_STANDARD 99)
set(CMAKE_C_STANDARD_REQUIRED ON)

if(CMAKE_BUILD_TYPE STREQUAL "Release")
  set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -O2")
endif()

if(UNIX AND NOT APPLE)
  find_library(M_LIB m)
  set(EXTRA_LIBS ${M_LIB})
endif()

include_directories(${CMAKE_CURRENT_SOURCE_DIR}/include)

set(SOURCES
  src/AdjustPixels.c
  src/BrushPixels.c
  src/ContentFill.c
  src/HealPixels.c
  src/LensPixels.c
  src/LevelsPixels.c
  src/NoisePixels.c
  src/WandPixels.c
  src/compositor.c
  src/resample.c
  src/surface.c
  src/blend.c
)

add_library(compositor_core SHARED ${SOURCES})

target_link_libraries(compositor_core ${EXTRA_LIBS})

set_target_properties(compositor_core PROPERTIES
  OUTPUT_NAME "compositor_core"
  VERSION 1.0.0
  SOVERSION 1
)

install(TARGETS compositor_core
  LIBRARY DESTINATION lib
  RUNTIME DESTINATION bin
)