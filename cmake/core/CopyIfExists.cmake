# CopyIfExists.cmake
# Usage: cmake -P CopyIfExists.cmake <source> <destination>
# Copies source to destination only if source exists.

set(SRC "${CMAKE_ARGV3}")
set(DST "${CMAKE_ARGV4}")

if(EXISTS "${SRC}")
    file(COPY "${SRC}" DESTINATION "${DST}")
endif()
