
cmake_minimum_required(VERSION 3.20)

project(zines LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

set(ZINES_SIMULATOR "verilator" CACHE STRING
    "HDL simulator: verilator or icarus")
set_property(CACHE ZINES_SIMULATOR PROPERTY STRINGS
    verilator icarus)

option(ZINES_TRACE "Enable waveform tracing" OFF)

if(ZINES_SIMULATOR STREQUAL "verilator")
    find_program(VERILATOR_EXECUTABLE verilator REQUIRED)
elseif(ZINES_SIMULATOR STREQUAL "icarus")
    find_program(IVERILOG_EXECUTABLE iverilog REQUIRED)
    find_program(VVP_EXECUTABLE vvp REQUIRED)
else()
    message(FATAL_ERROR
        "Unsupported ZINES_SIMULATOR=${ZINES_SIMULATOR}")
endif()

add_subdirectory(src)
add_subdirectory(tests)
add_subdirectory(testbenches)
