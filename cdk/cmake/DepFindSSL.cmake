# Copyright (c) 2009, 2024, Oracle and/or its affiliates.
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License, version 2.0, as
# published by the Free Software Foundation.
#
# This program is designed to work with certain software (including
# but not limited to OpenSSL) that is licensed under separate terms, as
# designated in a particular file or component or in included license
# documentation. The authors of MySQL hereby grant you an additional
# permission to link the program and your derivative works with the
# separately licensed software that they have either included with
# the program or referenced in the documentation.
#
# Without limiting anything contained in the foregoing, this file,
# which is part of Connector/C++, is also subject to the
# Universal FOSS Exception, version 1.0, a copy of which can be found at
# https://oss.oracle.com/licenses/universal-foss-exception.
#
# This program is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
# See the GNU General Public License, version 2.0, for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software Foundation, Inc.,
# 51 Franklin St, Fifth Floor, Boston, MA 02110-1301 USA

##############################################################################
#
# Targets:
#   OpenSSL::SSL      - main library (includes crypto library)
#   OpenSSL::Crypto   - crypto library
#
# Output variables:
#   OPENSSL_INCLUDE_DIR
#   OPENSSL_LIB_DIR
#   OPENSSL_VERSION
#   OPENSSL_VERSION_MAJOR
#   OPENSSL_LIBRARIES
#

if(TARGET OpenSSL::SSL)
  return()
endif()

include(config_header)  # add_config()
include(CheckSymbolExists)

add_config_option(WITH_SSL STRING DEFAULT system
  "Either 'system' to use system-wide OpenSSL library,"
  " or custom OpenSSL location."
)


function(main)

  message(STATUS "Looking for SSL library.")

  if(NOT WITH_SSL MATCHES "^(system|yes)$")

    if(EXISTS ${WITH_SSL}/include/openssl/ssl.h)
      set(OPENSSL_ROOT_DIR "${WITH_SSL}")
    endif()

    if(NOT DEFINED OpenSSL_DIR)
      set(OpenSSL_DIR "${WITH_SSL}")
    endif()

  endif()

  find_openssl()

  if(NOT TARGET OpenSSL::SSL)

    message(SEND_ERROR
      "Cannot find appropriate system libraries for SSL. "
      "Make sure you've specified a supported SSL version. "
      "Consult the documentation for WITH_SSL alternatives"
    )

    return()

  endif()

  set(OPENSSL_LIB_DIR "${OPENSSL_LIB_DIR}" CACHE INTERNAL "")

  message(STATUS "Using OpenSSL version: ${OPENSSL_VERSION}")

  set(OPENSSL_VERSION_GLOBAL ${OPENSSL_VERSION} CACHE INTERNAL "OpenSSL Version")
  #message(STATUS "OPENSSL_INCLUDE_DIR: ${OPENSSL_INCLUDE_DIR}")
  #message(STATUS "OPENSSL_LIBRARIES: ${OPENSSL_LIBRARIES}")


  set(CMAKE_REQUIRED_INCLUDES "${OPENSSL_INCLUDE_DIR}")
  CHECK_SYMBOL_EXISTS(SHA512_DIGEST_LENGTH "openssl/sha.h"
                      HAVE_SHA512_DIGEST_LENGTH)

  if(NOT HAVE_SHA512_DIGEST_LENGTH)

    message(SEND_ERROR "Could not find SHA512_DIGEST_LENGTH symbol in sha.h header of OpenSSL library")

  endif()

  check_x509_functions()

  if(BUNDLE_DEPENDENCIES)
    bundle_ssl_libs()
  endif()

endfunction(main)


