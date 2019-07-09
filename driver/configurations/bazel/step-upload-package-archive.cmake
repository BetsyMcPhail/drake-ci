if(DASHBOARD_FAILURE OR DASHBOARD_UNSTABLE)
  notice("CTest Status: NOT UPLOADING PACKAGE ARCHIVE BECAUSE BAZEL BUILD WAS NOT SUCCESSFUL")
else()
  notice("CTest Status: UPLOADING PACKAGE ARCHIVE")
  set(DASHBOARD_PACKAGE_ARCHIVE_STORAGE_CLASS STANDARD)
  if(DASHBOARD_TRACK STREQUAL "Nightly")
    set(DASHBOARD_PACKAGE_ARCHIVE_CACHE_CONTROL_MAX_AGE 31536000)  # 365 days.
    set(DASHBOARD_PACKAGE_ARCHIVE_LATEST_CACHE_CONTROL_MAX_AGE 64800)  # 18 hours.
  else()
    set(DASHBOARD_PACKAGE_ARCHIVE_CACHE_CONTROL_MAX_AGE 2419200)  # 28 days.
    set(DASHBOARD_PACKAGE_ARCHIVE_LATEST_CACHE_CONTROL_MAX_AGE 2700)  # 45 minutes.
  endif()
  if(DASHBOARD_TRACK STREQUAL "Experimental")
    set(DASHBOARD_PACKAGE_ARCHIVE_TOTAL_UPLOADS 1)
  else()
    set(DASHBOARD_PACKAGE_ARCHIVE_TOTAL_UPLOADS 2)
  endif()
  string(TOLOWER "${DASHBOARD_TRACK}" DASHBOARD_PACKAGE_ARCHIVE_FOLDER)
  message(STATUS "Uploading nightly package archive 1 of ${DASHBOARD_PACKAGE_ARCHIVE_TOTAL_UPLOADS} to AWS S3...")
  execute_process(
    COMMAND ${DASHBOARD_AWS_COMMAND} s3 cp
      --acl public-read
      --cache-control max-age=${DASHBOARD_PACKAGE_ARCHIVE_CACHE_CONTROL_MAX_AGE}
      --storage-class ${DASHBOARD_PACKAGE_ARCHIVE_STORAGE_CLASS}
      "${DASHBOARD_WORKSPACE}/${DASHBOARD_PACKAGE_ARCHIVE_NAME}"
      "s3://drake-packages/drake/${DASHBOARD_PACKAGE_ARCHIVE_FOLDER}/${DASHBOARD_PACKAGE_ARCHIVE_NAME}"
    RESULT_VARIABLE DASHBOARD_AWS_S3_RESULT_VARIABLE)
  if(DASHBOARD_AWS_S3_RESULT_VARIABLE EQUAL 0)
    message(STATUS "Package URL 1 of ${DASHBOARD_PACKAGE_ARCHIVE_TOTAL_UPLOADS}: https://drake-packages.csail.mit.edu/drake/${DASHBOARD_PACKAGE_ARCHIVE_FOLDER}/${DASHBOARD_PACKAGE_ARCHIVE_NAME}")
  else()
    append_step_status("BAZEL NIGHTLY PACKAGE ARCHIVE UPLOAD 1 OF ${DASHBOARD_PACKAGE_ARCHIVE_TOTAL_UPLOADS}" UNSTABLE)
  endif()
  if(NOT DASHBOARD_UNSTABLE)
    file(SHA512 "${DASHBOARD_WORKSPACE}/${DASHBOARD_PACKAGE_ARCHIVE_NAME}" DASHBOARD_PACKAGE_SHA512)
    file(WRITE "${DASHBOARD_WORKSPACE}/${DASHBOARD_PACKAGE_ARCHIVE_NAME}.sha512" "${DASHBOARD_PACKAGE_SHA512}  ${DASHBOARD_PACKAGE_ARCHIVE_NAME}")
    message(STATUS "Uploading nightly package archive checksum 1 of ${DASHBOARD_PACKAGE_ARCHIVE_TOTAL_UPLOADS} to AWS S3...")
    execute_process(
      COMMAND ${DASHBOARD_AWS_COMMAND} s3 cp
        --acl public-read
        --cache-control max-age=${DASHBOARD_PACKAGE_ARCHIVE_CACHE_CONTROL_MAX_AGE}
        --storage-class ${DASHBOARD_PACKAGE_ARCHIVE_STORAGE_CLASS}
        "${DASHBOARD_WORKSPACE}/${DASHBOARD_PACKAGE_ARCHIVE_NAME}.sha512"
        "s3://drake-packages/drake/${DASHBOARD_PACKAGE_ARCHIVE_FOLDER}/${DASHBOARD_PACKAGE_ARCHIVE_NAME}.sha512"
      RESULT_VARIABLE DASHBOARD_AWS_S3_RESULT_VARIABLE)
    if(NOT DASHBOARD_AWS_S3_RESULT_VARIABLE EQUAL 0)
      append_step_status("BAZEL NIGHTLY PACKAGE ARCHIVE CHECKSUM UPLOAD 1 OF ${DASHBOARD_PACKAGE_ARCHIVE_TOTAL_UPLOADS}" UNSTABLE)
    endif()
  endif()
  if(DASHBOARD_PACKAGE_ARCHIVE_TOTAL_UPLOADS EQUAL 2)
    set(DASHBOARD_PACKAGE_ARCHIVE_LATEST_NAME "drake-latest-${DASHBOARD_PACKAGE_ARCHIVE_DISTRIBUTION}.tar.gz")
    if(NOT DASHBOARD_UNSTABLE)
      message(STATUS "Uploading nightly package archive 2 of 2 to AWS S3...")
      execute_process(
        COMMAND ${DASHBOARD_AWS_COMMAND} s3 cp
          --acl public-read
          --cache-control max-age=${DASHBOARD_PACKAGE_ARCHIVE_LATEST_CACHE_CONTROL_MAX_AGE}
          --storage-class ${DASHBOARD_PACKAGE_ARCHIVE_STORAGE_CLASS}
          "${DASHBOARD_WORKSPACE}/${DASHBOARD_PACKAGE_ARCHIVE_NAME}"
          "s3://drake-packages/drake/${DASHBOARD_PACKAGE_ARCHIVE_FOLDER}/${DASHBOARD_PACKAGE_ARCHIVE_LATEST_NAME}"
        RESULT_VARIABLE DASHBOARD_AWS_S3_RESULT_VARIABLE)
      if(DASHBOARD_AWS_S3_RESULT_VARIABLE EQUAL 0)
        message(STATUS "Package URL 2 of 2: https://drake-packages.csail.mit.edu/drake/${DASHBOARD_PACKAGE_ARCHIVE_FOLDER}/${DASHBOARD_PACKAGE_ARCHIVE_LATEST_NAME}")
      else()
        append_step_status("BAZEL NIGHTLY PACKAGE ARCHIVE UPLOAD 2 OF 2" UNSTABLE)
      endif()
    endif()
    if(NOT DASHBOARD_UNSTABLE)
      file(WRITE "${DASHBOARD_WORKSPACE}/${DASHBOARD_PACKAGE_ARCHIVE_LATEST_NAME}.sha512" "${DASHBOARD_PACKAGE_SHA512}  ${DASHBOARD_PACKAGE_ARCHIVE_LATEST_NAME}")
      message(STATUS "Uploading nightly package archive checksum 2 of 2 to AWS S3...")
      execute_process(
        COMMAND ${DASHBOARD_AWS_COMMAND} s3 cp
          --acl public-read
          --cache-control max-age=${DASHBOARD_PACKAGE_ARCHIVE_LATEST_CACHE_CONTROL_MAX_AGE}
          --storage-class ${DASHBOARD_PACKAGE_ARCHIVE_STORAGE_CLASS}
          "${DASHBOARD_WORKSPACE}/${DASHBOARD_PACKAGE_ARCHIVE_LATEST_NAME}.sha512"
          "s3://drake-packages/drake/${DASHBOARD_PACKAGE_ARCHIVE_FOLDER}/${DASHBOARD_PACKAGE_ARCHIVE_LATEST_NAME}.sha512"
        RESULT_VARIABLE DASHBOARD_AWS_S3_RESULT_VARIABLE)
      if(NOT DASHBOARD_AWS_S3_RESULT_VARIABLE EQUAL 0)
        append_step_status("BAZEL NIGHTLY PACKAGE ARCHIVE CHECKSUM UPLOAD 2 OF 2" UNSTABLE)
      endif()
    endif()
  endif()
endif()