execute_process(
    COMMAND hexdump -v -e "4/4 \"%08x\\r\\n\""  "${INPUT}"
    OUTPUT_FILE "${OUTPUT}"
    COMMAND_ERROR_IS_FATAL ANY
)