function(check_x509_functions)
    SET(CMAKE_REQUIRED_LIBRARIES OpenSSL::SSL)

    CHECK_SYMBOL_EXISTS(X509_CHECK_FLAG_NO_PARTIAL_WILDCARDS "openssl/x509v3.h"
                        HAVE_X509_CHECK_FLAG_NO_PARTIAL_WILDCARDS)
    CHECK_SYMBOL_EXISTS(SSL_get0_param "openssl/ssl.h"
                        HAVE_SSL_GET0_PARAM)
    CHECK_SYMBOL_EXISTS(X509_VERIFY_PARAM_set_hostflags "openssl/x509v3.h"
                        HAVE_X509_VERIFY_PARAM_SET_HOSTFLAGS)
    CHECK_SYMBOL_EXISTS(X509_VERIFY_PARAM_set1_host "openssl/x509v3.h"
                        HAVE_X509_VERIFY_PARAM_SET1_HOST)

    IF(HAVE_SSL_GET0_PARAM AND HAVE_X509_CHECK_FLAG_NO_PARTIAL_WILDCARDS AND
       HAVE_X509_VERIFY_PARAM_SET_HOSTFLAGS AND HAVE_X509_VERIFY_PARAM_SET1_HOST)
      SET(HAVE_REQUIRED_X509_FUNCTIONS ON CACHE INTERNAL
          "Indicates the presence of required X509 functionality")
      message("-- found required X509 extensions")
      ADD_CONFIG(HAVE_REQUIRED_X509_FUNCTIONS)
    ENDIF()
endfunction(check_x509_functions)


#
# Find libraries, create import targets and set output variables.
#

function(find_openssl)

  # Note: FindOpenSSL seems to be broken on earlier versions of cmake.

  if(CMAKE_VERSION VERSION_GREATER "3.8" OR USE_CMAKE_FIND_OPENSSL)

    # message(STATUS "Using cmake OpenSSL module")
    find_package(OpenSSL)

    set(OPENSSL_LIBRARY "${OPENSSL_SSL_LIBRARY}")

  else()

    # Use our simplified replacement for broken FindOpenSSL

    find_openssl_fix()

  endif()

  # Set OPENSSL_LIB_DIR from the library path if it was not yet defined.

  if(NOT OPENSSL_LIB_DIR)

    # OPENSSL_LIBRARY can be a list containing optimized and debug variants:
    #
    #   optimized;/path/to/optimized/lib;debug;/path/to/debug/lib
    #
    # In that case we extract path from the optimized library.

    list(FIND OPENSSL_LIBRARY "optimized" pos)

    if(pos LESS 0)

      # If "optimized" entry was not found we assume that OPENSSL_LIBRARY is a single path

      set(lib_path "${OPENSSL_LIBRARY}")

    else()

      # Otherwise read the path after the "optimized" entry

      math(EXPR pos "${pos}+1")
      list(GET OPENSSL_LIBRARY ${pos} lib_path)

    endif()

    get_filename_component(OPENSSL_LIB_DIR "${lib_path}" PATH CACHE)

  endif()

  # Set output variables

  set(OPENSSL_FOUND "${OPENSSL_FOUND}" PARENT_SCOPE)
  set(OPENSSL_VERSION "${OPENSSL_VERSION}" PARENT_SCOPE)
  set(OPENSSL_VERSION_MAJOR "${OPENSSL_VERSION_MAJOR}" PARENT_SCOPE)
  set(OPENSSL_INCLUDE_DIR "${OPENSSL_INCLUDE_DIR}" PARENT_SCOPE)
  set(OPENSSL_LIB_DIR "${OPENSSL_LIB_DIR}" PARENT_SCOPE)
  set(OPENSSL_LIBRARIES "${OPENSSL_LIBRARIES}" PARENT_SCOPE)

endfunction(find_openssl)


