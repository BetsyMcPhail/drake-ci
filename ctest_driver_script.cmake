# ctest --extra-verbose --no-compress-output --output-on-failure
#
# Variables:
#
#   ENV{BUILD_ID}         optional    value of Jenkins BUILD_ID
#   ENV{WORKSPACE}        required    value of Jenkins WORKSPACE
#
#   ENV{compiler}         optional    "clang" | "cpplint" | "gcc" | "include-what-you-use" | "msvc-32" | "msvc-64" | "scan-build"
#   ENV{coverage}         optional    "false" | "true"
#   ENV{debug}            optional    "false" | "true"
#   ENV{documentation}    optional    "false" | "true"
#   ENV{ghprbPullId}      optional    value for CTEST_CHANGE_ID
#   ENV{matlab}           optional    "false" | "true"
#   ENV{memcheck}         optional    "asan" | "msan" | "tsan" | "valgrind"
#   ENV{openSource}       optional    "false" | "true"
#   ENV{track}            optional    "continuous" | "experimental" | "nightly"
#
#   buildname             optional    value for CTEST_BUILD_NAME
#   site                  optional    value for CTEST_SITE

cmake_minimum_required(VERSION 3.5 FATAL_ERROR)

if(NOT DEFINED ENV{WORKSPACE})
  message(FATAL_ERROR
    "*** CTest Result: FAILURE BECAUSE ENV{WORKSPACE} WAS NOT SET")
endif()

# set site and build name
if(DEFINED site)
  if(APPLE)
    string(REGEX REPLACE "(.*)_(.*)" "\\1" DASHBOARD_SITE "${site}")
  else()
    set(DASHBOARD_SITE "${site}")
  endif()
  set(CTEST_SITE "${DASHBOARD_SITE}")
else()
  message(WARNING "*** CTEST_SITE was not set")
endif()

if(DEFINED buildname)
  set(CTEST_BUILD_NAME "${buildname}")
else()
  message(WARNING "*** CTEST_BUILD_NAME was not set")
endif()

include(ProcessorCount)
ProcessorCount(DASHBOARD_PROCESSOR_COUNT)

set(CTEST_TEST_ARGS "")

if(DASHBOARD_PROCESSOR_COUNT EQUAL 0)
  message(WARNING "*** CTEST_TEST_ARGS PARALLEL_LEVEL was not set")
else()
  set(CTEST_TEST_ARGS ${CTEST_TEST_ARGS}
    PARALLEL_LEVEL ${DASHBOARD_PROCESSOR_COUNT})
endif()

if(NOT DEFINED ENV{compiler})
  message(WARNING "*** ENV{compiler} was not set")
  if(WIN32)
    set(ENV{compiler} "msvc-64")
  elseif(APPLE)
    set(ENV{compiler} "clang")
  else()
    set(ENV{compiler} "gcc")
  endif()
endif()

if(WIN32)
  set(CTEST_CMAKE_GENERATOR "Visual Studio 14 2015")
  set(ENV{CMAKE_FLAGS} "-G \"Visual Studio 14 2015\"")  # HACK
  set(CTEST_USE_LAUNCHERS OFF)
  set(ENV{CXXFLAGS} "-MP")
  set(ENV{CFLAGS} "-MP")
elseif(NOT "$ENV{compiler}" MATCHES "cpplint")
  set(CTEST_CMAKE_GENERATOR "Unix Makefiles")
  if(NOT DASHBOARD_PROCESSOR_COUNT EQUAL 0)
    set(CTEST_BUILD_FLAGS "-j${DASHBOARD_PROCESSOR_COUNT}")
  endif()
  set(CTEST_USE_LAUNCHERS ON)
  set(ENV{CTEST_USE_LAUNCHERS_DEFAULT} 1)
endif()

# check for compiler settings
if("$ENV{compiler}" MATCHES "gcc")
  set(ENV{CC} "gcc-4.9")
  set(ENV{CXX} "g++-4.9")
  set(ENV{FC} "gfortran-4.9")
elseif("$ENV{compiler}" MATCHES "clang" OR "$ENV{compiler}" MATCHES "include-what-you-use")
  set(ENV{CC} "clang")
  set(ENV{CXX} "clang++")
  if(APPLE)
    set(ENV{FC} "gfortran")
  else()
    set(ENV{FC} "gfortran-4.9")
  endif()
elseif("$ENV{compiler}" MATCHES "scan-build")
  find_program(DASHBOARD_CCC_ANALYZER_COMMAND NAMES "ccc-analyzer"
    PATHS "/usr/local/libexec" "/usr/libexec")
  find_program(DASHBOARD_CXX_ANALYZER_COMMAND NAMES "c++-analyzer"
    PATHS "/usr/local/libexec" "/usr/libexec")
  if(NOT DASHBOARD_CCC_ANALYZER_COMMAND OR NOT DASHBOARD_CXX_ANALYZER_COMMAND)
    message(FATAL_ERROR
      "*** CTest Result: FAILURE BECAUSE SCAN-BUILD WAS NOT FOUND")
  endif()
  set(ENV{CC} "${DASHBOARD_CCC_ANALYZER_COMMAND}")
  set(ENV{CXX} "${DASHBOARD_CXX_ANALYZER_COMMAND}")
  set(ENV{CCC_CC} "clang")
  set(ENV{CCC_CXX} "clang++")
  if(APPLE)
    set(ENV{FC} "gfortran")
  else()
    set(ENV{FC} "gfortran-4.9")
  endif()
elseif("$ENV{compiler}" MATCHES "msvc-64")
  set(CTEST_CMAKE_GENERATOR "Visual Studio 14 2015 Win64")
  set(ENV{CMAKE_FLAGS} "-G \"Visual Studio 14 2015 Win64\"")  # HACK
endif()

file(TO_CMAKE_PATH "$ENV{WORKSPACE}" DASHBOARD_WORKSPACE)
set(CTEST_SOURCE_DIRECTORY "${DASHBOARD_WORKSPACE}")
set(CTEST_BINARY_DIRECTORY "${DASHBOARD_WORKSPACE}/pod-build")

if(WIN32)
  file(DOWNLOAD
    "https://s3.amazonaws.com/drake-provisioning/pkg-config.exe"
    "${DASHBOARD_WORKSPACE}/pkg-config.exe")
  set(PATH
    "${DASHBOARD_WORKSPACE}"
    "${DASHBOARD_WORKSPACE}/drake/pod-build/lib/Release"
    "${DASHBOARD_WORKSPACE}/build/bin"
    "${DASHBOARD_WORKSPACE}/build/lib")
  foreach(p ${PATH})
    file(TO_NATIVE_PATH "${p}" path)
    list(APPEND paths "${path}")
  endforeach()
  set(curPath "$ENV{PATH}")
  set(ENV{PATH} "${paths};${curPath}")
elseif(APPLE)
  set(ENV{PATH} "/opt/X11/bin:/usr/local/bin:/usr/bin:/bin:/usr/local/sbin:/usr/sbin:/sbin:$ENV{PATH}")
endif()

