# Builds a da65 info file from ld65 output so the disassembly gets real
# label names and treats data segments as data, not code.
#
# Inputs: LABELS (ld65 -Ln file), MAP (ld65 -m file), OUTPUT (info file),
#         START, END (hex, e.g. 8000/FFFF: image region to disassemble)

math(EXPR START "0x${START}")
math(EXPR END "0x${END}")
math(EXPR SIZE "${END} - ${START} + 1")
math(EXPR START_HEX "${START}" OUTPUT_FORMAT HEXADECIMAL)
math(EXPR SIZE_HEX "${SIZE}" OUTPUT_FORMAT HEXADECIMAL)

set(INFO "GLOBAL {\n    CPU \"6502\";\n    INPUTOFFS ${START_HEX};\n    INPUTSIZE ${SIZE_HEX};\n    STARTADDR ${START_HEX};\n    COMMENTS 4;\n};\n")

# Labels: "al 008000 ._init". Skip linker-generated __NAME__ symbols and
# keep only the first name per address (da65 allows one).
file(STRINGS "${LABELS}" LABEL_LINES)
set(SEEN "")
foreach(LINE IN LISTS LABEL_LINES)
    if(NOT LINE MATCHES "^al ([0-9A-Fa-f]+) \\.(.+)$")
        continue()
    endif()
    set(ADDR "${CMAKE_MATCH_1}")
    set(NAME "${CMAKE_MATCH_2}")
    if(NAME MATCHES "^__.*__$" OR "${ADDR}" IN_LIST SEEN)
        continue()
    endif()
    list(APPEND SEEN "${ADDR}")
    string(APPEND INFO "LABEL { NAME \"${NAME}\"; ADDR $${ADDR}; };\n")
endforeach()

# Segments from the map: "CODE  008029  0080D9  0000B1  00001".
# Code segments are disassembled, RODATA as bytes, VECTORS as addresses,
# and the gaps (fill bytes) are skipped.
file(STRINGS "${MAP}" MAP_LINES)
set(IN_SEGMENTS FALSE)
set(POS ${START})
foreach(LINE IN LISTS MAP_LINES)
    if(LINE MATCHES "^Segment list:")
        set(IN_SEGMENTS TRUE)
        continue()
    endif()
    if(NOT IN_SEGMENTS)
        continue()
    endif()
    if(LINE MATCHES "^Exports list")
        break()
    endif()
    if(NOT LINE MATCHES "^([A-Z_0-9]+) +([0-9A-F]+) +([0-9A-F]+) +([0-9A-F]+)")
        continue()
    endif()
    set(SEG "${CMAKE_MATCH_1}")
    math(EXPR SEG_START "0x${CMAKE_MATCH_2}")
    math(EXPR SEG_END "0x${CMAKE_MATCH_3}")
    if(SEG_START LESS START OR SEG_END GREATER END)
        continue()
    endif()

    if(SEG STREQUAL "RODATA")
        set(TYPE ByteTable)
    elseif(SEG STREQUAL "VECTORS")
        set(TYPE AddrTable)
    else()
        set(TYPE Code)
    endif()

    if(SEG_START GREATER POS)
        math(EXPR GAP_END "${SEG_START} - 1")
        math(EXPR A "${POS}" OUTPUT_FORMAT HEXADECIMAL)
        math(EXPR B "${GAP_END}" OUTPUT_FORMAT HEXADECIMAL)
        string(APPEND INFO "RANGE { START ${A}; END ${B}; TYPE Skip; };\n")
    endif()
    math(EXPR A "${SEG_START}" OUTPUT_FORMAT HEXADECIMAL)
    math(EXPR B "${SEG_END}" OUTPUT_FORMAT HEXADECIMAL)
    string(APPEND INFO "RANGE { START ${A}; END ${B}; TYPE ${TYPE}; };\n")
    math(EXPR POS "${SEG_END} + 1")
endforeach()

# da65 wants $-prefixed hex
string(REPLACE "0x" "$" INFO "${INFO}")
file(WRITE "${OUTPUT}" "${INFO}")
