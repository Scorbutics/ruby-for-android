# Application.cmake
# Ruby-specific configuration bridge
# Maps generic platform variables to Ruby-specific variables

# Map ENABLE_SHARED to RUBY_ENABLE_SHARED
if(DEFINED ENABLE_SHARED)
    set(RUBY_ENABLE_SHARED ${ENABLE_SHARED})
else()
    set(RUBY_ENABLE_SHARED ON)  # Default to shared if not specified
endif()

# Map DISABLE_INSTALL_DOC to RUBY_DISABLE_INSTALL_DOC
if(DEFINED DISABLE_INSTALL_DOC)
    set(RUBY_DISABLE_INSTALL_DOC ${DISABLE_INSTALL_DOC})
else()
    set(RUBY_DISABLE_INSTALL_DOC OFF)  # Default to installing docs
endif()

message(STATUS "Ruby build configuration:")
message(STATUS "  RUBY_ENABLE_SHARED: ${RUBY_ENABLE_SHARED}")
message(STATUS "  RUBY_DISABLE_INSTALL_DOC: ${RUBY_DISABLE_INSTALL_DOC}")