if("$ENV{matlab}" MATCHES "true")
  if(WIN32)
    if("$ENV{compiler}" MATCHES "msvc-64")
      set(ENV{PATH} "C:\\Program Files\\MATLAB\\R2015b\\runtime\\win64;C:\\Program Files\\MATLAB\\R2015b\\bin;$ENV{PATH}")
    else()
      set(ENV{PATH} "C:\\Program Files (x86)\\MATLAB\\R2015b\\runtime\\win32;C:\\Program Files (x86)\\MATLAB\\R2015b\\bin;$ENV{PATH}")
    endif()
    execute_process(COMMAND mex -setup c
      RESULT_VARIABLE DASHBOARD_MEX_C_RESULT_VARIABLE)
    execute_process(COMMAND mex -setup c++
      RESULT_VARIABLE DASHBOARD_MEX_CXX_RESULT_VARIABLE)
    if(NOT DASHBOARD_MEX_C_RESULT_VARIABLE EQUAL 0 OR NOT DASHBOARD_MEX_CXX_RESULT_VARIABLE EQUAL 0)
      message(WARNING "*** mex setup was not successful")
    endif()
  elseif(APPLE)
    set(ENV{PATH} "/Applications/MATLAB_R2015b.app/bin:/Applications/MATLAB_R2015b.app/runtime/maci64:$ENV{PATH}")
  else()
    set(ENV{PATH} "/usr/local/MATLAB/R2015b/bin:$ENV{PATH}")
  endif()
endif()

set(CTEST_GIT_COMMAND "git")
set(CTEST_UPDATE_COMMAND "${CTEST_GIT_COMMAND}")
set(CTEST_UPDATE_VERSION_ONLY ON)

# clean out the old builds
file(REMOVE_RECURSE "${CTEST_BINARY_DIRECTORY}")
file(MAKE_DIRECTORY "${CTEST_BINARY_DIRECTORY}")

# set model and track for submission
set(DASHBOARD_MODEL "Experimental")
if("$ENV{track}" MATCHES "continuous")
  set(DASHBOARD_TRACK "Continuous")
elseif("$ENV{track}" MATCHES "nightly")
  set(DASHBOARD_MODEL "Nightly")
  set(DASHBOARD_TRACK "Nightly")
else()
  set(DASHBOARD_TRACK "Experimental")
endif()

set(DASHBOARD_CONFIGURE_AND_BUILD_SUPERBUILD ON)
set(DASHBOARD_CONFIGURE ON)
set(DASHBOARD_INSTALL ON)
set(DASHBOARD_TEST ON)

set(DASHBOARD_COVERAGE OFF)
set(DASHBOARD_MEMCHECK OFF)

if("$ENV{compiler}" MATCHES "cpplint")
  set(DASHBOARD_CONFIGURE_AND_BUILD_SUPERBUILD OFF)
  set(DASHBOARD_CONFIGURE OFF)
  set(DASHBOARD_INSTALL OFF)
  set(DASHBOARD_TEST OFF)
  find_program(DASHBOARD_CPPLINT_COMMAND NAMES "cpplint" "cpplint.py")
  if(NOT DASHBOARD_CPPLINT_COMMAND)
    file(WRITE "${DASHBOARD_WORKSPACE}/FAILURE")
    message(FATAL_ERROR
      "*** CTest Result: FAILURE BECAUSE CPPLINT WAS NOT FOUND")
  endif()
  set(CTEST_BUILD_COMMAND
    "${CMAKE_CURRENT_LIST_DIR}/cpplint_wrapper.py --cpplint=${DASHBOARD_CPPLINT_COMMAND} --excludes=(\\.git|doc|pod-build|thirdParty) ${DASHBOARD_WORKSPACE}/drake")
endif()

set(DASHBOARD_INSTALL_PREFIX "${DASHBOARD_WORKSPACE}/build")

# clean out any old installs
file(REMOVE_RECURSE "${DASHBOARD_INSTALL_PREFIX}")

set(DASHBOARD_CONFIGURATION_TYPE "Release")
set(DASHBOARD_TEST_TIMEOUT 500)

set(DASHBOARD_C_FLAGS "")
set(DASHBOARD_CXX_FLAGS "")
set(DASHBOARD_CXX_STANDARD "")
set(DASHBOARD_FORTRAN_FLAGS "")
set(DASHBOARD_POSITION_INDEPENDENT_CODE OFF)
set(DASHBOARD_SHARED_LINKER_FLAGS "")
set(DASHBOARD_STATIC_LINKER_FLAGS "")
set(DASHBOARD_VERBOSE_MAKEFILE OFF)

if("$ENV{compiler}" MATCHES "include-what-you-use")
  set(DASHBOARD_INSTALL OFF)
  set(DASHBOARD_TEST OFF)
  set(DASHBOARD_CONFIGURATION_TYPE "Debug")
  find_program(DASHBOARD_INCLUDE_WHAT_YOU_USE_COMMAND
    NAMES "include-what-you-use")
  if(NOT DASHBOARD_INCLUDE_WHAT_YOU_USE_COMMAND)
    file(WRITE "${DASHBOARD_WORKSPACE}/FAILURE")
    message(FATAL_ERROR
      "*** CTest Result: FAILURE BECAUSE INCLUDE-WHAT-YOU-USE WAS NOT FOUND")
  endif()
  set(DASHBOARD_INCLUDE_WHAT_YOU_USE
    "${DASHBOARD_INCLUDE_WHAT_YOU_USE_COMMAND}" "-Xiwyu" "--mapping_file=${DASHBOARD_WORKSPACE}/drake/include-what-you-use.imp")
endif()

if("$ENV{compiler}" MATCHES "scan-build")
  set(DASHBOARD_INSTALL OFF)
  set(DASHBOARD_TEST OFF)
  set(DASHBOARD_CONFIGURATION_TYPE "Debug")
  set(DASHBOARD_EXTRA_DEBUG_FLAGS "-O0")
  set(DASHBOARD_C_FLAGS "${DASHBOARD_EXTRA_DEBUG_FLAGS} ${DASHBOARD_C_FLAGS}")
  set(DASHBOARD_CXX_FLAGS
    "${DASHBOARD_EXTRA_DEBUG_FLAGS} ${DASHBOARD_CXX_FLAGS}")
  set(DASHBOARD_CCC_ANALYZER_HTML "${DASHBOARD_WORKSPACE}/drake/pod-build/html")
  set(ENV{CCC_ANALYZER_HTML} "${DASHBOARD_CCC_ANALYZER_HTML}")
  file(MAKE_DIRECTORY "${DASHBOARD_CCC_ANALYZER_HTML}")
endif()

# set compiler flags for coverage builds
if("$ENV{coverage}" MATCHES "true")
  set(DASHBOARD_COVERAGE ON)
  set(DASHBOARD_INSTALL OFF)
  set(DASHBOARD_CONFIGURATION_TYPE "Debug")
  set(DASHBOARD_COVERAGE_FLAGS "-fprofile-arcs -ftest-coverage")
  set(DASHBOARD_EXTRA_DEBUG_FLAGS "-O0")
  set(DASHBOARD_C_FLAGS
    "${DASHBOARD_COVERAGE_FLAGS} ${DASHBOARD_EXTRA_DEBUG_FLAGS} ${DASHBOARD_C_FLAGS}")
  set(DASHBOARD_CXX_FLAGS
    "${DASHBOARD_COVERAGE_FLAGS} ${DASHBOARD_EXTRA_DEBUG_FLAGS} ${DASHBOARD_CXX_FLAGS}")
  set(DASHBOARD_SHARED_LINKER_FLAGS
    "${DASHBOARD_COVERAGE_FLAGS} ${DASHBOARD_SHARED_LINKER_FLAGS}")

  if("$ENV{compiler}" MATCHES "clang")
    find_program(DASHBOARD_COVERAGE_COMMAND NAMES "llvm-cov")
    if(NOT DASHBOARD_COVERAGE_COMMAND)
      file(WRITE "${DASHBOARD_WORKSPACE}/FAILURE")
      message(FATAL_ERROR
        "*** CTest Result: FAILURE BECAUSE LLVM-COV WAS NOT FOUND")
    endif()
    set(DASHBOARD_COVERAGE_EXTRA_FLAGS "gcov")
  elseif("$ENV{compiler}" MATCHES "gcc")
    find_program(DASHBOARD_COVERAGE_COMMAND NAMES "gcov-4.9")
    if(NOT DASHBOARD_COVERAGE_COMMAND)
      file(WRITE "${DASHBOARD_WORKSPACE}/FAILURE")
      message(FATAL_ERROR
        "*** CTest Result: FAILURE BECAUSE GCOV-4.9 WAS NOT FOUND")
    endif()
  else()
    file(WRITE "${DASHBOARD_WORKSPACE}/FAILURE")
    message(FATAL_ERROR
      "*** CTest Result: FAILURE BECAUSE CTEST_COVERAGE_COMMAND WAS NOT SET")
  endif()

  set(CTEST_COVERAGE_COMMAND "${DASHBOARD_COVERAGE_COMMAND}")
  set(CTEST_COVERAGE_EXTRA_FLAGS "${DASHBOARD_COVERAGE_EXTRA_FLAGS}")

  set(CTEST_CUSTOM_COVERAGE_EXCLUDE
    ${CTEST_CUSTOM_COVERAGE_EXCLUDE}
    ".*/thirdParty/.*"
    ".*/test/.*"
  )
