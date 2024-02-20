# Copyright (c) 2015, 2024, Oracle and/or its affiliates.
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

#
# Note: We must clear compile flags - the ones used to build the connector
# are not good for building client code that uses the connector.
#

get_filename_component(CDKDIR "${CMAKE_CURRENT_LIST_DIR}/../../cdk" ABSOLUTE)

set_property(
  DIRECTORY .
  PROPERTY COMPILE_DEFINITIONS ""
)

if(WIN32)
  add_definitions(
    -D_CRT_SECURE_NO_WARNINGS
    -D_SILENCE_TR1_NAMESPACE_DEPRECATION_WARNING
  )

endif()

#
# If linking with connector statically, define macro that indicates this
# to the public headers.
#

if(BUILD_STATIC)
  add_definitions(-DSTATIC_CONCPP)
endif()

ADD_NG_TEST(devapi-t
  first-t.cc crud-t.cc types-t.cc batch-t.cc ddl-t.cc session-t.cc
  bugs-t.cc test.h
)

set(TLS_CIPHERS_H "${CDKDIR}/foundation/tls_ciphers.h")

if(EXISTS ${TLS_CIPHERS_H})

  message(STATUS "Using cipher list defined in: ${TLS_CIPHERS_H}")

  include_directories("${CDKDIR}/foundation")
  add_compile_definitions(TLS_CIPHERS_H)

else()
  message(SEND_ERROR "The cipher list could not be found: ${TLS_CIPHERS_H}")
endif()