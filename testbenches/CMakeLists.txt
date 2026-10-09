set(TESTBENCH_DIR ${CMAKE_CURRENT_SOURCE_DIR})
set(TEST_ASSETS
    ${CMAKE_SOURCE_DIR}/assets/SMB.nes
    ${CMAKE_SOURCE_DIR}/assets/color_test.nes
)

file(GLOB TESTBENCHS
    "${TESTBENCH_DIR}/tb_*.sv"
)

file(GLOB_RECURSE TESTVECTORS
    "${TESTBENCH_DIR}/data/*.tv"
)

foreach(TESTVECTOR ${TESTVECTORS})
    file(RELATIVE_PATH TESTVECTOR_RELATIVE_PATH
        "${TESTBENCH_DIR}"
        "${TESTVECTOR}"
    )
    get_filename_component(TESTVECTOR_NAME "${TESTVECTOR}" NAME)
    set(COPIED_TESTVECTOR
        "${CMAKE_BINARY_DIR}/tests/${TESTVECTOR_NAME}"
    )
    get_filename_component(COPIED_TESTVECTOR_DIR
        "${COPIED_TESTVECTOR}"
        DIRECTORY
    )

    add_custom_command(
        OUTPUT ${COPIED_TESTVECTOR}
        COMMAND ${CMAKE_COMMAND} -E make_directory
            ${COPIED_TESTVECTOR_DIR}
        COMMAND ${CMAKE_COMMAND} -E copy_if_different
            ${TESTVECTOR}
            ${COPIED_TESTVECTOR}
        DEPENDS ${TESTVECTOR}
        COMMENT "Copying ${TESTVECTOR_RELATIVE_PATH}"
    )

    list(APPEND COPIED_TESTVECTORS ${COPIED_TESTVECTOR})
    
endforeach()

add_custom_target(copy_testvectors DEPENDS ${COPIED_TESTVECTORS})

add_custom_target(sim_all ALL
    COMMENT "Running all testbenches"
)

add_custom_target(sim_cartridge ALL
    COMMENT "Running cartridge testbenches"
)

add_custom_target(sim_ppu ALL
    COMMENT "Running PPU testbenches"
)

add_custom_target(sim_cpu
    COMMENT "Running all CPU-related testbenches"
)

set(TB_RESULT_DIR "${CMAKE_BINARY_DIR}/tb_results")

add_custom_target(sim_summary
    COMMAND ${CMAKE_COMMAND} -DRESULT_DIR=${TB_RESULT_DIR}
        -P ${CMAKE_SOURCE_DIR}/cmake/tb_summary.cmake
    USES_TERMINAL
    COMMENT "Testbench summary"
)

# Interactive SDL display testbench: Verilator only, never part of sim_all.
set(LIVE_TB tb_201_video)