endif()

# set compiler flags for memcheck builds
if("$ENV{memcheck}" MATCHES "asan" OR "$ENV{memcheck}" MATCHES "msan" OR "$ENV{memcheck}" MATCHES "tsan" OR "$ENV{memcheck}" MATCHES "valgrind")
  set(DASHBOARD_MEMCHECK ON)
  set(DASHBOARD_INSTALL OFF)
  set(DASHBOARD_CONFIGURATION_TYPE "Debug")
  set(DASHBOARD_EXTRA_DEBUG_FLAGS "-O1 -fno-omit-frame-pointer")
  set(DASHBOARD_C_FLAGS "${DASHBOARD_EXTRA_DEBUG_FLAGS} ${DASHBOARD_C_FLAGS}")
  set(DASHBOARD_CXX_FLAGS "${DASHBOARD_EXTRA_DEBUG_FLAGS} ${DASHBOARD_CXX_FLAGS}")
  if("$ENV{memcheck}" MATCHES "msan")
    set(ENV{LD_LIBRARY_PATH} "/usr/local/libcxx_msan/lib:$ENV{LD_LIBRARY_PATH}")
    set(DASHBOARD_C_FLAGS
      "-I/usr/local/libcxx_msan/include ${DASHBOARD_C_FLAGS}")
    set(DASHBOARD_CXX_FLAGS
      "-stdlib=libc++ -L/usr/local/libcxx_msan/lib -lc++abi -I/usr/local/libcxx_msan/include -I/usr/local/libcxx_msan/include/c++/v1 ${DASHBOARD_CXX_FLAGS}")
    set(DASHBOARD_CXX_STANDARD 11)
  endif()
  if("$ENV{memcheck}" MATCHES "asan")
    set(DASHBOARD_MEMORYCHECK_TYPE "AddressSanitizer")
    set(DASHBOARD_SANITIZE_FLAGS "-fsanitize=address")
    set(DASHBOARD_C_FLAGS "${DASHBOARD_SANITIZE_FLAGS} ${DASHBOARD_C_FLAGS}")
    set(DASHBOARD_CXX_FLAGS
      "${DASHBOARD_SANITIZE_FLAGS} ${DASHBOARD_CXX_FLAGS}")
    set(DASHBOARD_SHARED_LINKER_FLAGS
      "${DASHBOARD_SANITIZE_FLAGS} ${DASHBOARD_SHARED_LINKER_FLAGS}")
  elseif("$ENV{memcheck}" MATCHES "msan")
    set(DASHBOARD_MEMORYCHECK_TYPE "MemorySanitizer")
    set(DASHBOARD_SANITIZE_FLAGS "-fsanitize=memory")
    set(DASHBOARD_C_FLAGS "${DASHBOARD_SANITIZE_FLAGS} ${DASHBOARD_C_FLAGS}")
    set(DASHBOARD_CXX_FLAGS
      "${DASHBOARD_SANITIZE_FLAGS} ${DASHBOARD_CXX_FLAGS}")
    set(DASHBOARD_SHARED_LINKER_FLAGS
      "${DASHBOARD_SANITIZE_FLAGS} ${DASHBOARD_SHARED_LINKER_FLAGS}")
  elseif("$ENV{memcheck}" MATCHES "tsan")
    set(DASHBOARD_MEMORYCHECK_TYPE "ThreadSanitizer")
    set(DASHBOARD_SANITIZE_FLAGS "-fsanitize=thread")
    set(DASHBOARD_C_FLAGS "${DASHBOARD_SANITIZE_FLAGS} ${DASHBOARD_C_FLAGS}")
    set(DASHBOARD_CXX_FLAGS
      "${DASHBOARD_SANITIZE_FLAGS} ${DASHBOARD_CXX_FLAGS}")
    set(DASHBOARD_SHARED_LINKER_FLAGS
      "${DASHBOARD_SANITIZE_FLAGS} ${DASHBOARD_SHARED_LINKER_FLAGS}")
    set(DASHBOARD_POSITION_INDEPENDENT_CODE ON)
  elseif("$ENV{memcheck}" MATCHES "valgrind")
    set(DASHBOARD_MEMORYCHECK_TYPE "Valgrind")
    find_program(DASHBOARD_MEMORYCHECK_COMMAND NAMES "valgrind")
    set(CTEST_MEMORYCHECK_COMMAND "${DASHBOARD_MEMORYCHECK_COMMAND}")
    set(CTEST_MEMORYCHECK_COMMAND_OPTIONS "--show-leak-kinds=definite,possible")
    set(CTEST_MEMORYCHECK_SUPPRESSIONS_FILE
      "${DASHBOARD_WORKSPACE}/drake/valgrind.supp")
    if(NOT EXISTS "${DASHBOARD_WORKSPACE}/drake/valgrind.supp")
      file(WRITE "${DASHBOARD_WORKSPACE}/FAILURE")
      message(FATAL_ERROR
        "*** CTest Result: FAILURE BECAUSE CTEST_MEMORYCHECK_SUPPRESSIONS_FILE WAS NOT FOUND")
    endif()
  else()
    file(WRITE "${DASHBOARD_WORKSPACE}/FAILURE")
    message(FATAL_ERROR
      "*** CTest Result: FAILURE BECAUSE CTEST_MEMORYCHECK_TYPE WAS NOT SET")
  endif()
  set(CTEST_MEMORYCHECK_TYPE "${DASHBOARD_MEMORYCHECK_TYPE}")
endif()

if("$ENV{debug}" MATCHES "true")
  set(DASHBOARD_CONFIGURATION_TYPE "Debug")
endif()

if(DASHBOARD_CONFIGURATION_TYPE MATCHES "Debug")
  set(DASHBOARD_TEST_TIMEOUT 1500)
endif()

if("$ENV{matlab}" MATCHES "true")
  if(APPLE)
    math(EXPR DASHBOARD_TEST_TIMEOUT "${DASHBOARD_TEST_TIMEOUT} + 250")
  else()
    math(EXPR DASHBOARD_TEST_TIMEOUT "${DASHBOARD_TEST_TIMEOUT} + 125")
  endif()
endif()

set(ENV{CMAKE_CONFIG_TYPE} "${DASHBOARD_CONFIGURATION_TYPE}")
set(CTEST_CONFIGURATION_TYPE "${DASHBOARD_CONFIGURATION_TYPE}")
set(CTEST_TEST_TIMEOUT ${DASHBOARD_TEST_TIMEOUT})

if("${CTEST_CMAKE_GENERATOR}" MATCHES "Unix Makefiles")
  set(DASHBOARD_VERBOSE_MAKEFILE ON)
  set(ENV{CMAKE_FLAGS}
    "-DCMAKE_VERBOSE_MAKEFILE:BOOL=ON $ENV{CMAKE_FLAGS}")  # HACK
