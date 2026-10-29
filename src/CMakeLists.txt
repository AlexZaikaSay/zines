
set(SOURCE_DIR ${CMAKE_CURRENT_SOURCE_DIR})

add_subdirectory(apu)
add_subdirectory(boards)
add_subdirectory(cartridge)
add_subdirectory(cpu)
add_subdirectory(ppu)
add_subdirectory(sd_card)
add_subdirectory(vga)

set(RTL_SOURCES  ${APU_SOURCES} ${BOARDS_SOURCES} ${CARTRIDGE_SOURCES} ${CPU_SOURCES} ${PPU_SOURCES} ${SD_CARD_SOURCES} ${VGA_SOURCES})
# Dependency list only: testbenches pull RTL in through `include, so these
# files must not be passed to Verilator again (duplicate modules)
set(RTL_SOURCES ${RTL_SOURCES} PARENT_SCOPE)

set(SOURCE_DIR ${SOURCE_DIR} PARENT_SCOPE)