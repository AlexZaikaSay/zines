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

add_custom_target(copy_testvectors ALL DEPENDS ${COPIED_TESTVECTORS})

# `ninja` only builds the testbenches; `ninja test` (CTest) runs them all.
# The sim_* targets below run a single testbench or a group on demand.
add_custom_target(sim_all
    COMMENT "Running all testbenches"
)

add_custom_target(sim_cartridge
    COMMENT "Running cartridge testbenches"
)

add_custom_target(sim_ppu
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

foreach(TB_FILE ${TESTBENCHS})

    get_filename_component(TB_NAME ${TB_FILE} NAME_WE)
    string(REGEX REPLACE "^tb_" "" TEST_NAME ${TB_NAME})
    # Inside foreach(TB_FILE ${TESTBENCHS}), after TB_NAME is set.


    set(OBJ_DIR "${CMAKE_BINARY_DIR}/obj_${TB_NAME}")
    set(SIM_EXE "${OBJ_DIR}/V${TB_NAME}")

    set(VERILATOR_FLAGS
        --binary
        --x-assign fast --x-initial fast
        -O3
        -CFLAGS "-O3 -g -march=native"
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

        # Verilator links -lz twice for FST (its own flags + verilated.mk);
        # Apple's ld warns about it, so silence that harmless warning.
        if(APPLE)
            list(APPEND VERILATOR_FLAGS -LDFLAGS -Wl,-no_warn_duplicate_libraries)
        endif()
    endif()

    add_custom_command(

        OUTPUT "${SIM_EXE}"
        COMMAND ${VERILATOR_COMMAND}
            ${VERILATOR_FLAGS}
            ${RTL_SOURCES}
            ${TB_FILE}
        WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}"
        DEPENDS
            ${RTL_SOURCES}
            ${TB_FILE}
            ${TESTVECTORS}
            ${TEST_ASSETS}
        COMMENT "Building ${TB_NAME} with Verilator"
        VERBATIM
    )

    set(TB_RUN_COMMAND ${CMAKE_COMMAND}
        -DTB_NAME=${TB_NAME}
        -DSIM_EXE=${SIM_EXE}
        -DWORK_DIR=${CMAKE_BINARY_DIR}
        -DRESULT_DIR=${TB_RESULT_DIR}
        -P ${CMAKE_SOURCE_DIR}/cmake/run_tb.cmake)

    add_custom_target(build_${TB_NAME} ALL DEPENDS "${SIM_EXE}")

    if(TARGET ${TEST_NAME})
        # The test target produces the generated memory image consumed by the
        # testbench at runtime (for example, tests/001_cld.tv).
        add_dependencies(build_${TB_NAME} ${TEST_NAME})
    endif()

    add_custom_target(sim_${TB_NAME}
        COMMAND ${TB_RUN_COMMAND}
        DEPENDS build_${TB_NAME} copy_testvectors
        USES_TERMINAL
        VERBATIM
    )

    add_test(NAME ${TB_NAME} COMMAND ${TB_RUN_COMMAND})

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