endif()

set(CACHE_C_FLAGS "")
set(CACHE_C_INCLUDE_WHAT_YOU_USE "")
set(CACHE_CXX_FLAGS "")
set(CACHE_CXX_INCLUDE_WHAT_YOU_USE "")
set(CACHE_CXX_STANDARD "")
set(CACHE_CXX_STANDARD_REQUIRED "")
set(CACHE_EXE_LINKER_FLAGS "")
set(CACHE_FORTRAN_FLAGS "")
set(CACHE_INSTALL_PREFIX "")
set(CACHE_POSITION_INDEPENDENT_CODE "")
set(CACHE_SHARED_LINKER_FLAGS "")
set(CACHE_STATIC_LINKER_FLAGS "")
set(CACHE_VERBOSE_MAKEFILE "")

if(DASHBOARD_C_FLAGS)
  set(CACHE_C_FLAGS "CMAKE_C_FLAGS:STRING=${DASHBOARD_C_FLAGS}")
endif()
if(DASHBOARD_CXX_FLAGS)
  set(CACHE_CXX_FLAGS "CMAKE_CXX_FLAGS:STRING=${DASHBOARD_CXX_FLAGS}")
endif()
if(DASHBOARD_CXX_STANDARD)
  set(CACHE_CXX_STANDARD_REQUIRED "CMAKE_CXX_STANDARD_REQUIRED:BOOL=ON")
  set(CACHE_CXX_STANDARD "CMAKE_CXX_STANDARD:STRING=${DASHBOARD_CXX_STANDARD}")
endif()
if(DASHBOARD_FORTRAN_FLAGS)
  set(CACHE_FORTRAN_FLAGS
    "CMAKE_Fortran_FLAGS:STRING=${DASHBOARD_FORTRAN_FLAGS}")
endif()
if(DASHBOARD_INCLUDE_WHAT_YOU_USE)
  set(CACHE_C_INCLUDE_WHAT_YOU_USE
    "CMAKE_C_INCLUDE_WHAT_YOU_USE:STRING=${DASHBOARD_INCLUDE_WHAT_YOU_USE}")
  set(CACHE_CXX_INCLUDE_WHAT_YOU_USE
    "CMAKE_CXX_INCLUDE_WHAT_YOU_USE:STRING=${DASHBOARD_INCLUDE_WHAT_YOU_USE}")
endif()
if(DASHBOARD_INSTALL_PREFIX)
  set(CACHE_INSTALL_PREFIX
    "CMAKE_INSTALL_PREFIX:PATH=${DASHBOARD_INSTALL_PREFIX}")
endif()
if(DASHBOARD_POSITION_INDEPENDENT_CODE)
  set(CACHE_POSITION_INDEPENDENT_CODE
    "CMAKE_POSITION_INDEPENDENT_CODE:BOOL=${DASHBOARD_POSITION_INDEPENDENT_CODE}")
endif()
if(DASHBOARD_SHARED_LINKER_FLAGS)
  set(CACHE_EXE_LINKER_FLAGS
    "CMAKE_EXE_LINKER_FLAGS:STRING=${DASHBOARD_SHARED_LINKER_FLAGS}")
  set(CACHE_SHARED_LINKER_FLAGS
    "CMAKE_SHARED_LINKER_FLAGS:STRING=${DASHBOARD_SHARED_LINKER_FLAGS}")
endif()
if(DASHBOARD_STATIC_LINKER_FLAGS)
  set(CACHE_STATIC_LINKER_FLAGS
    "CMAKE_STATIC_LINKER_FLAGS:STRING=${DASHBOARD_STATIC_LINKER_FLAGS}")
endif()
if(DASHBOARD_VERBOSE_MAKEFILE)
  set(CACHE_VERBOSE_MAKEFILE
    "CMAKE_VERBOSE_MAKEFILE:BOOL=${DASHBOARD_VERBOSE_MAKEFILE}")
endif()

set(DASHBOARD_BUILD_DOCUMENTATION OFF)
set(DASHBOARD_LONG_RUNNING_TESTS OFF)

if("$ENV{documentation}" MATCHES "true")
  set(DASHBOARD_BUILD_DOCUMENTATION ON)
endif()

if(NOT "${DASHBOARD_TRACK}" MATCHES "Experimental")
  set(DASHBOARD_LONG_RUNNING_TESTS ON)
endif()

set(CACHE_BUILD_DOCUMENTATION
  "BUILD_DOCUMENTATION:BOOL=${DASHBOARD_BUILD_DOCUMENTATION}")
set(CACHE_LONG_RUNNING_TESTS
  "LONG_RUNNING_TESTS:BOOL=${DASHBOARD_LONG_RUNNING_TESTS}")

set(DASHBOARD_WITH_AVL OFF)
set(DASHBOARD_WITH_BERTINI OFF)
set(DASHBOARD_WITH_BOT_CORE_LCMTYPES ON)
set(DASHBOARD_WITH_BULLET ON)
set(DASHBOARD_WITH_EIGEN ON)
set(DASHBOARD_WITH_GLOPTIPOLY OFF)
set(DASHBOARD_WITH_GOOGLETEST ON)
set(DASHBOARD_WITH_GTK OFF)
set(DASHBOARD_WITH_GUROBI OFF)
set(DASHBOARD_WITH_IRIS OFF)
set(DASHBOARD_WITH_LCM ON)
set(DASHBOARD_WITH_MESHCONVERTERS OFF)
set(DASHBOARD_WITH_MOSEK OFF)
set(DASHBOARD_WITH_NLOPT OFF)
set(DASHBOARD_WITH_OCTOMAP OFF)
set(DASHBOARD_WITH_SEDUMI OFF)
set(DASHBOARD_WITH_SIGNALSCOPE OFF)
set(DASHBOARD_WITH_SNOPT OFF)
set(DASHBOARD_WITH_SNOPT_PRECOMPILED OFF)
set(DASHBOARD_WITH_SPOTLESS OFF)
set(DASHBOARD_WITH_SWIG_MATLAB OFF)
set(DASHBOARD_WITH_SWIGMAKE ON)
set(DASHBOARD_WITH_TEXTBOOK OFF)
set(DASHBOARD_WITH_XFOIL OFF)
set(DASHBOARD_WITH_YALMIP OFF)
set(DASHBOARD_WITH_YAML_CPP ON)

if(WIN32)
  set(DASHBOARD_WITH_GTK ON)
else()
  set(DASHBOARD_WITH_MESHCONVERTERS ON)
  set(DASHBOARD_WITH_NLOPT ON)
  set(DASHBOARD_WITH_OCTOMAP ON)
  set(DASHBOARD_WITH_SIGNALSCOPE ON)
  set(DASHBOARD_WITH_SWIG_MATLAB ON)

  if(NOT "$ENV{openSource}" MATCHES "true")
    if(APPLE)
      set(DASHBOARD_GUROBI_DISTRO "$ENV{HOME}/gurobi6.0.5a_mac64.pkg")
    else()
      set(DASHBOARD_GUROBI_DISTRO "$ENV{HOME}/gurobi6.0.5_linux64.tar.gz")
    endif()
    if(EXISTS "${DASHBOARD_GUROBI_DISTRO}")
      set(DASHBOARD_WITH_GUROBI ON)
      set(ENV{GUROBI_DISTRO} "${DASHBOARD_GUROBI_DISTRO}")
    else()
      message(WARNING "*** GUROBI_DISTRO was not found")
    endif()
  endif()

  if("$ENV{matlab}" MATCHES "true")
    set(DASHBOARD_WITH_AVL ON)
    set(DASHBOARD_WITH_IRIS ON)
    set(DASHBOARD_WITH_TEXTBOOK ON)
    set(DASHBOARD_WITH_XFOIL ON)
    set(DASHBOARD_WITH_YALMIP ON)

    if(NOT "$ENV{openSource}" MATCHES "true")
      set(DASHBOARD_WITH_BERTINI ON)
      set(DASHBOARD_WITH_GLOPTIPOLY ON)
      set(DASHBOARD_WITH_MOSEK ON)
      set(DASHBOARD_WITH_SEDUMI ON)
    endif()
  endif()
