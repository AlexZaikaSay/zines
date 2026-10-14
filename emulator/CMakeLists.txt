# Interactive SDL emulator testbenches (video, joysticks, audio).
# Verilator only; clk is driven by utils/sim_main.cpp, never part of sim_all.
set(EMULATOR_DIR ${CMAKE_CURRENT_SOURCE_DIR})
set(TESTBENCH_DIR ${CMAKE_SOURCE_DIR}/testbenches)
set(TEST_ASSETS
    ${CMAKE_SOURCE_DIR}/assets/SMB.nes
    ${CMAKE_SOURCE_DIR}/assets/color_test.nes
)
set(EMULATOR_TBS tb_200_video tb_300_audio)

find_program(SDL2_CONFIG sdl2-config REQUIRED)
execute_process(COMMAND ${SDL2_CONFIG} --cflags
    OUTPUT_VARIABLE SDL2_CFLAGS OUTPUT_STRIP_TRAILING_WHITESPACE)
execute_process(COMMAND ${SDL2_CONFIG} --libs
    OUTPUT_VARIABLE SDL2_LIBS OUTPUT_STRIP_TRAILING_WHITESPACE)

foreach(TB_NAME ${EMULATOR_TBS})
    set(TB_FILE ${EMULATOR_DIR}/${TB_NAME}.sv)
    string(REGEX REPLACE "^tb_" "" TEST_NAME ${TB_NAME})
    set(OBJ_DIR "${CMAKE_BINARY_DIR}/obj_${TB_NAME}")
    set(SIM_EXE "${OBJ_DIR}/V${TB_NAME}")

    set(VERILATOR_FLAGS
        --cc --exe --build
        --x-assign fast --x-initial fast
        -O3
        -CFLAGS "-O3 -g -march=native"
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
        COMMAND ${VERILATOR_EXECUTABLE}
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

    # Interactive: run directly so output streams and no PASS/FAIL is recorded.
    add_custom_target(sim_${TB_NAME}
        COMMAND ${CMAKE_COMMAND} -E chdir "${CMAKE_BINARY_DIR}" "${SIM_EXE}"
        DEPENDS "${SIM_EXE}"
        USES_TERMINAL
        VERBATIM
    )

    if(TARGET ${TEST_NAME})
        add_dependencies(sim_${TB_NAME} ${TEST_NAME})
    endif()
endforeach()