macro(find_openssl_fix)

  set(add_applink true)
  unset(hints)

  if(OPENSSL_ROOT_DIR)
    set(hints HINTS ${OPENSSL_ROOT_DIR} NO_DEFAULT_PATH)
  endif()

  find_path(OPENSSL_INCLUDE_DIR
    NAMES openssl/ssl.h
    PATH_SUFFIXES include
    ${hints}
  )

  if(NOT OPENSSL_INCLUDE_DIR)
    return()
  endif()

  message("-- found OpenSSL headers at: ${OPENSSL_INCLUDE_DIR}")

  # Verify version number. Version information looks like:
  #   #define OPENSSL_VERSION_TEXT    "OpenSSL 1.1.1a  20 Nov 2018"

  FILE(STRINGS "${OPENSSL_INCLUDE_DIR}/openssl/opensslv.h"
    OPENSSL_VERSION_NUMBER
    REGEX "#[ ]*define[\t ]+OPENSSL_VERSION_TEXT"
  )

  #message("== OPENSSL_VERSION_NUMBER: ${OPENSSL_VERSION_NUMBER}")
  # define OPENSSL_VERSION_TEXT "OpenSSL 1.1.1d-freebsd 10 Sep 2019"
  STRING(REGEX REPLACE
    "^.*OPENSSL_VERSION_TEXT[\t ]+\"OpenSSL[\t ]([0-9]+)\\.([0-9]+)\\.([0-9]+)([a-z]|)[\t \\-].*$"
    "\\1;\\2;\\3;\\4"
    version_list "${OPENSSL_VERSION_NUMBER}"
  )
  #message("-- OPENSSL_VERSION: ${version_list}")

  list(GET version_list 0 OPENSSL_VERSION_MAJOR)
  math(EXPR OPENSSL_VERSION_MAJOR ${OPENSSL_VERSION_MAJOR})

  list(GET version_list 1 OPENSSL_VERSION_MINOR)
  math(EXPR OPENSSL_VERSION_MINOR ${OPENSSL_VERSION_MINOR})

  list(GET version_list 2 OPENSSL_VERSION_FIX)
  math(EXPR OPENSSL_VERSION_FIX ${OPENSSL_VERSION_FIX})

  list(GET version_list 3 OPENSSL_VERSION_PATCH)

  set(OPENSSL_VERSION
    "${OPENSSL_VERSION_MAJOR}.${OPENSSL_VERSION_MINOR}.${OPENSSL_VERSION_FIX}${OPENSSL_VERSION_PATCH}"
  )


  find_library(OPENSSL_LIBRARY
    NAMES ssl ssleay32 ssleay32MD libssl
    PATH_SUFFIXES lib
    ${hints}
  )

  find_library(CRYPTO_LIBRARY
    NAMES crypto libeay32 libeay32MD libcrypto
    PATH_SUFFIXES lib
    ${hints}
  )

  if(NOT OPENSSL_LIBRARY OR NOT CRYPTO_LIBRARY)
    return()
  endif()

  message("-- OpenSSL library: ${OPENSSL_LIBRARY}")
  message("-- OpenSSL crypto library: ${CRYPTO_LIBRARY}")

  # Note: apparently UNKNOWN library type does not work
  # https://stackoverflow.com/questions/39346679/cmake-imported-unknown-global-target

  add_library(OpenSSL::SSL SHARED IMPORTED GLOBAL)
  set_target_properties(OpenSSL::SSL PROPERTIES
    IMPORTED_LOCATION "${OPENSSL_LIBRARY}"
    IMPORTED_IMPLIB "${OPENSSL_LIBRARY}"
    INTERFACE_INCLUDE_DIRECTORIES "${OPENSSL_INCLUDE_DIR}"
  )

  add_library(OpenSSL::Crypto SHARED IMPORTED GLOBAL)
  set_target_properties(OpenSSL::Crypto PROPERTIES
    IMPORTED_LOCATION "${CRYPTO_LIBRARY}"
    IMPORTED_IMPLIB "${CRYPTO_LIBRARY}"
    INTERFACE_INCLUDE_DIRECTORIES "${OPENSSL_INCLUDE_DIR}"
  )

  set_property(TARGET OpenSSL::SSL PROPERTY
    INTERFACE_LINK_LIBRARIES OpenSSL::Crypto
  )

  #TODO: Is it needed also when OpenSSL is found via cmake module?

  if(WIN32 AND EXISTS "${OPENSSL_INCLUDE_DIR}/openssl/applink.c")

    #message("-- Handling applink.c")

    add_library(openssl-applink STATIC "${OPENSSL_INCLUDE_DIR}/openssl/applink.c")
    target_link_libraries(OpenSSL::SSL INTERFACE openssl-applink)

    set_target_properties(openssl-applink PROPERTIES FOLDER "Misc")
    # Remove warnings from openssl applink.c
    if(CXX_FRONTEND_MSVC)
      target_compile_options(openssl-applink PRIVATE /wd4152 /wd4996)
    endif()

  endif()

  set(OPENSSL_FOUND true)

endmacro(find_openssl_fix)


#
# Add instructions for installing OpenSSL libraries together
# with the connector.
#