endif()

if(WIN32 OR "$ENV{openSource}" MATCHES "true")
  set(DASHBOARD_WITH_SNOPT_PRECOMPILED ON)
else()
  set(DASHBOARD_WITH_SNOPT ON)
endif()

if("$ENV{matlab}" MATCHES "true")
  set(DASHBOARD_WITH_SPOTLESS ON)
endif()

set(CACHE_WITH_AVL "WITH_AVL:BOOL=${DASHBOARD_WITH_AVL}")
set(CACHE_WITH_BERTINI "WITH_BERTINI:BOOL=${DASHBOARD_WITH_BERTINI}")
set(CACHE_WITH_BOT_CORE_LCMTYPES
  "WITH_BOT_CORE_LCMTYPES:BOOL=${DASHBOARD_WITH_BOT_CORE_LCMTYPES}")
set(CACHE_WITH_BULLET "WITH_BULLET:BOOL=${DASHBOARD_WITH_BULLET}")
set(CACHE_WITH_EIGEN "WITH_EIGEN:BOOL=${DASHBOARD_WITH_EIGEN}")
set(CACHE_WITH_GLOPTIPOLY "WITH_GLOPTIPOLY:BOOL=${DASHBOARD_WITH_GLOPTIPOLY}")
set(CACHE_WITH_GOOGLETEST "WITH_GOOGLETEST:BOOL=${DASHBOARD_WITH_GOOGLETEST}")
set(CACHE_WITH_GTK "WITH_GTK:BOOL=${DASHBOARD_WITH_GTK}")
set(CACHE_WITH_GUROBI "WITH_GUROBI:BOOL=${DASHBOARD_WITH_GUROBI}")
set(CACHE_WITH_IRIS "WITH_IRIS:BOOL=${DASHBOARD_WITH_IRIS}")
set(CACHE_WITH_LCM "WITH_LCM:BOOL=${DASHBOARD_WITH_LCM}")
set(CACHE_WITH_MESHCONVERTERS
  "WITH_MESHCONVERTERS:BOOL=${DASHBOARD_WITH_MESHCONVERTERS}")
set(CACHE_WITH_MOSEK "WITH_MOSEK:BOOL=${DASHBOARD_WITH_MOSEK}")
set(CACHE_WITH_NLOPT "WITH_NLOPT:BOOL=${DASHBOARD_WITH_NLOPT}")
set(CACHE_WITH_OCTOMAP "WITH_OCTOMAP:BOOL=${DASHBOARD_WITH_OCTOMAP}")
set(CACHE_WITH_SEDUMI "WITH_SEDUMI:BOOL=${DASHBOARD_WITH_SEDUMI}")
set(CACHE_WITH_SIGNALSCOPE
  "WITH_SIGNALSCOPE:BOOL=${DASHBOARD_WITH_SIGNALSCOPE}")
set(CACHE_WITH_SNOPT "WITH_SNOPT:BOOL=${DASHBOARD_WITH_SNOPT}")
set(CACHE_WITH_SNOPT_PRECOMPILED
  "WITH_SNOPT_PRECOMPILED:BOOL=${DASHBOARD_WITH_SNOPT_PRECOMPILED}")
set(CACHE_WITH_SPOTLESS "WITH_SPOTLESS:BOOL=${DASHBOARD_WITH_SPOTLESS}")
set(CACHE_WITH_SWIG_MATLAB
  "WITH_SWIG_MATLAB:BOOL=${DASHBOARD_WITH_SWIG_MATLAB}")
set(CACHE_WITH_SWIGMAKE "WITH_SWIGMAKE:BOOL=${DASHBOARD_WITH_SWIGMAKE}")
set(CACHE_WITH_TEXTBOOK "WITH_TEXTBOOK:BOOL=${DASHBOARD_WITH_TEXTBOOK}")
set(CACHE_WITH_XFOIL "WITH_XFOIL:BOOL=${DASHBOARD_WITH_XFOIL}")
set(CACHE_WITH_YALMIP "WITH_YALMIP:BOOL=${DASHBOARD_WITH_YALMIP}")
set(CACHE_WITH_YAML_CPP "WITH_YAML_CPP:BOOL=${DASHBOARD_WITH_YAML_CPP}")

if(DEFINED ENV{BUILD_ID})
  set(DASHBOARD_LABEL "jenkins-${CTEST_BUILD_NAME}-$ENV{BUILD_ID}")
  set_property(GLOBAL PROPERTY Label "${DASHBOARD_LABEL}")
else()
  message(WARNING "*** ENV{BUILD_ID} was not set")
  set(DASHBOARD_LABEL "")
endif()

# set pull request id
if(DEFINED ENV{ghprbPullId})
  set(CTEST_CHANGE_ID "$ENV{ghprbPullId}")
  set(DASHBOARD_CHANGE_TITLE "$ENV{ghprbPullTitle}")
  string(LENGTH "${DASHBOARD_CHANGE_TITLE}" DASHBOARD_CHANGE_TITLE_LENGTH)
  if(DASHBOARD_CHANGE_TITLE_LENGTH GREATER 30)
    string(SUBSTRING "${DASHBOARD_CHANGE_TITLE}" 0 27
      DASHBOARD_CHANGE_TITLE_SUBSTRING)
    set(DASHBOARD_CHANGE_TITLE "${DASHBOARD_CHANGE_TITLE_SUBSTRING}...")
  endif()
  set(DASHBOARD_BUILD_DESCRIPTION
    "*** Build Description: <a title=\"$ENV{ghprbPullTitle}\" href=\"$ENV{ghprbPullLink}\">PR ${CTEST_CHANGE_ID}</a>: ${DASHBOARD_CHANGE_TITLE}")
  message("${DASHBOARD_BUILD_DESCRIPTION}")
endif()