foreach(TB_FILE ${TESTBENCHS})

    get_filename_component(TB_NAME ${TB_FILE} NAME_WE)
    set(TB_EXTRA_SOURCES "")
    set(TB_LIVE FALSE)
    if(TB_NAME STREQUAL LIVE_TB)
        if(NOT ZINES_SIMULATOR STREQUAL "verilator")
            continue()
        endif()
        set(TB_LIVE TRUE)
    endif()
    string(REGEX REPLACE "^tb_" "" TEST_NAME ${TB_NAME})
    # Inside foreach(TB_FILE ${TESTBENCHS}), after TB_NAME is set.

    if(ZINES_SIMULATOR STREQUAL "verilator")
        set(OBJ_DIR "${CMAKE_BINARY_DIR}/obj_${TB_NAME}")
        set(SIM_EXE "${OBJ_DIR}/V${TB_NAME}")

        set(VERILATOR_FLAGS
            --binary
            --timing
            -O3
            -CFLAGS -O3
            --top-module ${TB_NAME}
            --Mdir ${OBJ_DIR}
            -Wall
            -Wno-fatal
            -I${SOURCE_DIR}
            -I${TESTBENCH_DIR}
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
        endif()

        if(TB_LIVE)
            find_program(SDL2_CONFIG sdl2-config REQUIRED)
            execute_process(COMMAND ${SDL2_CONFIG} --cflags
                OUTPUT_VARIABLE SDL2_CFLAGS OUTPUT_STRIP_TRAILING_WHITESPACE)
            execute_process(COMMAND ${SDL2_CONFIG} --libs
                OUTPUT_VARIABLE SDL2_LIBS OUTPUT_STRIP_TRAILING_WHITESPACE)
            set(TB_EXTRA_SOURCES ${TESTBENCH_DIR}/utils/sdl_display.cpp)
            list(APPEND VERILATOR_FLAGS
                -CFLAGS "${SDL2_CFLAGS}"
                -LDFLAGS "${SDL2_LIBS}"
            )
        endif()

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
                ${TESTVECTORS}
                ${TEST_ASSETS}
            COMMENT "Building ${TB_NAME} with Verilator"
            VERBATIM
        )

        if(TB_LIVE)
            # Interactive: run directly so output streams and no PASS/FAIL is recorded.
            set(TB_RUN_COMMAND ${CMAKE_COMMAND} -E chdir
                "${CMAKE_BINARY_DIR}" "${SIM_EXE}")
        else()
            set(TB_RUN_COMMAND ${CMAKE_COMMAND}
                -DTB_NAME=${TB_NAME}
                -DSIM_EXE=${SIM_EXE}
                -DWORK_DIR=${CMAKE_BINARY_DIR}
                -DRESULT_DIR=${TB_RESULT_DIR}
                -P ${CMAKE_SOURCE_DIR}/cmake/run_tb.cmake)
        endif()

        add_custom_target(sim_${TB_NAME}
            COMMAND ${TB_RUN_COMMAND}
            DEPENDS "${SIM_EXE}" copy_testvectors
            USES_TERMINAL
            VERBATIM
        )

    else()
        # Keep your existing Icarus compile/run commands here.


        set(OUTPUT_FILE "${CMAKE_BINARY_DIR}/${TB_NAME}.out")
        set(VCD_FILE    "${CMAKE_BINARY_DIR}/${TB_NAME}.vcd")

        list(APPEND GENERATED_FILES
            ${OUTPUT_FILE}
            ${VCD_FILE}
        )

        add_custom_command(
            OUTPUT ${OUTPUT_FILE}
            COMMAND
                ${IVERILOG_EXECUTABLE}
                -g2012
                -o ${OUTPUT_FILE}
                -I ${SOURCE_DIR}
                -I ${TESTBENCH_DIR}
                ${TB_FILE}
            DEPENDS
                ${RTL_SOURCES}
                ${SOURCE_DIR}/nes_sim.sv
                ${TESTBENCH_DIR}/utils/nes_video_capture.sv
                ${TB_FILE}
                ${TESTVECTORS}
                ${TEST_ASSETS}
            COMMENT "Compiling ${TB_NAME}"
        )

        add_custom_target(sim_${TB_NAME}
            DEPENDS ${OUTPUT_FILE}
            COMMAND ${CMAKE_COMMAND}
                -DTB_NAME=${TB_NAME}
                -DSIM_EXE=${VVP_EXECUTABLE}
                -DSIM_ARG=${OUTPUT_FILE}
                -DWORK_DIR=${CMAKE_BINARY_DIR}
                -DRESULT_DIR=${TB_RESULT_DIR}
                -P ${CMAKE_SOURCE_DIR}/cmake/run_tb.cmake
            USES_TERMINAL
        )

        add_dependencies(sim_${TB_NAME} copy_testvectors)

    endif()

    if(TARGET ${TEST_NAME})
        # The test target produces the generated memory image consumed by the
        # testbench at runtime (for example, tests/001_cld.tv).
        add_dependencies(sim_${TB_NAME} ${TEST_NAME})
    endif()

    if(TB_LIVE)
        continue()
    endif()

    add_dependencies(sim_all sim_${TB_NAME})

    if(TB_NAME MATCHES "^tb_0" OR TB_NAME MATCHES "^tb_6502")
        add_dependencies(sim_cpu sim_${TB_NAME})
    endif()
    
    if(TB_NAME MATCHES "^tb_1")
        add_dependencies(sim_cartridge sim_${TB_NAME})
    endif()

    if(TB_NAME MATCHES "^tb_2")
        add_dependencies(sim_ppu sim_${TB_NAME})
    endif()


endforeach()

set_property(DIRECTORY APPEND PROPERTY
    ADDITIONAL_CLEAN_FILES "${GENERATED_FILES};${COPIED_TESTVECTORS}"
)