set(TESTBENCH_DIR ${CMAKE_CURRENT_SOURCE_DIR})

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

foreach(TB_FILE ${TESTBENCHS})
    get_filename_component(TB_NAME ${TB_FILE} NAME_WE)
    string(REGEX REPLACE "^tb_" "" TEST_NAME ${TB_NAME})

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
            ${TB_FILE}
        DEPENDS
            ${RTL_SOURCES}
            ${TB_FILE}
            ${TESTVECTORS}
        COMMENT "Compiling ${TB_NAME}"
    )

    add_custom_target(sim_${TB_NAME}
        DEPENDS ${OUTPUT_FILE}
        COMMAND ${CMAKE_COMMAND} -E chdir ${CMAKE_BINARY_DIR}
            ${VVP_EXECUTABLE} ${OUTPUT_FILE}
        COMMENT "Running ${TB_NAME}"
    )
    add_dependencies(sim_${TB_NAME} copy_testvectors)

    if(TARGET ${TEST_NAME})
        # The test target produces the generated memory image consumed by the
        # testbench at runtime (for example, tests/001_cld.tv).
        add_dependencies(sim_${TB_NAME} ${TEST_NAME})
    endif()

    add_dependencies(sim_all sim_${TB_NAME})
endforeach()

set_property(DIRECTORY APPEND PROPERTY
    ADDITIONAL_CLEAN_FILES "${GENERATED_FILES};${COPIED_TESTVECTORS}"
)