message("
  ------------------------------------------------------------------------------
  CC                                  = $ENV{CC}
  CCC_CC                              = $ENV{CCC_CC}
  CCC_CXX                             = $ENV{CCC_CXX}
  CXX                                 = $ENV{CXX}
  FC                                  = $ENV{FC}
  ------------------------------------------------------------------------------
  CMAKE_C_FLAGS                      += ${DASHBOARD_C_FLAGS}
  CMAKE_C_INCLUDE_WHAT_YOU_USE        = ${DASHBOARD_C_INCLUDE_WHAT_YOU_USE}
  CMAKE_CXX_FLAGS                    += ${DASHBOARD_CXX_FLAGS}
  CMAKE_CXX_INCLUDE_WHAT_YOU_USE      = ${DASHBOARD_CXX_INCLUDE_WHAT_YOU_USE}
  CMAKE_CXX_STANDARD                  = ${DASHBOARD_CXX_STANDARD}
  CMAKE_CXX_STANDARD_REQUIRED         = ${DASHBOARD_CXX_STANDARD_REQUIRED}
  CMAKE_EXE_LINKER_FLAGS             += ${DASHBOARD_EXE_LINKER_FLAGS}
  CMAKE_Fortran_FLAGS                += ${DASHBOARD_FORTRAN_FLAGS}
  CMAKE_INSTALL_PREFIX                = ${DASHBOARD_INSTALL_PREFIX}
  CMAKE_POSITION_INDEPENDENT_CODE     = ${DASHBOARD_POSITION_INDEPENDENT_CODE}
  CMAKE_SHARED_LINKER_FLAGS          += ${DASHBOARD_SHARED_LINKER_FLAGS}
  CMAKE_STATIC_LINKER_FLAGS          += ${DASHBOARD_STATIC_LINKER_FLAGS}
  CMAKE_VERBOSE_MAKEFILE              = ${DASHBOARD_VERBOSE_MAKEFILE}
  ------------------------------------------------------------------------------
  CTEST_BUILD_COMMAND                 = ${CTEST_BUILD_COMMAND}
  CTEST_BUILD_NAME                    = ${CTEST_BUILD_NAME}
  CTEST_CHANGE_ID                     = ${CTEST_CHANGE_ID}
  CTEST_CMAKE_GENERATOR               = ${CTEST_CMAKE_GENERATOR}
  CTEST_CONFIGURATION_TYPE            = ${CTEST_CONFIGURATION_TYPE}
  CTEST_CONFIGURE_COMMAND             = ${CTEST_CONFIGURE_COMMAND}
  CTEST_COVERAGE_COMMAND              = ${CTEST_COVERAGE_COMMAND}
  CTEST_COVERAGE_EXTRA_FLAGS          = ${CTEST_COVERAGE_EXTRA_FLAGS}
  CTEST_GIT_COMMAND                   = ${CTEST_GIT_COMMAND}
  CTEST_MEMORYCHECK_COMMAND           = ${CTEST_MEMORYCHECK_COMMAND}
  CTEST_MEMORYCHECK_COMMAND_OPTIONS   = ${CTEST_MEMORYCHECK_COMMAND_OPTIONS}
  CTEST_MEMORYCHECK_SUPPRESSIONS_FILE = ${CTEST_MEMORYCHECK_SUPPRESSIONS_FILE}
  CTEST_MEMORYCHECK_TYPE              = ${CTEST_MEMORYCHECK_TYPE}
  CTEST_SITE                          = ${CTEST_SITE}
  CTEST_TEST_TIMEOUT                  = ${CTEST_TEST_TIMEOUT}
  CTEST_UPDATE_COMMAND                = ${CTEST_UPDATE_COMMAND}
  CTEST_UPDATE_VERSION_ONLY           = ${CTEST_UPDATE_VERSION_ONLY}
  CTEST_USE_LAUNCHERS                 = ${CTEST_USE_LAUNCHERS}
  ------------------------------------------------------------------------------
  BUILD_DOCUMENTATION                 = ${DASHBOARD_BUILD_DOCUMENTATION}
  LONG_RUNNING_TESTS                  = ${DASHBOARD_LONG_RUNNING_TESTS}
  ------------------------------------------------------------------------------
  WITH_AVL                            = ${DASHBOARD_WITH_AVL}
  WITH_BERTINI                        = ${DASHBOARD_WITH_BERTINI}
  WITH_BOT_CORE_LCMTYPES              = ${DASHBOARD_WITH_BOT_CORE_LCMTYPES}
  WITH_BULLET                         = ${DASHBOARD_WITH_BULLET}
  WITH_EIGEN                          = ${DASHBOARD_WITH_EIGEN}
  WITH_GLOPTIPOLY                     = ${DASHBOARD_WITH_GLOPTIPOLY}
  WITH_GOOGLETEST                     = ${DASHBOARD_WITH_GOOGLETEST}
  WITH_GTK                            = ${DASHBOARD_WITH_GTK}
  WITH_GUROBI                         = ${DASHBOARD_WITH_GUROBI}
  WITH_IRIS                           = ${DASHBOARD_WITH_IRIS}
  WITH_LCM                            = ${DASHBOARD_WITH_LCM}
  WITH_MESHCONVERTERS                 = ${DASHBOARD_WITH_MESHCONVERTERS}
  WITH_MOSEK                          = ${DASHBOARD_WITH_MOSEK}
  WITH_NLOPT                          = ${DASHBOARD_WITH_NLOPT}
  WITH_OCTOMAP                        = ${DASHBOARD_WITH_OCTOMAP}
  WITH_SEDUMI                         = ${DASHBOARD_WITH_SEDUMI}
  WITH_SIGNALSCOPE                    = ${DASHBOARD_WITH_SIGNALSCOPE}
  WITH_SNOPT                          = ${DASHBOARD_WITH_SNOPT}
  WITH_SNOPT_PRECOMPILED              = ${DASHBOARD_WITH_SNOPT_PRECOMPILED}
  WITH_SPOTLESS                       = ${DASHBOARD_WITH_SPOTLESS}
  WITH_SWIG_MATLAB                    = ${DASHBOARD_WITH_SWIG_MATLAB}
  WITH_SWIGMAKE                       = ${DASHBOARD_WITH_SWIGMAKE}
  WITH_TEXTBOOK                       = ${DASHBOARD_WITH_TEXTBOOK}
  WITH_XFOIL                          = ${DASHBOARD_WITH_XFOIL}
  WITH_YALMIP                         = ${DASHBOARD_WITH_YALMIP}
  WITH_YAML_CPP                       = ${DASHBOARD_WITH_YAML_CPP}
  ------------------------------------------------------------------------------
  ")

set(DASHBOARD_CDASH_SERVER "drake-cdash.csail.mit.edu")
set(DASHBOARD_NIGHTLY_START_TIME "00:00:00 EST")

if(DASHBOARD_CONFIGURE_AND_BUILD_SUPERBUILD)
  set(DASHBOARD_SUPERBUILD_PROJECT_NAME "drake-superbuild")

  set(CTEST_PROJECT_NAME "${DASHBOARD_SUPERBUILD_PROJECT_NAME}")
  set(CTEST_NIGHTLY_START_TIME "${DASHBOARD_NIGHTLY_START_TIME}")
  set(CTEST_DROP_METHOD "https")
  set(CTEST_DROP_SITE "${DASHBOARD_CDASH_SERVER}")
  set(CTEST_DROP_LOCATION
    "/submit.php?project=${DASHBOARD_SUPERBUILD_PROJECT_NAME}")
  set(CTEST_DROP_SITE_CDASH ON)

set(DASHBOARD_SUPERBUILD_START_MESSAGE
  "*** CTest Status: CONFIGURING / BUILDING SUPERBUILD")

message("
  ------------------------------------------------------------------------------
  ${DASHBOARD_SUPERBUILD_START_MESSAGE}
  ------------------------------------------------------------------------------
  ")

  ctest_start("${DASHBOARD_MODEL}" TRACK "${DASHBOARD_TRACK}" QUIET)
  ctest_update(SOURCE "${CTEST_SOURCE_DIRECTORY}" QUIET)

  set(CACHE_DRAKE_ADDITIONAL_BUILD_ARGS
    "drake_ADDITIONAL_BUILD_ARGS:STRING=BUILD_COMMAND;${CMAKE_COMMAND};-E;echo;INSTALL_COMMAND;${CMAKE_COMMAND};-E;echo")

  # write initial cache
  file(WRITE "${CTEST_BINARY_DIRECTORY}/CMakeCache.txt" "
${CACHE_DRAKE_ADDITIONAL_BUILD_ARGS}
${CACHE_BUILD_DOCUMENTATION}
${CACHE_C_FLAGS}
${CACHE_CXX_FLAGS}
${CACHE_CXX_STANDARD_REQUIRED}
${CACHE_CXX_STANDARD}
${CACHE_EXE_LINKER_FLAGS}
${CACHE_FORTRAN_FLAGS}
${CACHE_INSTALL_PREFIX}
${CACHE_POSITION_INDEPENDENT_CODE}
${CACHE_SHARED_LINKER_FLAGS}
${CACHE_STATIC_LINKER_FLAGS}
${CACHE_VERBOSE_MAKEFILE}
${CACHE_LONG_RUNNING_TESTS}
${CACHE_WITH_AVL}
${CACHE_WITH_BERTINI}
${CACHE_WITH_BOT_CORE_LCMTYPES}
${CACHE_WITH_BULLET}
${CACHE_WITH_EIGEN}
${CACHE_WITH_GLOPTIPOLY}
${CACHE_WITH_GOOGLETEST}
${CACHE_WITH_GTK}
${CACHE_WITH_GUROBI}
${CACHE_WITH_IRIS}
${CACHE_WITH_LCM}
${CACHE_WITH_MESHCONVERTERS}
${CACHE_WITH_MOSEK}
${CACHE_WITH_NLOPT}
${CACHE_WITH_OCTOMAP}
${CACHE_WITH_SEDUMI}
${CACHE_WITH_SIGNALSCOPE}
${CACHE_WITH_SNOPT_PRECOMPILED}
${CACHE_WITH_SNOPT}
${CACHE_WITH_SPOTLESS}
${CACHE_WITH_SWIG_MATLAB}
${CACHE_WITH_SWIGMAKE}
${CACHE_WITH_TEXTBOOK}
${CACHE_WITH_XFOIL}
${CACHE_WITH_YALMIP}
${CACHE_WITH_YAML_CPP}
  ")

  ctest_configure(BUILD "${CTEST_BINARY_DIRECTORY}"
    SOURCE "${CTEST_SOURCE_DIRECTORY}"
    RETURN_VALUE DASHBOARD_SUPERBUILD_CONFIGURE_RETURN_VALUE QUIET)
  ctest_build(BUILD "${CTEST_BINARY_DIRECTORY}" APPEND
    NUMBER_ERRORS DASHBOARD_SUPERBUILD_NUMBER_BUILD_ERRORS QUIET)

  set(DASHBOARD_BUILD_URL_FILE
    "${CTEST_BINARY_DIRECTORY}/${CTEST_BUILD_NAME}.url")
  file(WRITE "${DASHBOARD_BUILD_URL_FILE}" "$ENV{BUILD_URL}")
  ctest_upload(FILES "${DASHBOARD_BUILD_URL_FILE}" QUIET)

  ctest_submit(QUIET)
endif()

set(DASHBOARD_PROJECT_NAME "Drake")

# now start the actual drake build
set(CTEST_SOURCE_DIRECTORY "${DASHBOARD_WORKSPACE}/drake")
set(CTEST_BINARY_DIRECTORY "${DASHBOARD_WORKSPACE}/drake/pod-build")

# switch the dashboard to the drake only dashboard
set(CTEST_PROJECT_NAME "${DASHBOARD_PROJECT_NAME}")
set(CTEST_NIGHTLY_START_TIME "${DASHBOARD_NIGHTLY_START_TIME}")
set(CTEST_DROP_METHOD "https")
set(CTEST_DROP_SITE "${DASHBOARD_CDASH_SERVER}")
set(CTEST_DROP_LOCATION "/submit.php?project=${DASHBOARD_PROJECT_NAME}")
set(CTEST_DROP_SITE_CDASH ON)

# clean out the old builds
file(REMOVE_RECURSE "${CTEST_BINARY_DIRECTORY}")
file(MAKE_DIRECTORY "${CTEST_BINARY_DIRECTORY}")

if("$ENV{compiler}" MATCHES "scan-build")
  file(MAKE_DIRECTORY "${DASHBOARD_CCC_ANALYZER_HTML}")
endif()

set(DASHBOARD_STEPS "")
if(DASHBOARD_CONFIGURE)
  list(APPEND DASHBOARD_STEPS "CONFIGURING")
endif()
list(APPEND DASHBOARD_STEPS "BUILDING")
if(DASHBOARD_INSTALL)
  list(APPEND DASHBOARD_STEPS "INSTALLING")
endif()
if(DASHBOARD_TEST)
  list(APPEND DASHBOARD_STEPS "TESTING")
endif()
string(REPLACE ";" " / " DASHBOARD_STEPS_STRING "${DASHBOARD_STEPS}")
set(DASHBOARD_START_MESSAGE "*** CTest Status: ${DASHBOARD_STEPS_STRING} DRAKE")

message("
  ------------------------------------------------------------------------------
  ${DASHBOARD_START_MESSAGE}
  ------------------------------------------------------------------------------
  ")

ctest_start("${DASHBOARD_MODEL}" TRACK "${DASHBOARD_TRACK}" QUIET)
ctest_update(SOURCE "${CTEST_SOURCE_DIRECTORY}" QUIET)

if(DASHBOARD_CONFIGURE)
  # write initial cache
  file(WRITE "${CTEST_BINARY_DIRECTORY}/CMakeCache.txt" "
${CACHE_BUILD_DOCUMENTATION}
${CACHE_C_FLAGS}
${CACHE_C_INCLUDE_WHAT_YOU_USE}
${CACHE_CXX_FLAGS}
${CACHE_CXX_INCLUDE_WHAT_YOU_USE}
${CACHE_CXX_STANDARD_REQUIRED}
${CACHE_CXX_STANDARD}
${CACHE_EXE_LINKER_FLAGS}
${CACHE_FORTRAN_FLAGS}
${CACHE_INSTALL_PREFIX}
${CACHE_POSITION_INDEPENDENT_CODE}
${CACHE_SHARED_LINKER_FLAGS}
${CACHE_STATIC_LINKER_FLAGS}
${CACHE_VERBOSE_MAKEFILE}
${CACHE_LONG_RUNNING_TESTS}
${CACHE_WITH_AVL}
${CACHE_WITH_BERTINI}
${CACHE_WITH_BOT_CORE_LCMTYPES}
${CACHE_WITH_BULLET}
${CACHE_WITH_EIGEN}
${CACHE_WITH_GLOPTIPOLY}
${CACHE_WITH_GOOGLETEST}
${CACHE_WITH_GTK}
${CACHE_WITH_GUROBI}
${CACHE_WITH_IRIS}
${CACHE_WITH_LCM}
${CACHE_WITH_MESHCONVERTERS}
${CACHE_WITH_MOSEK}
${CACHE_WITH_NLOPT}
${CACHE_WITH_OCTOMAP}
${CACHE_WITH_SEDUMI}
${CACHE_WITH_SIGNALSCOPE}
${CACHE_WITH_SNOPT_PRECOMPILED}
${CACHE_WITH_SNOPT}
${CACHE_WITH_SPOTLESS}
${CACHE_WITH_SWIG_MATLAB}
${CACHE_WITH_SWIGMAKE}
${CACHE_WITH_TEXTBOOK}
${CACHE_WITH_XFOIL}
${CACHE_WITH_YALMIP}
${CACHE_WITH_YAML_CPP}
  ")

  ctest_configure(BUILD "${CTEST_BINARY_DIRECTORY}"
    SOURCE "${CTEST_SOURCE_DIRECTORY}"
    RETURN_VALUE DASHBOARD_CONFIGURE_RETURN_VALUE QUIET)
endif()

ctest_read_custom_files("${CTEST_BINARY_DIRECTORY}")

if("$ENV{compiler}" MATCHES "cpplint")
  set(CTEST_CUSTOM_MAXIMUM_NUMBER_OF_ERRORS 1000)
  set(CTEST_CUSTOM_MAXIMUM_NUMBER_OF_WARNINGS 1000)

  set(CTEST_CUSTOM_ERROR_MATCH
    "Total errors found: [1-9]"
    ${CTEST_CUSTOM_ERROR_MATCH}
  )
elseif("$ENV{compiler}" MATCHES "include-what-you-use")
  set(CTEST_CUSTOM_MAXIMUM_NUMBER_OF_ERRORS 1000)
  set(CTEST_CUSTOM_MAXIMUM_NUMBER_OF_WARNINGS 1000)
else()
  set(CTEST_CUSTOM_MAXIMUM_NUMBER_OF_ERRORS 100)
  set(CTEST_CUSTOM_MAXIMUM_NUMBER_OF_WARNINGS 100)
endif()

if("$ENV{matlab}" MATCHES "true")
  set(CTEST_CUSTOM_MAXIMUM_FAILED_TEST_OUTPUT_SIZE 307200)
  set(CTEST_CUSTOM_MAXIMUM_PASSED_TEST_OUTPUT_SIZE 307200)
endif()

ctest_build(APPEND NUMBER_ERRORS DASHBOARD_NUMBER_BUILD_ERRORS
  NUMBER_WARNINGS DASHBOARD_NUMBER_BUILD_WARNINGS QUIET)
ctest_submit(PARTS Build QUIET)

if(DASHBOARD_INSTALL)
  ctest_build(TARGET "install" APPEND
    RETURN_VALUE DASHBOARD_INSTALL_RETURN_VALUE QUIET)
endif()

if(DASHBOARD_TEST)
  ctest_test(BUILD "${CTEST_BINARY_DIRECTORY}" ${CTEST_TEST_ARGS}
    RETURN_VALUE DASHBOARD_TEST_RETURN_VALUE QUIET)
endif()

if(DASHBOARD_COVERAGE)
  ctest_coverage(RETURN_VALUE DASHBOARD_COVERAGE_RETURN_VALUE QUIET)
endif()

if(DASHBOARD_MEMCHECK)
  ctest_memcheck(RETURN_VALUE DASHBOARD_MEMCHECK_RETURN_VALUE QUIET)
endif()

# upload the Jenkins job URL to add link on CDash
set(DASHBOARD_BUILD_URL_FILE
  "${CTEST_BINARY_DIRECTORY}/${CTEST_BUILD_NAME}.url")
file(WRITE "${DASHBOARD_BUILD_URL_FILE}" "$ENV{BUILD_URL}")
ctest_upload(FILES "${DASHBOARD_BUILD_URL_FILE}" QUIET)

ctest_submit(QUIET)

set(DASHBOARD_FAILURE OFF)
set(DASHBOARD_FAILURES "")

if(DASHBOARD_CONFIGURE_AND_BUILD_SUPERBUILD)
  if(NOT DASHBOARD_SUPERBUILD_CONFIGURE_RETURN_VALUE EQUAL 0)
    set(DASHBOARD_FAILURE ON)
    list(APPEND DASHBOARD_FAILURES "CONFIGURE SUPERBUILD")
  endif()

  if(DASHBOARD_SUPERBUILD_NUMBER_BUILD_ERRORS GREATER 0)
    set(DASHBOARD_FAILURE ON)
    list(APPEND DASHBOARD_FAILURES "BUILD SUPERBUILD")
  endif()

endif()

if(DASHBOARD_CONFIGURE AND NOT DASHBOARD_CONFIGURE_RETURN_VALUE EQUAL 0)
  set(DASHBOARD_FAILURE ON)
  list(APPEND DASHBOARD_FAILURES "CONFIGURE")
endif()

if(DASHBOARD_NUMBER_BUILD_ERRORS GREATER 0)
  set(DASHBOARD_FAILURE ON)
  list(APPEND DASHBOARD_FAILURES "BUILD")
endif()

if(DASHBOARD_INSTALL AND NOT DASHBOARD_INSTALL_RETURN_VALUE EQUAL 0)
  set(DASHBOARD_FAILURE ON)
  list(APPEND DASHBOARD_FAILURES "INSTALL")
endif()

if(DASHBOARD_FAILURE)
  string(REPLACE ";" " / " DASHBOARD_FAILURES_STRING "${DASHBOARD_FAILURES}")
  set(DASHBOARD_MESSAGE "FAILURE DURING ${DASHBOARD_FAILURES_STRING}")
  file(WRITE "${DASHBOARD_WORKSPACE}/FAILURE")
else()
  if(DASHBOARD_NUMBER_BUILD_WARNINGS GREATER 0)
    set(DASHBOARD_MESSAGE "SUCCESS BUT WITH BUILD WARNINGS: ${DASHBOARD_NUMBER_BUILD_WARNINGS}")
  else()
    set(DASHBOARD_MESSAGE "SUCCESS")
  endif()

  set(DASHBOARD_UNSTABLE OFF)
  set(DASHBOARD_UNSTABLES "")

  if(DASHBOARD_TEST AND NOT DASHBOARD_TEST_RETURN_VALUE EQUAL 0)
    set(DASHBOARD_UNSTABLE ON)
    list(APPEND DASHBOARD_UNSTABLES "TEST")
  endif()

  if(DASHBOARD_COVERAGE AND NOT DASHBOARD_COVERAGE_RETURN_VALUE EQUAL 0)
    set(DASHBOARD_UNSTABLE ON)
    list(APPEND DASHBOARD_UNSTABLES "COVERAGE TOOL")
  endif()

  if(DASHBOARD_MEMCHECK AND NOT DASHBOARD_MEMCHECK_RETURN_VALUE EQUAL 0)
    set(DASHBOARD_UNSTABLE ON)
    list(APPEND DASHBOARD_UNSTABLES "MEMCHECK TOOL")
  endif()

  if(DASHBOARD_UNSTABLE)
    string(REPLACE ";" " / " DASHBOARD_UNSTABLES_STRING "${DASHBOARD_UNSTABLES}")
    set(DASHBOARD_MESSAGE
      "UNSTABLE DUE TO ${DASHBOARD_UNSTABLES_STRING} FAILURES")
    file(WRITE "${DASHBOARD_WORKSPACE}/UNSTABLE")
  else()
    file(WRITE "${DASHBOARD_WORKSPACE}/SUCCESS")
  endif()
endif()

set(DASHBOARD_MESSAGE "*** CTest Result: ${DASHBOARD_MESSAGE}")

if(DASHBOARD_CONFIGURE_AND_BUILD_SUPERBUILD AND DASHBOARD_LABEL)
  set(DASHBOARD_CDASH_SUPERBUILD_URL_MESSAGE
    "*** CDash Superbuild URL: https://${DASHBOARD_CDASH_SERVER}/index.php?project=${DASHBOARD_SUPERBUILD_PROJECT_NAME}&showfilters=1&filtercount=2&showfilters=1&filtercombine=and&field1=label&compare1=61&value1=${DASHBOARD_LABEL}&field2=buildstarttime&compare2=84&value2=now")
else()
  set(DASHBOARD_CDASH_SUPERBUILD_URL_MESSAGE "*** CDash Superbuild URL:")
endif()

if(DASHBOARD_LABEL)
  set(DASHBOARD_CDASH_URL_MESSAGE
    "*** CDash URL: https://${DASHBOARD_CDASH_SERVER}/index.php?project=${DASHBOARD_PROJECT_NAME}&showfilters=1&filtercount=2&showfilters=1&filtercombine=and&field1=label&compare1=61&value1=${DASHBOARD_LABEL}&field2=buildstarttime&compare2=84&value2=now")
else()
  set(DASHBOARD_CDASH_URL_MESSAGE "*** CDash URL:")
endif()

message("
  ------------------------------------------------------------------------------
  ${DASHBOARD_MESSAGE}
  ------------------------------------------------------------------------------
  ${DASHBOARD_CDASH_SUPERBUILD_URL_MESSAGE}
  ------------------------------------------------------------------------------
  ${DASHBOARD_CDASH_URL_MESSAGE}
  ------------------------------------------------------------------------------
  ")

if(DASHBOARD_FAILURE)
  message(FATAL_ERROR
    "*** Return value set to NON-ZERO due to failure during build")
endif()
