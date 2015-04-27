#[=======================================================================[.rst:
CTest
-----

Configure a project for testing with CTest/CDash

Include this module in the top CMakeLists.txt file of a project to
enable testing with CTest and dashboard submissions to CDash::

  project(MyProject)
  ...
  include(CTest)

The module automatically creates a ``BUILD_TESTING`` option that selects
whether to enable testing support (``ON`` by default).  After including
the module, use code like::

  if(BUILD_TESTING)
    # ... CMake code to create tests ...
  endif()

to creating tests when testing is enabled.

To enable submissions to a CDash server, create a ``CTestConfig.cmake``
file at the top of the project with content such as::

  set(CTEST_PROJECT_NAME "MyProject")
  set(CTEST_NIGHTLY_START_TIME "01:00:00 UTC")
  set(CTEST_DROP_METHOD "http")
  set(CTEST_DROP_SITE "my.cdash.org")
  set(CTEST_DROP_LOCATION "/submit.php?project=MyProject")
  set(CTEST_DROP_SITE_CDASH TRUE)

(the CDash server can provide the file to a project administrator who
configures ``MyProject``).  Settings in the config file are shared by
both this ``CTest`` module and the :manual:`ctest(1)` command-line
:ref:`Dashboard Client` mode (``ctest -S``).

While building a project for submission to CDash, CTest scans the
build output for errors and warnings and reports them with surrounding
context from the build log.  This generic approach works for all build
tools, but does not give details about the command invocation that
produced a given problem.  One may get more detailed reports by adding::

  set(CTEST_USE_LAUNCHERS 1)

to the ``CTestConfig.cmake`` file.  When this option is enabled, the CTest
module tells CMake's Makefile generators to invoke every command in
the generated build system through a CTest launcher program.
(Currently the ``CTEST_USE_LAUNCHERS`` option is ignored on non-Makefile
generators.) During a manual build each launcher transparently runs
the command it wraps.  During a CTest-driven build for submission to
CDash each launcher reports detailed information when its command
fails or warns.  (Setting ``CTEST_USE_LAUNCHERS`` in ``CTestConfig.cmake`` is
convenient, but also adds the launcher overhead even for manual
builds.  One may instead set it in a CTest dashboard script and add it
to the CMake cache for the build tree.)
#]=======================================================================]

#=============================================================================
# Copyright 2005-2009 Kitware, Inc.
#
# Distributed under the OSI-approved BSD License (the "License");
# see accompanying file Copyright.txt for details.
#
# This software is distributed WITHOUT ANY WARRANTY; without even the
# implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
# See the License for more information.
#=============================================================================
# (To distribute this file outside of CMake, substitute the full
#  License text for the above reference.)

option(BUILD_TESTING "Build the testing tree." ON)

# function to turn generator name into a version string
# like vs7 vs71 vs8 vs9
function(GET_VS_VERSION_STRING generator var)
  string(REGEX REPLACE "Visual Studio ([0-9][0-9]?)($|.*)" "\\1"
    NUMBER "${generator}")
  if("${generator}" MATCHES "Visual Studio 7 .NET 2003")
    set(ver_string "vs71")
  else()
    set(ver_string "vs${NUMBER}")
  endif()
  set(${var} ${ver_string} PARENT_SCOPE)
endfunction()

include(CTestUseLaunchers)

