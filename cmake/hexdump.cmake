execute_process(
    COMMAND hexdump -v -e "1/1 \"%02x\\r\\n\""  "${INPUT}"
    OUTPUT_FILE "${OUTPUT}"
    COMMAND_ERROR_IS_FATAL ANY
)
