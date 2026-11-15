find_program(CA65_EXECUTABLE ca65 REQUIRED)
find_program(LD65_EXECUTABLE ld65 REQUIRED)

file(GLOB ASM_SOURCES CONFIGURE_DEPENDS
    "${CMAKE_CURRENT_SOURCE_DIR}/asm/*.ca65"
)

foreach(SRC ${ASM_SOURCES})
    get_filename_component(NAME ${SRC} NAME_WE)
    # 1xx: supervisor (OSD CPU) programs, 32K ROM image at $8000; others: 64K RAM image
    if(NAME MATCHES "^1[0-9][0-9]_")
        set(LINKER_SCRIPT ${CMAKE_CURRENT_SOURCE_DIR}/asm/osd_rom.cfg)
    else()
        set(LINKER_SCRIPT ${CMAKE_CURRENT_SOURCE_DIR}/asm/6502.cfg)
    endif()

    set(OBJ ${CMAKE_CURRENT_BINARY_DIR}/${NAME}.o)
    set(LST ${CMAKE_CURRENT_BINARY_DIR}/${NAME}.lst)
    set(BIN ${CMAKE_CURRENT_BINARY_DIR}/${NAME}.bin)
    set(MAP ${CMAKE_CURRENT_BINARY_DIR}/${NAME}.map)
    set(TV ${CMAKE_CURRENT_BINARY_DIR}/${NAME}.tv)
    

    add_custom_command(OUTPUT ${OBJ}
        COMMAND ${CA65_EXECUTABLE} -o ${OBJ} -l ${LST} ${SRC}
        BYPRODUCTS ${LST}
        DEPENDS ${SRC})

    add_custom_command(OUTPUT ${BIN}
        COMMAND ${LD65_EXECUTABLE} -C ${LINKER_SCRIPT}
                -m ${MAP} -o ${BIN} ${OBJ}
        BYPRODUCTS ${MAP}
        DEPENDS ${OBJ} ${LINKER_SCRIPT})

    add_custom_command(OUTPUT ${TV}
        COMMAND ${CMAKE_COMMAND} -DINPUT=${BIN} -DOUTPUT=${TV}
                -P ${CMAKE_SOURCE_DIR}/cmake/hexdump.cmake
        DEPENDS ${BIN})

    add_custom_target(${NAME} ALL DEPENDS ${TV})
endforeach()