function(bundle_ssl_libs)

  if(NOT OPENSSL_LIB_DIR)
    return()
  endif()


  if(NOT WIN32)

    # Note: On U**ix systems the files we link to are symlinks to
    # the actual shared libs, so we read these symlinks here and
    # bundle their targets as well.

    foreach(lib ${OPENSSL_LIBRARIES})

      if(NOT EXISTS "${lib}")
        continue()
      endif()

      get_filename_component(path "${lib}" REALPATH)
      list(APPEND glob1 "${lib}" "${path}")

    endforeach()

  else()

    # Very simplistic approach - assuming that OPENSSL_LIB_DIR points
    # at OpenSSL installation grab all shared libraries that can be
    # found there.

    file(GLOB glob1
      "${OPENSSL_LIB_DIR}/*${CMAKE_SHARED_LIBRARY_SUFFIX}*"
    )

    file(GLOB glob2
      "${OPENSSL_LIB_DIR}/../bin/*${CMAKE_SHARED_LIBRARY_SUFFIX}*"
    )

  endif()

  foreach(lib ${glob1} ${glob2})
    # Copy SSL libs to binary dir as below we will modify them (change the path to
    # libcrypto dependency).
    file(COPY ${lib} DESTINATION ${CMAKE_BINARY_DIR}/SSL)

    message("-- bundling OpenSSL library: ${lib}")

    get_filename_component(lib_filename ${lib} NAME)

    if(WIN32 OR APPLE)
      install(FILES ${CMAKE_BINARY_DIR}/SSL/${lib_filename}
        DESTINATION "${INSTALL_LIB_DIR}"
        COMPONENT OpenSSLDll
        )
    else()
      install(FILES ${CMAKE_BINARY_DIR}/SSL/${lib_filename}
        DESTINATION "${INSTALL_LIB_DIR}/private"
        COMPONENT OpenSSLDll
        )
    endif()


  endforeach()

  # For Windows we also need static import libraries

  if(WIN32)

    file(GLOB glob
      "${OPENSSL_LIB_DIR}/*.lib"
    )

    foreach(lib ${glob})

      message("-- bundling OpenSSL library: ${lib}")

      install(FILES ${lib}
        DESTINATION "${INSTALL_LIB_DIR_STATIC}"
        COMPONENT OpenSSLDev
      )

    endforeach()

  endif()

  if(APPLE)

    # Edit the main OpenSSL library to not include full path to the crypto
    # dependency. Instead use path relative to the location of the main library.
    # Dependency information is changed from something
    # like this:
    #
    # $ otool -L SSL/libssl.dylib
    # SSL/libssl.dylib:
    #  /opt/homebrew/Cellar/openssl@3/3.2.1/lib/libcrypto.3.dylib (compatibility version 3.0.0, current version 3.0.0)
    #
    # to something like this:
    #
    # $ otool -L SSL/libssl.dylib
    # SSL/libssl.dylib:
    #  @loader_path/libcrypto.3.dylib (compatibility version 3.0.0, current version 3.0.0)

    # Read original dependencies using otool (only for the main library)

    set(lib_ssl ${OPENSSL_LIBRARIES})
    list(FILTER lib_ssl INCLUDE REGEX "libssl\.dylib$")

    execute_process(
      COMMAND otool -L ${lib_ssl}
      OUTPUT_VARIABLE OTOOL_OPENSSL_DEPS
    )

    # Parse output of otool to extract full paths and library names
    # with versions.

    string(REPLACE "\n" ";" DEPS_LIST ${OTOOL_OPENSSL_DEPS})

    foreach(line ${DEPS_LIST})
    foreach(lib ssl crypto)

      if(line MATCHES "(/.*lib${lib}.*${CMAKE_SHARED_LIBRARY_SUFFIX}).*compatibility version")

        if(CMAKE_MATCH_1)
          set(lib_${lib}_path "${CMAKE_MATCH_1}")
          get_filename_component(lib_${lib}_name "${lib_${lib}_path}" NAME)
        endif()

      endif()

    endforeach(lib)
    endforeach(line)


    if(NOT lib_ssl_path OR NOT lib_crypto_path)
      message("Warning: Failed to edit OpenSSL library dependencies")
      return()
    endif()

    # Use install_name_tool to replace full path with @loader_path:
    # $ install_name_tool -change old new file

    execute_process(
      COMMAND chmod +w ${lib_ssl_name} ${lib_crypto_name}
      COMMAND install_name_tool
        -change "${lib_crypto_path}" "@loader_path/${lib_crypto_name}"
        "${lib_ssl_name}"
      WORKING_DIRECTORY "${CMAKE_BINARY_DIR}/SSL"
    )

  endif(APPLE)

endfunction(bundle_ssl_libs)


main()
return()

##########################################################################

