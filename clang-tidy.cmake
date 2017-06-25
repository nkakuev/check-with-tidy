cmake_minimum_required(VERSION 3.0)

find_program(CLANG_TIDY NAMES clang-tidy clang-tidy-4.0)
if (NOT CLANG_TIDY)
    message(WARNING "Cannot find clang-tidy!")
else()
    message("-- Path to clang-tidy: ${CLANG_TIDY}")
endif()

macro(check_with_clang_tidy)
    # There is no reason to check Release builds:
    if (CLANG_TIDY AND CMAKE_BUILD_TYPE STREQUAL "Debug")
        set(ARGUMENT_LIST ${ARGN})
        list(GET ARGUMENT_LIST 0 TARGET_NAME)
        list(REMOVE_AT ARGUMENT_LIST 0)

        # Process default checks:
        if (NOT TIDY_CHECKS)
            set(DEFAULT_CHECKS "-*,clang-analyzer-*,-clang-analyzer-alpha*")
            message("-- Note: \${TIDY_CHECKS} is empty for ${TARGET_NAME}. "
                    "Using default checks: ${DEFAULT_CHECKS}")
            set(TIDY_CHECKS ${DEFAULT_CHECKS})
        endif()

        # Process 'warnings-as-errors' checks:
        if (NOT TIDY_ERROR_CHECKS)
            set(DEFAULT_ERROR_CHECKS "*")
            message(
                "-- Note: \${TIDY_ERROR_CHECKS} is empty for ${TARGET_NAME}. "
                "Treating these warnings as errors: ${DEFAULT_ERROR_CHECKS}")
            set(TIDY_ERROR_CHECKS ${DEFAULT_ERROR_CHECKS})
        endif()

        # The patch adding `-suppress-checks-filter` option is still in the
        # review: https://reviews.llvm.org/D26418
        # Abusing `-line-filter` as a temporary solution to suppress diagnostics
        # from files:
        if (NOT TIDY_LINE_FILTER)
            set(TIDY_LINE_FILTER "[]")
        endif()

        # Native integration via CXX_CLANG_TIDY doesn't work properly prior to
        # CMake 3.8: https://gitlab.kitware.com/cmake/cmake/issues/16435
        if (NOT CMAKE_VERSION VERSION_LESS "3.8")
            message("New clang-tidy detected!")
        else()
            # Fallback implementation. For each source file:
            #   1) Add a custom command that depends on a ${SOURCE_FILE}, runs
            #      ${CLANG_TIDY} on it, and saves the output to ${OUTPUT_FILE}
            #   2) Add a custom target ${TARGET_NAME} that depends on the
            #      ${OUTPUT_FILE} created in the first step
            #   3) Add ${TARGET_NAME} as a dependency for ${PROJECT_NAME}
            foreach (SOURCE_FILE IN LISTS ARGUMENT_LIST)
                # Build complete invokation command:
                set(TIDY_INVOKE_COMMAND
                    ${CLANG_TIDY}
                    -checks=${TIDY_CHECKS}
                    -warnings-as-errors=${TIDY_ERROR_CHECKS}
                    -line-filter=${TIDY_LINE_FILTER}
                    -p ${CMAKE_CURRENT_BINARY_DIR}
                    ${SOURCE_FILE})

                # Replace slashes in ${SOURCE_FILE}, so it can be used
                # as a target name:
                string(REPLACE "/" "" CUSTOM_TARGET_NAME ${SOURCE_FILE})

                # Prepend ${TARGET_NAME} to allow different targets use
                # idenatically named files:
                set(CUSTOM_TARGET_NAME "${TARGET_NAME}_${CUSTOM_TARGET_NAME}")

                # Create a directory for output files:
                set(OUTPUT_DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}/.tidy_temp")
                file(MAKE_DIRECTORY ${OUTPUT_DIRECTORY})
                set(OUTPUT_FILE "${OUTPUT_DIRECTORY}/${CUSTOM_TARGET_NAME}")

                add_custom_command(
                    OUTPUT ${OUTPUT_FILE}
                    COMMAND bash ${CMAKE_SOURCE_DIR}/build_scripts/tee_and_return_code.sh
                        ${OUTPUT_FILE}
                        ${TIDY_INVOKE_COMMAND}
                    DEPENDS ${CMAKE_CURRENT_SOURCE_DIR}/${SOURCE_FILE}
                    WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
                    COMMENT Running clang-tidy on ${TARGET_NAME}
                    VERBATIM)

                add_custom_target(${CUSTOM_TARGET_NAME} ALL DEPENDS ${OUTPUT_FILE})
                add_dependencies(${TARGET_NAME} ${CUSTOM_TARGET_NAME})
            endforeach()
        endif()
    endif()
endmacro()

