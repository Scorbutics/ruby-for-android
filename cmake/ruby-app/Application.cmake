# Application.cmake
# Ruby-specific configuration bridge
# Maps generic platform variables to Ruby-specific variables

# Map DISABLE_INSTALL_DOC to RUBY_DISABLE_INSTALL_DOC
if(DEFINED DISABLE_INSTALL_DOC)
    set(RUBY_DISABLE_INSTALL_DOC ${DISABLE_INSTALL_DOC})
else()
    set(RUBY_DISABLE_INSTALL_DOC OFF)  # Default to installing docs
endif()

message(STATUS "Ruby build configuration:")
message(STATUS "  RUBY_DISABLE_INSTALL_DOC: ${RUBY_DISABLE_INSTALL_DOC}")
