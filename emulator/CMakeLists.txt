# Interactive SDL emulators (video + joysticks, audio).
# Verilator only; clk is driven by utils/sim_main.cpp. `ninja` builds them,
# `ninja video` / `ninja audio` runs them. Never part of `ninja test`.
set(EMULATOR_DIR ${CMAKE_CURRENT_SOURCE_DIR})
set(TESTBENCH_DIR ${CMAKE_SOURCE_DIR}/testbenches)
set(TEST_ASSETS
    ${CMAKE_SOURCE_DIR}/assets/SMB.nes
    ${CMAKE_SOURCE_DIR}/assets/color_test.nes
)
set(EMULATOR_TBS video audio osdvideo)

find_program(SDL2_CONFIG sdl2-config REQUIRED)

# On MSYS2 sdl2-config is a shell script, which Windows cannot execute directly
if(WIN32)
    find_program(SH_EXECUTABLE sh REQUIRED)
    set(SDL2_CONFIG_COMMAND ${SH_EXECUTABLE} ${SDL2_CONFIG})
else()
    set(SDL2_CONFIG_COMMAND ${SDL2_CONFIG})
endif()

execute_process(COMMAND ${SDL2_CONFIG_COMMAND} --cflags
    OUTPUT_VARIABLE SDL2_CFLAGS OUTPUT_STRIP_TRAILING_WHITESPACE
    COMMAND_ERROR_IS_FATAL ANY)
execute_process(COMMAND ${SDL2_CONFIG_COMMAND} --libs
    OUTPUT_VARIABLE SDL2_LIBS OUTPUT_STRIP_TRAILING_WHITESPACE
    COMMAND_ERROR_IS_FATAL ANY)

if(WIN32)
    # -mwindows builds a GUI-subsystem exe with no console, hiding simulator output
    string(REPLACE "-mwindows" "" SDL2_LIBS "${SDL2_LIBS}")
    # sim_main.cpp defines a plain main() without including SDL.h, so skip
    # SDL's main -> SDL_main renaming and its SDL2main entry-point wrapper
    string(REPLACE "-Dmain=SDL_main" "-DSDL_MAIN_HANDLED" SDL2_CFLAGS "${SDL2_CFLAGS}")
    string(REPLACE "-lSDL2main" "" SDL2_LIBS "${SDL2_LIBS}")
endif()

foreach(TB_NAME ${EMULATOR_TBS})
    set(TB_FILE ${EMULATOR_DIR}/${TB_NAME}.sv)
    set(OBJ_DIR "${CMAKE_BINARY_DIR}/obj_${TB_NAME}")
    set(SIM_EXE "${OBJ_DIR}/V${TB_NAME}")

    set(VERILATOR_FLAGS
        --cc --exe --build
        --x-assign fast --x-initial fast
        -O3
        -CFLAGS "-O3 -g -march=native"
        # Time comes from VerilatedContext::timeInc() in sim_main.cpp; without this
        # Verilator references a weak sc_time_stamp(), which Windows linkers reject
        -CFLAGS -DVL_TIME_CONTEXT
        --top-module ${TB_NAME}
        --Mdir ${OBJ_DIR}
        -Wall
        -Wno-fatal
        -I${SOURCE_DIR}
        -I${TESTBENCH_DIR}
        -I${EMULATOR_DIR}
        -CFLAGS "${SDL2_CFLAGS}"
        -LDFLAGS "${SDL2_LIBS}"
    )

    if(ZINES_TRACE)
        list(APPEND VERILATOR_FLAGS --trace-fst)

        # FST tracing needs lz4, which Homebrew keeps outside the
        # default compiler search paths.
        find_path(LZ4_INCLUDE_DIR lz4.h
            HINTS /opt/homebrew/include /usr/local/include)
        find_library(LZ4_LIBRARY lz4
            HINTS /opt/homebrew/lib /usr/local/lib)
        if(LZ4_INCLUDE_DIR AND LZ4_LIBRARY)
            get_filename_component(LZ4_LIB_DIR "${LZ4_LIBRARY}" DIRECTORY)
            list(APPEND VERILATOR_FLAGS
                -CFLAGS -I${LZ4_INCLUDE_DIR}
                -LDFLAGS -L${LZ4_LIB_DIR}
            )
        endif()

        # Verilator links -lz twice for FST (its own flags + verilated.mk);
        # Apple's ld warns about it, so silence that harmless warning.
        if(APPLE)
            list(APPEND VERILATOR_FLAGS -LDFLAGS -Wl,-no_warn_duplicate_libraries)
        endif()
    endif()

    configure_file(${EMULATOR_DIR}/utils/sim_main.cpp
        ${OBJ_DIR}/sim_main.cpp @ONLY)
    set(TB_EXTRA_SOURCES
        ${OBJ_DIR}/sim_main.cpp
        ${EMULATOR_DIR}/utils/sdl_display.cpp)

    add_custom_command(
        OUTPUT "${SIM_EXE}"
        COMMAND ${VERILATOR_COMMAND}
            ${VERILATOR_FLAGS}
            ${RTL_SOURCES}
            ${TB_FILE}
            ${TB_EXTRA_SOURCES}
        WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}"
        DEPENDS
            ${RTL_SOURCES}
            ${TB_FILE}
            ${TB_EXTRA_SOURCES}
            ${TEST_ASSETS}
        COMMENT "Building ${TB_NAME} with Verilator"
        VERBATIM
    )

    add_custom_target(build_${TB_NAME} ALL DEPENDS "${SIM_EXE}")

    # Interactive: run directly so output streams and no PASS/FAIL is recorded.
    add_custom_target(${TB_NAME}
        COMMAND ${CMAKE_COMMAND} -E chdir "${CMAKE_BINARY_DIR}" "${SIM_EXE}"
        DEPENDS build_${TB_NAME}
        USES_TERMINAL
        VERBATIM
    )
