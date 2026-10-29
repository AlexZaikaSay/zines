
cmake_minimum_required(VERSION 3.20)

project(zines LANGUAGES CXX)

# `ninja test` runs every testbench through CTest
enable_testing()

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

find_program(VERILATOR_EXECUTABLE verilator REQUIRED)

set(ZINES_TRACE ON)

# MSYS2 ships verilator as a Perl script, which cmd.exe (used by Ninja) cannot run directly
if(WIN32)
    find_program(PERL_EXECUTABLE perl REQUIRED)
    set(VERILATOR_COMMAND ${PERL_EXECUTABLE} ${VERILATOR_EXECUTABLE})
else()
    set(VERILATOR_COMMAND ${VERILATOR_EXECUTABLE})
endif()

add_subdirectory(src)
add_subdirectory(tests)
add_subdirectory(testbenches)
add_subdirectory(emulator)
add_subdirectory(osd)
