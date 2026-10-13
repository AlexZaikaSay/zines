
cmake_minimum_required(VERSION 3.20)

project(zines LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

find_program(VERILATOR_EXECUTABLE verilator REQUIRED)

add_subdirectory(src)
add_subdirectory(tests)
add_subdirectory(testbenches)
add_subdirectory(emulator)
