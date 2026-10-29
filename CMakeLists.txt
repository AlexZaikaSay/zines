
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

# RTL and simulation sources are listed in filelists/*.f. Every Verilator
# build gets all of them; --top-module keeps only what the top uses.
# Paths inside the .f files are relative to the repo root, so Verilator
# must run with WORKING_DIRECTORY ${CMAKE_SOURCE_DIR}.
set(FILELIST_DIR ${CMAKE_SOURCE_DIR}/filelists)
# Synthesizable code only; these are also what fpga/*.qsf list
set(RTL_FILELISTS
    common
    cpu6502
    nes_core
    cart
    storage
    display
    input
    audio
)
set(FILELISTS ${RTL_FILELISTS} sim_models sim_boards)

set(FILELIST_FLAGS -Wno-MULTITOP)
set(RTL_SOURCES)
foreach(FILELIST ${FILELISTS})
    set(FILELIST_FILE ${FILELIST_DIR}/${FILELIST}.f)
    list(APPEND FILELIST_FLAGS -f ${FILELIST_FILE})
    # Rebuild when a filelist or any file it names changes
    set_property(DIRECTORY APPEND PROPERTY CMAKE_CONFIGURE_DEPENDS ${FILELIST_FILE})
    file(STRINGS ${FILELIST_FILE} FILELIST_LINES REGEX "^[^/]")
    foreach(LINE ${FILELIST_LINES})
        list(APPEND RTL_SOURCES ${CMAKE_SOURCE_DIR}/${LINE})
    endforeach()
    list(APPEND RTL_SOURCES ${FILELIST_FILE})
endforeach()

# RTL lint: every synthesizable top must be clean under -Wall. Unlike the
# testbench builds, warnings are fatal here. `ninja test` runs one lint_<top>
# test per top; `ninja lint` runs them all and shows the warnings.
set(RTL_FILELIST_FLAGS -Wno-MULTITOP)
foreach(FILELIST ${RTL_FILELISTS})
    list(APPEND RTL_FILELIST_FLAGS -f ${FILELIST_DIR}/${FILELIST}.f)
endforeach()
set(RTL_LINT_TOPS
    nes
    cartridge
    disk
    sd_loader
    mos6502
    nes_vga
    vga
    hdmi_tx
    charmap
    nes_audio_sampler
    nes_pad_poller
    nes_pad_port
)
add_custom_target(lint COMMENT "Linting RTL")
foreach(TOP ${RTL_LINT_TOPS})
    set(LINT_COMMAND ${VERILATOR_COMMAND} --lint-only -Wall --top-module ${TOP}
        ${RTL_FILELIST_FLAGS})
    add_test(NAME lint_${TOP} COMMAND ${LINT_COMMAND}
        WORKING_DIRECTORY ${CMAKE_SOURCE_DIR})
    add_custom_target(lint_${TOP} COMMAND ${LINT_COMMAND}
        WORKING_DIRECTORY ${CMAKE_SOURCE_DIR} VERBATIM)
    add_dependencies(lint lint_${TOP})
endforeach()

add_subdirectory(tests)
add_subdirectory(tb)
add_subdirectory(sim/top)
add_subdirectory(osd)
