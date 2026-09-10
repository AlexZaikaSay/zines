cmake_minimum_required(VERSION 3.12)
project(RISC-V NONE)

find_program(IVERILOG_EXECUTABLE iverilog REQUIRED)
find_program(VVP_EXECUTABLE vvp REQUIRED)

add_subdirectory(src)
add_subdirectory(tests)
add_subdirectory(testbenches)
