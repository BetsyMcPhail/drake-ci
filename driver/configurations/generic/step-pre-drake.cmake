set(DASHBOARD_SUPERBUILD_FAILURE OFF)

notice("CTest Status: CONFIGURING / BUILDING SUPERBUILD")

# Set up parameters for dashboard submission
begin_stage(
  URL_NAME "Superbuild"
  PROJECT_NAME "drake-superbuild"
  BUILD_NAME "${DASHBOARD_BUILD_NAME}-pre-drake")

# Set up the build and update the sources
ctest_start("${DASHBOARD_MODEL}" TRACK "${DASHBOARD_TRACK}" QUIET)
ctest_update(SOURCE "${CTEST_SOURCE_DIRECTORY}"
  RETURN_VALUE DASHBOARD_SUPERBUILD_UPDATE_RETURN_VALUE QUIET)

# Write initial cache and configure the superbuild
file(WRITE "${CTEST_BINARY_DIRECTORY}/CMakeCache.txt" "${CACHE_CONTENT}")

ctest_configure(BUILD "${CTEST_BINARY_DIRECTORY}"
  SOURCE "${CTEST_SOURCE_DIRECTORY}"
  RETURN_VALUE DASHBOARD_SUPERBUILD_CONFIGURE_RETURN_VALUE QUIET)
if(NOT DASHBOARD_SUPERBUILD_CONFIGURE_RETURN_VALUE EQUAL 0)
  append_step_status("CONFIGURE SUPERBUILD (PRE-DRAKE)" FAILURE)
endif()

# Run the build
ctest_build(BUILD "${CTEST_BINARY_DIRECTORY}" APPEND
  NUMBER_ERRORS DASHBOARD_SUPERBUILD_NUMBER_BUILD_ERRORS QUIET)
if(DASHBOARD_SUPERBUILD_NUMBER_BUILD_ERRORS GREATER 0)
  append_step_status("BUILD SUPERBUILD (PRE-DRAKE)" FAILURE)
endif()

# Upload the Jenkins job URL to add link on CDash
set(DASHBOARD_BUILD_URL_FILE
  "${CTEST_BINARY_DIRECTORY}/${DASHBOARD_BUILD_NAME}.url")
file(WRITE "${DASHBOARD_BUILD_URL_FILE}" "$ENV{BUILD_URL}")
ctest_upload(FILES "${DASHBOARD_BUILD_URL_FILE}" QUIET)

# Submit the results
ctest_submit(RETRY_COUNT 4 RETRY_DELAY 15
  RETURN_VALUE DASHBOARD_SUPERBUILD_SUBMIT_RETURN_VALUE QUIET)

set(DASHBOARD_SUPERBUILD_FAILURE ${DASHBOARD_FAILURE})
