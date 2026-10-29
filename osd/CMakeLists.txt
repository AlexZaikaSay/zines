# OSD firmware: C program for the secondary 6502 that drives the on-screen
# display (game/save picker, save menu, FAT access to the SD card).
# Built with cc65; the output is a raw binary image for the OSD CPU's ROM.
find_program(CL65_EXECUTABLE cl65 REQUIRED)

set(OSD_SOURCE_DIR ${CMAKE_CURRENT_SOURCE_DIR}/src)
set(OSD_INCLUDE_DIR ${CMAKE_CURRENT_SOURCE_DIR}/inc)
# Petit FatFs (ChaN), unmodified; its config pffconf.h and disk I/O live in src/
set(PFF_DIR ${CMAKE_CURRENT_SOURCE_DIR}/lib/pff)
file(GLOB_RECURSE OSD_SOURCES CONFIGURE_DEPENDS
    ${OSD_SOURCE_DIR}/*.c
    ${OSD_SOURCE_DIR}/*.s
    ${PFF_DIR}/*.c
)

set(LINKER_SCRIPT ${CMAKE_CURRENT_SOURCE_DIR}/osd.cfg)
set(OSD_BIN ${CMAKE_CURRENT_BINARY_DIR}/osd.bin)
set(OSD_MAP ${CMAKE_CURRENT_BINARY_DIR}/osd.map)
set(OSD_LST ${CMAKE_CURRENT_BINARY_DIR}/osd.lst)
set(OSD_LABELS ${CMAKE_CURRENT_BINARY_DIR}/osd.lbl)
set(OSD_DA65_INFO ${CMAKE_CURRENT_BINARY_DIR}/osd.da65)
set(OSD_TV ${CMAKE_CURRENT_BINARY_DIR}/osd.tv)
set(OSD_TV_DATA ${CMAKE_BINARY_DIR}/data/osd.tv)

# memio_regs.h: register addresses and codes generated from the RTL package,
# so the firmware always matches the hardware
find_package(Python3 REQUIRED COMPONENTS Interpreter)
set(OSD_GEN_DIR ${CMAKE_CURRENT_BINARY_DIR}/gen)
set(MEMIO_REGS_H ${OSD_GEN_DIR}/memio_regs.h)
set(ZINES_PKG ${CMAKE_SOURCE_DIR}/rtl/common/zines_pkg.sv)
set(GEN_MEMIO_REGS ${CMAKE_SOURCE_DIR}/tools/gen_memio_regs.py)
add_custom_command(OUTPUT ${MEMIO_REGS_H}
    COMMAND ${CMAKE_COMMAND} -E make_directory ${OSD_GEN_DIR}
    COMMAND ${Python3_EXECUTABLE} ${GEN_MEMIO_REGS} ${ZINES_PKG} ${MEMIO_REGS_H}
    DEPENDS ${ZINES_PKG} ${GEN_MEMIO_REGS}
    COMMENT "Generating memio_regs.h from zines_pkg.sv"
    VERBATIM)

foreach(SRC ${OSD_SOURCES})
    file(RELATIVE_PATH REL ${CMAKE_CURRENT_SOURCE_DIR} ${SRC})
    set(OBJ ${CMAKE_CURRENT_BINARY_DIR}/obj/${REL}.o)
    set(DEP ${CMAKE_CURRENT_BINARY_DIR}/obj/${REL}.d)

    add_custom_command(OUTPUT ${OBJ}
        COMMAND ${CL65_EXECUTABLE} -t none -O -c
            -I ${OSD_INCLUDE_DIR}
            -I ${PFF_DIR}
            -I ${OSD_GEN_DIR}
            --create-dep ${DEP}
            -o ${OBJ}
            ${SRC}
        DEPENDS ${SRC} ${MEMIO_REGS_H}
        DEPFILE ${DEP}
        COMMENT "Compiling OSD ${REL}"
        VERBATIM)

    list(APPEND OSD_OBJECTS ${OBJ})
endforeach()

add_custom_command(OUTPUT ${OSD_BIN}
    COMMAND ${CL65_EXECUTABLE} -t none
        -C ${LINKER_SCRIPT}
        -m ${OSD_MAP}
        -Ln ${OSD_LABELS}
        -o ${OSD_BIN}
        ${OSD_OBJECTS}
    BYPRODUCTS ${OSD_MAP} ${OSD_LABELS}
    DEPENDS ${OSD_OBJECTS} ${LINKER_SCRIPT}
    COMMENT "Linking OSD firmware osd.bin"
    VERBATIM)

add_custom_command(OUTPUT ${OSD_TV}
    COMMAND ${CMAKE_COMMAND} -DINPUT=${OSD_BIN} -DOUTPUT=${OSD_TV}
            -P ${CMAKE_SOURCE_DIR}/cmake/hexdump.cmake
    DEPENDS ${OSD_BIN})

# Testbenches load the OSD ROM image from build/data
add_custom_command(OUTPUT ${OSD_TV_DATA}
    COMMAND ${CMAKE_COMMAND} -E make_directory ${CMAKE_BINARY_DIR}/data
    COMMAND ${CMAKE_COMMAND} -E copy_if_different ${OSD_TV} ${OSD_TV_DATA}
    DEPENDS ${OSD_TV}
    COMMENT "Copying osd.tv to data/"
    VERBATIM)

# Whole-program listing with final addresses: disassemble the ROM image
# with da65, using the linker's labels and segment layout.
find_program(DA65_EXECUTABLE da65 REQUIRED)
add_custom_command(OUTPUT ${OSD_LST}
    COMMAND ${CMAKE_COMMAND} -DLABELS=${OSD_LABELS} -DMAP=${OSD_MAP}
            -DOUTPUT=${OSD_DA65_INFO} -DSTART=8000 -DEND=FFFF
            -P ${CMAKE_SOURCE_DIR}/cmake/da65_info.cmake
    COMMAND ${DA65_EXECUTABLE} -i ${OSD_DA65_INFO} -o ${OSD_LST} ${OSD_BIN}
    BYPRODUCTS ${OSD_DA65_INFO}
    DEPENDS ${OSD_BIN} ${CMAKE_SOURCE_DIR}/cmake/da65_info.cmake
    COMMENT "Disassembling osd.bin to osd.lst"
    VERBATIM)

add_custom_target(osd ALL DEPENDS ${OSD_BIN} ${OSD_TV_DATA} ${OSD_LST})
