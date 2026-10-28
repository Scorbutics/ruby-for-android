# Checks that the built Ruby loads the bytecode of Pokemon Studio's other
# platforms (patches/ruby/<minor>/load-foreign-bytecode.patch): every fixture
# of its minor must disassemble exactly like a native compile of the sample,
# and the other minors must be refused. Needs a miniruby that runs on the host
# (native Linux and macOS builds):
#   cmake -DMINIRUBY=<build>/ruby/build_dir/<arch>/ruby-<version>/miniruby \
#         -P cmake/ruby-app/tests/check_foreign_bytecode.cmake
# How the fixtures were made: foreign_bytecode/README.md.

if(NOT MINIRUBY OR NOT EXISTS "${MINIRUBY}")
    message(FATAL_ERROR "Pass -DMINIRUBY=<path to the built miniruby> (got '${MINIRUBY}')")
endif()
get_filename_component(MINIRUBY "${MINIRUBY}" ABSOLUTE)

set(_dir "${CMAKE_CURRENT_LIST_DIR}/foreign_bytecode")
file(GLOB _fixtures "${_dir}/fixtures/*.yarb")
list(SORT _fixtures)

# Run from a scratch dir: check.rb writes the disasm of a failing fixture there.
if(NOT WORK_DIR)
    set(WORK_DIR "${CMAKE_BINARY_DIR}/foreign-bytecode-check")
endif()
file(MAKE_DIRECTORY "${WORK_DIR}")

execute_process(
    COMMAND "${MINIRUBY}" -W0 "${_dir}/check.rb" "${_dir}/sample.rb" ${_fixtures}
    WORKING_DIRECTORY "${WORK_DIR}"
    RESULT_VARIABLE _result)
if(NOT _result EQUAL 0)
    message(FATAL_ERROR "Foreign bytecode check failed (disasm of failures in ${WORK_DIR})")
endif()
message(STATUS "Foreign bytecode loads as native")
