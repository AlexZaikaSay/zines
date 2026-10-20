# Builds a test SD card image: one MBR partition (FAT32, starts at 1 MiB)
# with folders test1/ and test2/; test1/ holds a ROM and four save slots.
# Invoked with -DOUT=<image> -DROM=<nes file> -DWORK=<tmp dir>
#   -DSFDISK=... -DMFORMAT=... -DMMD=... -DMCOPY=... -DDD=...
set(ENV{MTOOLS_SKIP_CHECK} 1)
set(IMG "${OUT}@@1M")

function(run)
    execute_process(COMMAND ${ARGN} RESULT_VARIABLE rc)
    if(NOT rc EQUAL 0)
        message(FATAL_ERROR "Command failed (${rc}): ${ARGN}")
    endif()
endfunction()

file(REMOVE_RECURSE ${WORK})
file(MAKE_DIRECTORY ${WORK})
file(REMOVE ${OUT})

# 64 MB blank image (FAT32 needs at least ~33 MB)
run(${DD} if=/dev/zero of=${OUT} bs=1048576 count=64)

file(WRITE ${WORK}/layout.sfdisk "label: dos\nstart=2048, type=c, bootable\n")
execute_process(COMMAND ${SFDISK} -q ${OUT}
    INPUT_FILE ${WORK}/layout.sfdisk RESULT_VARIABLE rc)
if(NOT rc EQUAL 0)
    message(FATAL_ERROR "sfdisk failed (${rc})")
endif()

run(${MFORMAT} -i ${IMG} -F -v SDCARD ::)
run(${MMD} -i ${IMG} ::/test1 ::/test2)

# 10-byte zero-filled save slots
set(SAVES)
foreach(i 0 1 2 3)
    run(${DD} if=/dev/zero of=${WORK}/test1.sv${i} bs=10 count=1)
    list(APPEND SAVES ${WORK}/test1.sv${i})
endforeach()
file(COPY_FILE ${ROM} ${WORK}/test1.nes)

run(${MCOPY} -i ${IMG} ${WORK}/test1.nes ${SAVES} ::/test1/)
