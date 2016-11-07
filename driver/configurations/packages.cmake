set(DASHBOARD_PACKAGES "")

macro(add_package NAME ENABLED)
  set(DASHBOARD_WITH_${NAME} ${ENABLED})
  list(APPEND DASHBOARD_PACKAGES ${NAME})
endmacro()

macro(enable_package NAME)
  set(DASHBOARD_WITH_${NAME} ON)
endmacro()

macro(disable_package NAME)
  set(DASHBOARD_WITH_${NAME} OFF)
endmacro()

add_package(AVL                       OFF)
add_package(BOT_CORE_LCMTYPES         ON)
add_package(BULLET                    ON)
add_package(DIRECTOR                  ON)
add_package(DRAKE                     ON)
add_package(DREAL                     ON)
add_package(EIGEN                     ON)
add_package(FCL                       ON)
add_package(GFLAGS                    ON)
add_package(GOOGLETEST                ON)
add_package(GOOGLE_STYLEGUIDE         ON)
add_package(GUROBI                    OFF)
add_package(IPOPT                     ON)
add_package(IRIS                      OFF)
add_package(LCM                       ON)
add_package(LIBBOT                    ON)
add_package(LIBCCD                    ON)
add_package(MESHCONVERTERS            OFF)
add_package(MOSEK                     OFF)
add_package(NLOPT                     ON)
add_package(OCTOMAP                   ON)
add_package(ROBOTLOCOMOTION_LCMTYPES  ON)
add_package(SEDUMI                    OFF)
add_package(SIGNALSCOPE               OFF)
add_package(SNOPT                     OFF)
add_package(SPDLOG                    ON)
add_package(SPOTLESS                  OFF)
add_package(SWIGMAKE                  ON)
add_package(SWIG_MATLAB               ON)
add_package(TEXTBOOK                  OFF)
add_package(XFOIL                     OFF)
add_package(YALMIP                    OFF)
add_package(YAML_CPP                  ON)

if(MINIMAL)
  disable_package(BOT_CORE_LCMTYPES)
  disable_package(BULLET)
  disable_package(DIRECTOR)
  disable_package(DREAL)
  disable_package(FCL)
  disable_package(GOOGLE_STYLEGUIDE)
  disable_package(IPOPT)
  disable_package(LCM)
  disable_package(LIBBOT)
  disable_package(LIBCCD)
  disable_package(NLOPT)
  disable_package(OCTOMAP)
  disable_package(ROBOTLOCOMOTION_LCMTYPES)
  disable_package(SPDLOG)
  disable_package(SWIG_MATLAB)
  disable_package(SWIGMAKE)
  disable_package(YAML_CPP)
else()
  enable_package(MESHCONVERTERS)
  enable_package(SIGNALSCOPE)
  enable_package(TEXTBOOK)

  if(COVERAGE)
    disable_package(GOOGLE_STYLEGUIDE)
  endif()

  if(MEMCHECK)
    disable_package(GOOGLE_STYLEGUIDE)
    disable_package(SWIG_MATLAB)
    disable_package(SWIGMAKE)
  endif()

  if(MEMCHECK STREQUAL "msan" OR COMPILER MATCHES "^scan-build")
    disable_package(IPOPT)
  endif()

  if(NOT COVERAGE AND NOT MEMCHECK MATCHES "^[amt]san$" OR NOT COMPILER MATCHES "^(clang|scan-build)")
    enable_package(AVL)
    enable_package(XFOIL)
  endif()

  if(NOT OPEN_SOURCE)
    if(APPLE)
      set(DASHBOARD_GUROBI_DISTRO "$ENV{HOME}/gurobi6.0.5a_mac64.pkg")
    else()
      set(DASHBOARD_GUROBI_DISTRO "$ENV{HOME}/gurobi6.0.5_linux64.tar.gz")
    endif()
    if(EXISTS "${DASHBOARD_GUROBI_DISTRO}")
      enable_package(GUROBI)
      set(ENV{GUROBI_DISTRO} "${DASHBOARD_GUROBI_DISTRO}")
    else()
      message(WARNING "*** GUROBI_DISTRO was not found")
    endif()
    enable_package(MOSEK)
  endif()

  if(MATLAB)
    enable_package(SPOTLESS)
    enable_package(YALMIP)

    if(APPLE)
      disable_package(IPOPT)
    endif()

    if(NOT OPEN_SOURCE)
      enable_package(IRIS)
      enable_package(SEDUMI)
    endif()
  endif()

  if(NOT OPEN_SOURCE)
    enable_package(SNOPT)
  endif()

  if(MEMCHECK MATCHES "^[amt]san$")
    disable_package(DIRECTOR)
    disable_package(LIBBOT)
  endif()
endif()

foreach(_package ${DASHBOARD_PACKAGES})
  set(CACHE_WITH_${_package}
    "WITH_${_package}:BOOL=${DASHBOARD_WITH_${_package}}")
endforeach()
