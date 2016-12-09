set(CTEST_SOURCE_DIRECTORY "${DASHBOARD_SOURCE_DIRECTORY}")
set(CTEST_BINARY_DIRECTORY "${DASHBOARD_BINARY_DIRECTORY}")

# Switch the dashboard (back) to the drake superbuild dashboard
begin_stage(
  URL_NAME "Superbuild"
  PROJECT_NAME "drake-superbuild"
  BUILD_NAME "${DASHBOARD_BUILD_NAME}-post-drake")

# Reconfigure the build, turning on post-drake externals
ctest_configure(BUILD "${CTEST_BINARY_DIRECTORY}"
  OPTIONS "-DSKIP_DRAKE_BUILD:BOOL=OFF"
  SOURCE "${CTEST_SOURCE_DIRECTORY}"
  RETURN_VALUE DASHBOARD_SUPERBUILD_CONFIGURE_RETURN_VALUE QUIET)
if(NOT DASHBOARD_SUPERBUILD_CONFIGURE_RETURN_VALUE EQUAL 0)
  append_step_status("CONFIGURE SUPERBUILD (POST-DRAKE)" FAILURE)
endif()

# Run the build
ctest_build(BUILD "${CTEST_BINARY_DIRECTORY}" APPEND
  NUMBER_ERRORS DASHBOARD_SUPERBUILD_NUMBER_BUILD_ERRORS QUIET)
if(DASHBOARD_SUPERBUILD_NUMBER_BUILD_ERRORS GREATER 0)
  append_step_status("BUILD SUPERBUILD (POST-DRAKE)" FAILURE)
endif()

# Submit the results
ctest_submit(RETRY_COUNT 4 RETRY_DELAY 15
  RETURN_VALUE DASHBOARD_SUPERBUILD_SUBMIT_RETURN_VALUE QUIET)
