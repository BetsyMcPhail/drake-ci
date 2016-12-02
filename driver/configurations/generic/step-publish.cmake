if(DASHBOARD_FAILURE OR DASHBOARD_UNSTABLE)
  notice("CTest Status: NOT PUBLISHING DOCUMENTATION BECAUSE BUILD WAS NOT SUCCESSFUL")
else()
  notice("CTest Status: PUBLISHING DOCUMENTATION")

  execute_process(COMMAND "${DASHBOARD_TOOLS_DIR}/publish_documentation.bash"
    WORKING_DIRECTORY "${DASHBOARD_WORKSPACE}"
    RESULT_VARIABLE DASHBOARD_PUBLISH_DOCUMENTATION_RESULT_VARIABLE
    OUTPUT_VARIABLE DASHBOARD_PUBLISH_DOCUMENTATION_OUTPUT_VARIABLE
    ERROR_VARIABLE DASHBOARD_PUBLISH_DOCUMENTATION_OUTPUT_VARIABLE)
  message("${DASHBOARD_PUBLISH_DOCUMENTATION_OUTPUT_VARIABLE}")

  if(NOT DASHBOARD_PUBLISH_DOCUMENTATION_RESULT_VARIABLE EQUAL 0)
    append_step_status("PUBLISHING DOCUMENTATION" UNSTABLE)
  endif()
endif()
