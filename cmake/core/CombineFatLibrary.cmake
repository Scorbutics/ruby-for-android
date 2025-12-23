# CombineFatLibrary.cmake
# Utility function to combine multiple static libraries into a single "fat" static library

function(combine_fat_library)
    # Set policy to handle empty list elements properly
    cmake_policy(SET CMP0007 NEW)
    
    cmake_parse_arguments(
        ARG
        ""
        "OUTPUT;WORKDIR"
        "LIBS"
        ${ARGN}
    )

    if(NOT ARG_OUTPUT)
        message(FATAL_ERROR "combine_fat_library: OUTPUT parameter is required")
    endif()

    if(NOT ARG_LIBS)
        message(FATAL_ERROR "combine_fat_library: LIBS parameter is required")
    endif()

    if(NOT ARG_WORKDIR)
        set(ARG_WORKDIR "${CMAKE_CURRENT_BINARY_DIR}/fat_library_workdir")
    endif()

    # Clean and create work directory
    file(REMOVE_RECURSE "${ARG_WORKDIR}")
    file(MAKE_DIRECTORY "${ARG_WORKDIR}")

    message(STATUS "Creating fat library: ${ARG_OUTPUT}")
    message(STATUS "Work directory: ${ARG_WORKDIR}")

    # Extract all .o files from each library
    set(lib_index 0)
    foreach(lib ${ARG_LIBS})
        string(STRIP "${lib}" lib)

        get_filename_component(lib_name "${lib}" NAME)
        
        if(EXISTS "${lib}")
            # Get library name for subdirectory
            get_filename_component(lib_name_we "${lib}" NAME_WE)

            # Create unique subdirectory for this library to avoid .o file name collisions
            set(lib_subdir "${ARG_WORKDIR}/${lib_index}_${lib_name_we}")
            file(MAKE_DIRECTORY "${lib_subdir}")

            message(STATUS "Extracting: ${lib}")
            
            # First, get the list of all members (including duplicates)
            execute_process(
                COMMAND ${CMAKE_AR} t ${lib}
                OUTPUT_VARIABLE ar_members
                RESULT_VARIABLE result
                ERROR_VARIABLE error
            )
            if(result AND NOT result EQUAL 0)
                message(FATAL_ERROR "Failed to list archive ${lib}: ${error}")
            endif()
            
            # Convert output to list and clean up
            string(REGEX REPLACE "\n" ";" member_list "${ar_members}")
            list(FILTER member_list EXCLUDE REGEX "^$")
            
            # Check for duplicates
            set(member_list_unique ${member_list})
            list(REMOVE_DUPLICATES member_list_unique)
            list(LENGTH member_list total_members)
            list(LENGTH member_list_unique unique_members)
            
            if(total_members EQUAL unique_members)
                # No duplicates - use fast extraction
                execute_process(
                    COMMAND ${CMAKE_AR} x ${lib}
                    WORKING_DIRECTORY ${lib_subdir}
                    RESULT_VARIABLE result
                    ERROR_VARIABLE error
                )
                if(result AND NOT result EQUAL 0)
                    message(FATAL_ERROR "Failed to extract ${lib}: ${error}")
                endif()
                
                # Rename all extracted files to ensure uniqueness across libraries
                file(GLOB extracted_objs "${lib_subdir}/*.o")
                foreach(obj_file ${extracted_objs})
                    get_filename_component(obj_name "${obj_file}" NAME)
                    file(RENAME "${obj_file}" "${lib_subdir}/${lib_index}_${obj_name}")
                endforeach()
                
                set(extracted_count ${unique_members})
            else()
                # Has duplicates - extract by creating temporary archives and removing members
                message(STATUS "  Archive has duplicates (${total_members} members, ${unique_members} unique) - extracting all via archive manipulation")
                
                # Copy archive to temp location
                set(temp_archive "${lib_subdir}/temp_archive.a")
                file(COPY ${lib} DESTINATION ${lib_subdir})
                get_filename_component(lib_name_only "${lib}" NAME)
                file(RENAME "${lib_subdir}/${lib_name_only}" "${temp_archive}")
                
                # Extract members in reverse order (so we get earlier occurrences first)
                list(REVERSE member_list)
                
                set(member_index ${total_members})
                set(extracted_count 0)
                foreach(member ${member_list})
                    # Extract this member (gets last occurrence in current archive state)
                    execute_process(
                        COMMAND ${CMAKE_AR} x ${temp_archive} ${member}
                        WORKING_DIRECTORY ${lib_subdir}
                        RESULT_VARIABLE result
                        OUTPUT_QUIET ERROR_QUIET
                    )
                    
                    if(EXISTS "${lib_subdir}/${member}")
                        # Rename with unique index
                        file(RENAME "${lib_subdir}/${member}" "${lib_subdir}/${lib_index}_${member_index}_${member}")
                        math(EXPR extracted_count "${extracted_count} + 1")
                        
                        # Remove this member from the temp archive
                        execute_process(
                            COMMAND ${CMAKE_AR} d ${temp_archive} ${member}
                            RESULT_VARIABLE result
                            OUTPUT_QUIET ERROR_QUIET
                        )
                    endif()
                    
                    math(EXPR member_index "${member_index} - 1")
                endforeach()
                
                # Clean up temp archive
                file(REMOVE ${temp_archive})
                
                message(STATUS "  Extracted ${extracted_count} object files from ${lib_name}")
            endif()
            
            message(STATUS "  Extracted ${extracted_count} object files from ${lib_name}")

            math(EXPR lib_index "${lib_index} + 1")
        else()
            message(WARNING "Library not found (skipping): ${lib}")
        endif()
    endforeach()

    # Combine all .o files from all subdirectories into fat library
    # Get all subdirectories
    file(GLOB lib_subdirs RELATIVE "${ARG_WORKDIR}" "${ARG_WORKDIR}/*")

    set(all_obj_files "")
    foreach(subdir ${lib_subdirs})
        file(GLOB obj_files_in_subdir "${ARG_WORKDIR}/${subdir}/*.o")
        list(APPEND all_obj_files ${obj_files_in_subdir})
    endforeach()

    list(LENGTH all_obj_files obj_count)
    message(STATUS "Combining ${obj_count} object files into fat library...")

    if(obj_count EQUAL 0)
        message(FATAL_ERROR "No object files found to combine!")
    endif()

    # Delete output file if it exists
    file(REMOVE "${ARG_OUTPUT}")

    # Check for duplicate symbols and filter object files
    message(STATUS "Checking for duplicate symbols...")
    set(defined_symbols "")
    set(filtered_obj_files "")
    set(skipped_count 0)
    
    foreach(obj_file ${all_obj_files})
        # Get defined symbols from this object file
        # Only check strong symbols (T, D, B, R) - skip weak symbols (V, W)
        execute_process(
            COMMAND ${CMAKE_NM} -g ${obj_file}
            OUTPUT_VARIABLE nm_output
            ERROR_QUIET
            OUTPUT_STRIP_TRAILING_WHITESPACE
        )
        
        # Extract only STRONG defined symbols (T = text/code, D = initialized data, B = BSS, R = read-only data)
        # Skip weak symbols (V, W) and common symbols (C) which can have multiple definitions
        string(REGEX MATCHALL "[0-9a-fA-F]+ [TDBR] [^\n]+" defined_lines "${nm_output}")
        
        set(has_duplicate FALSE)
        set(duplicate_symbols "")
        foreach(line ${defined_lines})
            # Extract symbol name (third field)
            string(REGEX REPLACE "^[0-9a-fA-F]+ [TDBR] (.+)$" "\\1" symbol "${line}")
            
            # Skip C++ type info and vtable symbols - these are often duplicated and handled by linker
            if(symbol MATCHES "^_ZT[ISV]" OR symbol MATCHES "^_ZN.*C[12]E" OR symbol MATCHES "^_ZN.*D[012]E")
                continue()
            endif()
            
            # Check if this symbol is already defined
            list(FIND defined_symbols "${symbol}" symbol_index)
            if(NOT symbol_index EQUAL -1)
                set(has_duplicate TRUE)
                list(APPEND duplicate_symbols "${symbol}")
            endif()
        endforeach()
        
        if(has_duplicate)
            # Skip this object file
            get_filename_component(obj_name "${obj_file}" NAME)
            message(STATUS "  Skipping ${obj_name} (duplicate symbols: ${duplicate_symbols})")
            math(EXPR skipped_count "${skipped_count} + 1")
        else()
            # Add this object file and record its symbols
            list(APPEND filtered_obj_files "${obj_file}")
            foreach(line ${defined_lines})
                string(REGEX REPLACE "^[0-9a-fA-F]+ [TDBR] (.+)$" "\\1" symbol "${line}")
                # Only track non-typeinfo symbols
                if(NOT (symbol MATCHES "^_ZT[ISV]" OR symbol MATCHES "^_ZN.*C[12]E" OR symbol MATCHES "^_ZN.*D[012]E"))
                    list(APPEND defined_symbols "${symbol}")
                endif()
            endforeach()
        endif()
    endforeach()
    
    message(STATUS "Skipped ${skipped_count} object files with duplicate symbols")
    list(LENGTH filtered_obj_files final_obj_count)
    message(STATUS "Adding ${final_obj_count} object files to fat library...")

    # Add object files in batches to avoid command line length limits
    set(batch_size 100)
    set(batch_files "")
    set(batch_count 0)
    set(total_batches 0)

    foreach(obj_file ${filtered_obj_files})
        list(APPEND batch_files "${obj_file}")
        math(EXPR batch_count "${batch_count} + 1")
        
        if(batch_count EQUAL batch_size)
            math(EXPR total_batches "${total_batches} + 1")
            message(STATUS "Writing batch ${total_batches} (${batch_size} object files)...")
            execute_process(
                COMMAND ${CMAKE_AR} r ${ARG_OUTPUT} ${batch_files}
                RESULT_VARIABLE result
            )
            if(result)
                message(FATAL_ERROR "Failed to add objects to fat library")
            endif()
            set(batch_files "")
            set(batch_count 0)
        endif()
    endforeach()

    # Add remaining files
    if(batch_count GREATER 0)
        math(EXPR total_batches "${total_batches} + 1")
        message(STATUS "Writing final batch ${total_batches} (${batch_count} object files)...")
        execute_process(
            COMMAND ${CMAKE_AR} r ${ARG_OUTPUT} ${batch_files}
            RESULT_VARIABLE result
        )
        if(result)
            message(FATAL_ERROR "Failed to add remaining objects to fat library")
        endif()
    endif()

    # Run ranlib to update the index
    message(STATUS "Running ranlib on fat library...")
    execute_process(
        COMMAND ${CMAKE_RANLIB} ${ARG_OUTPUT}
        RESULT_VARIABLE result
    )
    if(result)
        message(FATAL_ERROR "Failed to run ranlib on fat library")
    endif()

    message(STATUS "Fat library created successfully: ${ARG_OUTPUT}")
endfunction()
