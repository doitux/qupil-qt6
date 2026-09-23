# Generate Qupil build metadata at build time.
# This script intentionally runs on every build so the timestamp identifies
# the actual binary instead of the CMake configure step.

if(NOT DEFINED QUPIL_SOURCE_DIR OR QUPIL_SOURCE_DIR STREQUAL "")
    message(FATAL_ERROR "QUPIL_SOURCE_DIR is required")
endif()
if(NOT DEFINED QUPIL_OUTPUT_FILE OR QUPIL_OUTPUT_FILE STREQUAL "")
    message(FATAL_ERROR "QUPIL_OUTPUT_FILE is required")
endif()

get_filename_component(_output_dir "${QUPIL_OUTPUT_FILE}" DIRECTORY)
file(MAKE_DIRECTORY "${_output_dir}")

set(_commit "unknown")
find_program(_git_executable NAMES git)
if(_git_executable)
    execute_process(
        COMMAND "${_git_executable}" -C "${QUPIL_SOURCE_DIR}" rev-parse --is-inside-work-tree
        RESULT_VARIABLE _git_tree_result
        OUTPUT_VARIABLE _git_tree_output
        ERROR_QUIET
        OUTPUT_STRIP_TRAILING_WHITESPACE
    )
    if(_git_tree_result EQUAL 0 AND _git_tree_output STREQUAL "true")
        execute_process(
            COMMAND "${_git_executable}" -C "${QUPIL_SOURCE_DIR}" rev-parse --short=7 HEAD
            RESULT_VARIABLE _git_commit_result
            OUTPUT_VARIABLE _git_commit_output
            ERROR_QUIET
            OUTPUT_STRIP_TRAILING_WHITESPACE
        )
        if(_git_commit_result EQUAL 0 AND NOT _git_commit_output STREQUAL "")
            set(_commit "${_git_commit_output}")

            # Only tracked changes are relevant. Untracked helper files do not
            # affect an already configured build. PROJECT-STATE.md is a handoff
            # document and is intentionally excluded from the binary identity.
            execute_process(
                COMMAND "${_git_executable}" -C "${QUPIL_SOURCE_DIR}" status --porcelain --untracked-files=no -- . ":(exclude)PROJECT-STATE.md"
                RESULT_VARIABLE _git_status_result
                OUTPUT_VARIABLE _git_status_output
                ERROR_QUIET
                OUTPUT_STRIP_TRAILING_WHITESPACE
            )
            if(_git_status_result EQUAL 0 AND NOT _git_status_output STREQUAL "")
                string(APPEND _commit "-dirty")
            endif()
        endif()
    endif()
endif()

# GitHub/GitLab-style CI environments can still provide the source revision
# when the source tree itself no longer contains .git metadata.
if(_commit STREQUAL "unknown")
    foreach(_sha_env GITHUB_SHA CI_COMMIT_SHA SOURCE_VERSION)
        if(DEFINED ENV{${_sha_env}} AND NOT "$ENV{${_sha_env}}" STREQUAL "")
            set(_sha "$ENV{${_sha_env}}")
            string(LENGTH "${_sha}" _sha_length)
            if(_sha_length GREATER 7)
                string(SUBSTRING "${_sha}" 0 7 _commit)
            else()
                set(_commit "${_sha}")
            endif()
            break()
        endif()
    endforeach()
endif()

string(TIMESTAMP _timestamp "%Y-%m-%dT%H:%M:%SZ" UTC)

set(_content "#pragma once\n\n#define QUPIL_BUILD_COMMIT \"${_commit}\"\n#define QUPIL_BUILD_TIMESTAMP \"${_timestamp}\"\n")
set(_temporary "${QUPIL_OUTPUT_FILE}.tmp")
file(WRITE "${_temporary}" "${_content}")
execute_process(
    COMMAND "${CMAKE_COMMAND}" -E copy_if_different "${_temporary}" "${QUPIL_OUTPUT_FILE}"
    RESULT_VARIABLE _copy_result
)
file(REMOVE "${_temporary}")
if(NOT _copy_result EQUAL 0)
    message(FATAL_ERROR "Could not write Qupil build metadata: ${QUPIL_OUTPUT_FILE}")
endif()

message(STATUS "Qupil build identity: ${_commit} ${_timestamp}")
