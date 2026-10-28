# check_combine_extensions.cmake
#
# Regression test for combine_ruby_extensions.cmake, on a fake Ruby build tree
# compiled with the host C compiler:
#   - two extension archives with the same name and object names (Ruby 3.2+
#     has ext/cgi/escape/escape.a and ext/erb/escape/escape.a): both objects
#     must reach libruby-ext.a, Init_cgi_escape used to be lost;
#   - psych and fiddle linking -lyaml / -lffi: the staging libyaml.a and
#     libffi.a must be folded in.
#
# Usage:
#   cmake -DWORK_DIR=/tmp/combine-check -P cmake/ruby-app/tests/check_combine_extensions.cmake

cmake_minimum_required(VERSION 3.14)

if(NOT WORK_DIR)
    message(FATAL_ERROR "check_combine_extensions.cmake: WORK_DIR is required")
endif()

get_filename_component(_ROOT "${CMAKE_CURRENT_LIST_DIR}/../../.." ABSOLUTE)
find_program(_CC NAMES cc gcc clang REQUIRED)
find_program(_AR NAMES ar REQUIRED)
find_program(_NM NAMES nm REQUIRED)

set(_BUILD "${WORK_DIR}/build")
set(_SRC "${_BUILD}/ruby-9.9.9")
set(_STAGING "${WORK_DIR}/staging")
file(REMOVE_RECURSE "${WORK_DIR}")
file(MAKE_DIRECTORY "${_SRC}/ext" "${_SRC}/enc" "${_STAGING}")

# Compile <dir>/<name>.c defining <symbol> into <dir>/<name>.o, then archive it
function(_make_archive archive obj_name symbol)
    get_filename_component(_dir "${archive}" DIRECTORY)
    file(MAKE_DIRECTORY "${_dir}/obj")
    file(WRITE "${_dir}/obj/${obj_name}.c" "void ${symbol}(void) {}\n")
    execute_process(COMMAND ${_CC} -c "${obj_name}.c" -o "${obj_name}.o"
        WORKING_DIRECTORY "${_dir}/obj" RESULT_VARIABLE _res)
    if(NOT _res EQUAL 0)
        message(FATAL_ERROR "Cannot compile ${_dir}/obj/${obj_name}.c")
    endif()
    execute_process(COMMAND ${_AR} crs "${archive}" "obj/${obj_name}.o"
        WORKING_DIRECTORY "${_dir}" RESULT_VARIABLE _res)
    if(NOT _res EQUAL 0)
        message(FATAL_ERROR "Cannot create ${archive}")
    endif()
endfunction()

function(_make_object path symbol)
    file(WRITE "${path}.c" "void ${symbol}(void) {}\n")
    execute_process(COMMAND ${_CC} -c "${path}.c" -o "${path}" RESULT_VARIABLE _res)
    if(NOT _res EQUAL 0)
        message(FATAL_ERROR "Cannot compile ${path}.c")
    endif()
endfunction()

_make_object("${_SRC}/ext/extinit.o" Init_ext)
_make_object("${_SRC}/enc/encinit.o" Init_enc)
_make_archive("${_SRC}/ext/cgi/escape/escape.a" escape Init_cgi_escape)
_make_archive("${_SRC}/ext/erb/escape/escape.a" escape Init_erb_escape)
_make_archive("${_SRC}/ext/psych/psych.a" psych Init_psych)
_make_archive("${_SRC}/ext/fiddle/fiddle.a" fiddle Init_fiddle)
_make_archive("${_STAGING}/libyaml.a" api yaml_get_version)
_make_archive("${_STAGING}/libffi.a" prep_cif ffi_prep_cif)
file(WRITE "${_SRC}/ext/psych/Makefile" "LIBS = $(LIBRUBYARG_STATIC) -lyaml  -lm   -lc\n")
file(WRITE "${_SRC}/ext/fiddle/Makefile" "LIBS = $(LIBRUBYARG_STATIC) -ldl -lffi  -lffi -lm   -lc\n")

set(_OUT "${WORK_DIR}/out/libruby-ext.a")
execute_process(
    COMMAND ${CMAKE_COMMAND}
        -DRUBY_BUILD_DIR=${_BUILD}
        -DRUBY_VERSION=9.9.9
        -DOUTPUT_LIB=${_OUT}
        -DCROSS_AR=${_AR}
        -DSTAGING_LIB_DIR=${_STAGING}
        -P "${_ROOT}/cmake/ruby-app/scripts/combine_ruby_extensions.cmake"
    RESULT_VARIABLE _res OUTPUT_VARIABLE _out ERROR_VARIABLE _out)
if(NOT _res EQUAL 0)
    message(FATAL_ERROR "combine_ruby_extensions.cmake failed:\n${_out}")
endif()

execute_process(COMMAND ${_NM} -g --defined-only "${_OUT}" OUTPUT_VARIABLE _symbols RESULT_VARIABLE _res)
if(NOT _res EQUAL 0)
    message(FATAL_ERROR "Cannot list the symbols of ${_OUT}")
endif()

set(_MISSING "")
foreach(_sym Init_ext Init_enc Init_cgi_escape Init_erb_escape Init_psych Init_fiddle yaml_get_version ffi_prep_cif)
    if(NOT _symbols MATCHES "[ \t]_?${_sym}\n")
        list(APPEND _MISSING "${_sym}")
    endif()
endforeach()
if(_MISSING)
    message(FATAL_ERROR "Symbols missing from libruby-ext.a: ${_MISSING}\n${_out}")
endif()
message(STATUS "combine_ruby_extensions.cmake keeps every extension object and folds libyaml/libffi")