if(BUILD_TESTING)
  # Setup some auxilary macros
  macro(SET_IF_NOT_SET var val)
    if(NOT DEFINED "${var}")
      set("${var}" "${val}")
    endif()
  endmacro()

  macro(SET_IF_SET var val)
    if(NOT "${val}" STREQUAL "")
      set("${var}" "${val}")
    endif()
  endmacro()

  macro(SET_IF_SET_AND_NOT_SET var val)
    if(NOT "${val}" STREQUAL "")
      SET_IF_NOT_SET("${var}" "${val}")
    endif()
  endmacro()

  # Make sure testing is enabled
  enable_testing()

  if(EXISTS "${PROJECT_SOURCE_DIR}/CTestConfig.cmake")
    include("${PROJECT_SOURCE_DIR}/CTestConfig.cmake")
    SET_IF_SET_AND_NOT_SET(NIGHTLY_START_TIME "${CTEST_NIGHTLY_START_TIME}")
    SET_IF_SET_AND_NOT_SET(DROP_METHOD "${CTEST_DROP_METHOD}")
    SET_IF_SET_AND_NOT_SET(DROP_SITE "${CTEST_DROP_SITE}")
    SET_IF_SET_AND_NOT_SET(DROP_SITE_USER "${CTEST_DROP_SITE_USER}")
    SET_IF_SET_AND_NOT_SET(DROP_SITE_PASSWORD "${CTEST_DROP_SITE_PASWORD}")
    SET_IF_SET_AND_NOT_SET(DROP_SITE_MODE "${CTEST_DROP_SITE_MODE}")
    SET_IF_SET_AND_NOT_SET(DROP_LOCATION "${CTEST_DROP_LOCATION}")
    SET_IF_SET_AND_NOT_SET(TRIGGER_SITE "${CTEST_TRIGGER_SITE}")
    SET_IF_SET_AND_NOT_SET(UPDATE_TYPE "${CTEST_UPDATE_TYPE}")
  endif()

  # the project can have a DartConfig.cmake file
  if(EXISTS "${PROJECT_SOURCE_DIR}/DartConfig.cmake")
    include("${PROJECT_SOURCE_DIR}/DartConfig.cmake")
  else()
    # Dashboard is opened for submissions for a 24 hour period starting at
    # the specified NIGHTLY_START_TIME. Time is specified in 24 hour format.
    SET_IF_NOT_SET (NIGHTLY_START_TIME "00:00:00 EDT")
    SET_IF_NOT_SET(DROP_METHOD "http")
    SET_IF_NOT_SET (COMPRESS_SUBMISSION ON)
  endif()
  SET_IF_NOT_SET (NIGHTLY_START_TIME "00:00:00 EDT")

  find_program(CVSCOMMAND cvs )
  set(CVS_UPDATE_OPTIONS "-d -A -P" CACHE STRING
    "Options passed to the cvs update command.")
  find_program(SVNCOMMAND svn)
  find_program(BZRCOMMAND bzr)
  find_program(HGCOMMAND hg)
  find_program(GITCOMMAND git)
  find_program(P4COMMAND p4)

  if(NOT UPDATE_TYPE)
    if(EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/CVS")
      set(UPDATE_TYPE cvs)
    elseif(EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/.svn")
      set(UPDATE_TYPE svn)
    elseif(EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/.bzr")
      set(UPDATE_TYPE bzr)
    elseif(EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/.hg")
      set(UPDATE_TYPE hg)
    elseif(EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/.git")
      set(UPDATE_TYPE git)
    endif()
  endif()

  string(TOLOWER "${UPDATE_TYPE}" _update_type)
  if("${_update_type}" STREQUAL "cvs")
    set(UPDATE_COMMAND "${CVSCOMMAND}")
    set(UPDATE_OPTIONS "${CVS_UPDATE_OPTIONS}")
  elseif("${_update_type}" STREQUAL "svn")
    set(UPDATE_COMMAND "${SVNCOMMAND}")
    set(UPDATE_OPTIONS "${SVN_UPDATE_OPTIONS}")
  elseif("${_update_type}" STREQUAL "bzr")
    set(UPDATE_COMMAND "${BZRCOMMAND}")
    set(UPDATE_OPTIONS "${BZR_UPDATE_OPTIONS}")
  elseif("${_update_type}" STREQUAL "hg")
    set(UPDATE_COMMAND "${HGCOMMAND}")
    set(UPDATE_OPTIONS "${HG_UPDATE_OPTIONS}")
  elseif("${_update_type}" STREQUAL "git")
    set(UPDATE_COMMAND "${GITCOMMAND}")
    set(UPDATE_OPTIONS "${GIT_UPDATE_OPTIONS}")
  elseif("${_update_type}" STREQUAL "p4")
    set(UPDATE_COMMAND "${P4COMMAND}")
    set(UPDATE_OPTIONS "${P4_UPDATE_OPTIONS}")
  endif()

  set(DART_TESTING_TIMEOUT 1500 CACHE STRING
    "Maximum time allowed before CTest will kill the test.")

  set(CTEST_SUBMIT_RETRY_DELAY 5 CACHE STRING
    "How long to wait between timed-out CTest submissions.")
  set(CTEST_SUBMIT_RETRY_COUNT 3 CACHE STRING
    "How many times to retry timed-out CTest submissions.")

  find_program(MEMORYCHECK_COMMAND
    NAMES purify valgrind boundscheck
    PATHS
    "[HKEY_LOCAL_MACHINE\\SOFTWARE\\Rational Software\\Purify\\Setup;InstallFolder]"
    DOC "Path to the memory checking command, used for memory error detection."
    )
  find_program(SLURM_SBATCH_COMMAND sbatch DOC
    "Path to the SLURM sbatch executable"
    )
  find_program(SLURM_SRUN_COMMAND srun DOC
    "Path to the SLURM srun executable"
    )
  set(MEMORYCHECK_SUPPRESSIONS_FILE "" CACHE FILEPATH
    "File that contains suppressions for the memory checker")
  find_program(SCPCOMMAND scp DOC
    "Path to scp command, used by CTest for submitting results to a Dart server"
    )
  find_program(COVERAGE_COMMAND gcov DOC
    "Path to the coverage program that CTest uses for performing coverage inspection"
    )
  set(COVERAGE_EXTRA_FLAGS "-l" CACHE STRING
    "Extra command line flags to pass to the coverage tool")

  # set the site name
  site_name(SITE)
  # set the build name
  if(NOT BUILDNAME)
    set(DART_COMPILER "${CMAKE_CXX_COMPILER}")
    if(NOT DART_COMPILER)
      set(DART_COMPILER "${CMAKE_C_COMPILER}")
    endif()
    if(NOT DART_COMPILER)
      set(DART_COMPILER "unknown")
    endif()
    if(WIN32)
      set(DART_NAME_COMPONENT "NAME_WE")
    else()
      set(DART_NAME_COMPONENT "NAME")
    endif()
    if(NOT BUILD_NAME_SYSTEM_NAME)
      set(BUILD_NAME_SYSTEM_NAME "${CMAKE_SYSTEM_NAME}")
    endif()
    if(WIN32)
      set(BUILD_NAME_SYSTEM_NAME "Win32")
    endif()
    if(UNIX OR BORLAND)
      get_filename_component(DART_CXX_NAME
        "${CMAKE_CXX_COMPILER}" ${DART_NAME_COMPONENT})
    else()
      get_filename_component(DART_CXX_NAME
        "${CMAKE_MAKE_PROGRAM}" ${DART_NAME_COMPONENT})
    endif()
    if(DART_CXX_NAME MATCHES "msdev")
      set(DART_CXX_NAME "vs60")
    endif()
    if(DART_CXX_NAME MATCHES "devenv")
      GET_VS_VERSION_STRING("${CMAKE_GENERATOR}" DART_CXX_NAME)
    endif()
    set(BUILDNAME "${BUILD_NAME_SYSTEM_NAME}-${DART_CXX_NAME}")
  endif()

  # the build command
  build_command(MAKECOMMAND_DEFAULT_VALUE
    CONFIGURATION "\${CTEST_CONFIGURATION_TYPE}")
  set(MAKECOMMAND ${MAKECOMMAND_DEFAULT_VALUE}
    CACHE STRING "Command to build the project")

  # the default build configuration the ctest build handler will use
  # if there is no -C arg given to ctest:
  set(DEFAULT_CTEST_CONFIGURATION_TYPE "$ENV{CMAKE_CONFIG_TYPE}")
  if(DEFAULT_CTEST_CONFIGURATION_TYPE STREQUAL "")
    set(DEFAULT_CTEST_CONFIGURATION_TYPE "Release")
  endif()

  mark_as_advanced(
    BZRCOMMAND
    BZR_UPDATE_OPTIONS
    COVERAGE_COMMAND
    COVERAGE_EXTRA_FLAGS
    CTEST_SUBMIT_RETRY_DELAY
    CTEST_SUBMIT_RETRY_COUNT
    CVSCOMMAND
    CVS_UPDATE_OPTIONS
    DART_TESTING_TIMEOUT
    GITCOMMAND
    P4COMMAND
    HGCOMMAND
    MAKECOMMAND
    MEMORYCHECK_COMMAND
    MEMORYCHECK_SUPPRESSIONS_FILE
    PURIFYCOMMAND
    SCPCOMMAND
    SLURM_SBATCH_COMMAND
    SLURM_SRUN_COMMAND
    SITE
    SVNCOMMAND
    SVN_UPDATE_OPTIONS
    )
  if(NOT RUN_FROM_DART)
    set(RUN_FROM_CTEST_OR_DART 1)
    include(CTestTargets)
    set(RUN_FROM_CTEST_OR_DART)
  endif()
endif()
