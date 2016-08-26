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

add_package(AVL                 OFF)
add_package(BERTINI             OFF)
add_package(BOT_CORE_LCMTYPES   ON)
add_package(BULLET              ON)
add_package(CMAKE               ON)
add_package(DIRECTOR            OFF)
add_package(DRAKE               ON)
add_package(DREAL               ON)
add_package(EIGEN               ON)
add_package(GFLAGS              ON)
add_package(GLOPTIPOLY          OFF)
add_package(GOOGLETEST          ON)
add_package(GOOGLE_STYLEGUIDE   ON)
add_package(GTK                 OFF)
add_package(GUROBI              OFF)
add_package(IPOPT               OFF)
add_package(IRIS                OFF)
add_package(LCM                 ON)
add_package(LIBBOT              OFF)
add_package(MESHCONVERTERS      OFF)
add_package(MOSEK               OFF)
add_package(NLOPT               OFF)
add_package(OCTOMAP             OFF)
add_package(SEDUMI              OFF)
add_package(SIGNALSCOPE         OFF)
add_package(SNOPT               OFF)
add_package(SNOPT_PRECOMPILED   OFF)
add_package(SPDLOG              ON)
add_package(SPOTLESS            OFF)
add_package(SWIGMAKE            ON)
add_package(SWIG_MATLAB         OFF)
add_package(TEXTBOOK            OFF)
add_package(XFOIL               OFF)
add_package(YALMIP              OFF)
add_package(YAML_CPP            ON)

if(COMPILER STREQUAL "cpplint")
  disable_package(BOT_CORE_LCMTYPES)
  disable_package(BULLET)
  disable_package(CMAKE)
  disable_package(DRAKE)
  disable_package(DREAL)
  disable_package(EIGEN)
  disable_package(GFLAGS)
  disable_package(GOOGLETEST)
  disable_package(LCM)
  disable_package(SPDLOG)
  disable_package(SWIGMAKE)
  disable_package(YAML_CPP)
elseif(MINIMAL)
  disable_package(BOT_CORE_LCMTYPES)
  disable_package(BULLET)
  disable_package(DREAL)
  disable_package(GOOGLE_STYLEGUIDE)
  disable_package(LCM)
  disable_package(SPDLOG)
  disable_package(SWIGMAKE)
  disable_package(YAML_CPP)
else()
  if(WIN32)
    disable_package(DREAL)
    disable_package(GOOGLE_STYLEGUIDE)
    enable_package(GTK)
  else()
    enable_package(DIRECTOR)
    enable_package(LIBBOT)
    enable_package(MESHCONVERTERS)
    enable_package(NLOPT)
    if(NOT APPLE)
      enable_package(IPOPT)
    endif()
    enable_package(OCTOMAP)
    enable_package(SIGNALSCOPE)
    enable_package(SWIG_MATLAB)

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
      enable_package(AVL)
      enable_package(TEXTBOOK)
      enable_package(XFOIL)
      enable_package(YALMIP)

      if(NOT OPEN_SOURCE)
        enable_package(BERTINI)
        enable_package(GLOPTIPOLY)
        enable_package(IRIS)
        enable_package(SEDUMI)
      endif()
    endif()
  endif()

  if(WIN32 OR OPEN_SOURCE)
    enable_package(SNOPT_PRECOMPILED)
  else()
    enable_package(SNOPT)
  endif()

  if(MATLAB)
    enable_package(SPOTLESS)
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
