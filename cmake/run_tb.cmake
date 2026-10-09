# Runs one testbench, prints a PASS/FAIL line and records the result.
#
# Inputs: TB_NAME, SIM_EXE, [SIM_ARG], WORK_DIR, RESULT_DIR

string(ASCII 27 ESC)
if(DEFINED ENV{NO_COLOR})
    set(GREEN "")
    set(RED "")
    set(DIM "")
    set(RST "")
else()
    set(GREEN "${ESC}[32m")
    set(RED "${ESC}[31m")
    set(DIM "${ESC}[2m")
    set(RST "${ESC}[0m")
endif()

file(MAKE_DIRECTORY "${RESULT_DIR}")
set(STATUS_FILE "${RESULT_DIR}/${TB_NAME}.status")
set(LOG_FILE "${RESULT_DIR}/${TB_NAME}.log")
file(REMOVE "${STATUS_FILE}")

string(TIMESTAMP START "%s")
execute_process(
    COMMAND ${SIM_EXE} ${SIM_ARG}
    WORKING_DIRECTORY "${WORK_DIR}"
    OUTPUT_VARIABLE OUT
    ERROR_VARIABLE ERR
    RESULT_VARIABLE RC
)
string(TIMESTAMP END "%s")
math(EXPR ELAPSED "${END} - ${START}")

set(ALL_OUT "${OUT}${ERR}")
file(WRITE "${LOG_FILE}" "${ALL_OUT}")

# $error in Verilator prints "%Error", in Icarus "ERROR:"; neither
# guarantees a non-zero exit code, so scan the output too.
string(REPLACE "\n" ";" LINES "${ALL_OUT}")
set(FAIL_LINES "")
foreach(LINE IN LISTS LINES)
    if(LINE MATCHES "TEST FAILED|%Error|^ERROR:|Assertion failed|%Fatal|FATAL")
        list(APPEND FAIL_LINES "${LINE}")
    endif()
endforeach()

if(RC EQUAL 0 AND NOT FAIL_LINES)
    set(RESULT PASS)
    message("${GREEN}[ PASS ]${RST} ${TB_NAME} ${DIM}(${ELAPSED}s)${RST}")
else()
    set(RESULT FAIL)
    message("${RED}[ FAIL ]${RST} ${TB_NAME} ${DIM}(${ELAPSED}s, exit ${RC})${RST}")
    list(LENGTH FAIL_LINES N_FAIL)
    if(N_FAIL GREATER 10)
        list(SUBLIST FAIL_LINES 0 10 FAIL_LINES)
    endif()
    foreach(LINE IN LISTS FAIL_LINES)
        message("         ${RED}${LINE}${RST}")
    endforeach()
    message("         ${DIM}log: ${LOG_FILE}${RST}")
endif()

file(WRITE "${STATUS_FILE}" "${RESULT}\n")

if(RESULT STREQUAL "FAIL")
    message(FATAL_ERROR "")
endif()
