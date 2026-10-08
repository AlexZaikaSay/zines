set(SOURCE_DIR ${CMAKE_CURRENT_SOURCE_DIR})

add_subdirectory(cpu)
add_subdirectory(sd_card)
add_subdirectory(cartridge)
add_subdirectory(ppu)

set(RTL_SOURCES ${CPU_SOURCES} ${SD_CARD_SOURCES} ${CARTRIDGE_SOURCES} ${PPU_SOURCES})

set(SOURCE_DIR ${SOURCE_DIR} PARENT_SCOPE)
set(RTL_SOURCES ${RTL_SOURCES} PARENT_SCOPE)