endforeach()

# OSD character font for charmap.sv, generated from the unscii-8 glyphs
find_package(Python3 REQUIRED COMPONENTS Interpreter)
set(FONT_SRC ${CMAKE_SOURCE_DIR}/assets/unscii-8.hex)
set(FONT_HEX ${CMAKE_BINARY_DIR}/data/font.hex)
add_custom_command(OUTPUT ${FONT_HEX}
    COMMAND ${CMAKE_COMMAND} -E make_directory ${CMAKE_BINARY_DIR}/data
    COMMAND ${Python3_EXECUTABLE} ${CMAKE_SOURCE_DIR}/toold/make_font.py
            ${FONT_SRC} ${FONT_HEX}
    DEPENDS ${FONT_SRC} ${CMAKE_SOURCE_DIR}/toold/make_font.py
    COMMENT "Generating data/font.hex"
    VERBATIM)
add_custom_target(font ALL DEPENDS ${FONT_HEX})

# Test SD card image: MBR + FAT32 with test1/{test1.nes,test1.sv0..3} and test2/
find_program(SFDISK sfdisk REQUIRED
    HINTS /opt/homebrew/opt/util-linux/sbin /usr/local/opt/util-linux/sbin)
find_program(MFORMAT mformat REQUIRED)
find_program(MMD mmd REQUIRED)
find_program(MCOPY mcopy REQUIRED)
find_program(DD dd REQUIRED)
set(SDIMG_ROM ${CMAKE_SOURCE_DIR}/assets/color_test.nes)
set(SDIMG ${CMAKE_BINARY_DIR}/data/sd.img)
set(SDIMG_SCRIPT ${CMAKE_SOURCE_DIR}/cmake/make_sdimg.cmake)
add_custom_command(OUTPUT ${SDIMG}
    COMMAND ${CMAKE_COMMAND} -E make_directory ${CMAKE_BINARY_DIR}/data
    COMMAND ${CMAKE_COMMAND}
            -DOUT=${SDIMG} -DROM=${SDIMG_ROM} -DWORK=${CMAKE_BINARY_DIR}/sdimg
            -DSFDISK=${SFDISK} -DMFORMAT=${MFORMAT} -DMMD=${MMD}
            -DMCOPY=${MCOPY} -DDD=${DD}
            -P ${SDIMG_SCRIPT}
    DEPENDS ${SDIMG_SCRIPT} ${SDIMG_ROM}
    COMMENT "Generating data/sd.img"
    VERBATIM)
add_custom_target(sdimg ALL DEPENDS ${SDIMG})

# osdvideo loads the OSD firmware image (data/osd.tv), font (data/font.hex)
# and SD card image (data/sd.img) at runtime
add_dependencies(osdvideo osd font sdimg)
