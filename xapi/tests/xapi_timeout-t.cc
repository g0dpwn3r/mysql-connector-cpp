/*
 * Copyright (c) 2025, Oracle and/or its affiliates.
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License, version 2.0, as
 * published by the Free Software Foundation.
 *
 * This program is designed to work with certain software (including
 * but not limited to OpenSSL) that is licensed under separate terms, as
 * designated in a particular file or component or in included license
 * documentation. The authors of MySQL hereby grant you an additional
 * permission to link the program and your derivative works with the
 * separately licensed software that they have either included with
 * the program or referenced in the documentation.
 *
 * Without limiting anything contained in the foregoing, this file,
 * which is part of Connector/C++, is also subject to the
 * Universal FOSS Exception, version 1.0, a copy of which can be found at
 * https://oss.oracle.com/licenses/universal-foss-exception.
 *
 * This program is distributed in the hope that it will be useful, but
 * WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 * See the GNU General Public License, version 2.0, for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software Foundation, Inc.,
 * 51 Franklin St, Fifth Floor, Boston, MA 02110-1301 USA
 */
#include <stdio.h>
#include <string.h>
#include <climits>
#include <chrono>
#include <iostream>
#include <list>
#include <map>
#include "test.h"


TEST_F(xapi_timeout, read_timeout)
{
// Set MANUAL_TESTING to 1
#undef MANUAL_TESTING
#define MANUAL_TESTING 0
#if(MANUAL_TESTING == 1)
  mysqlx_session_t *local_sess = NULL;
  mysqlx_error_t *error = NULL;
  mysqlx_stmt_t *stmt = NULL;
  mysqlx_result_t *res = NULL;

  for (int timeout : {0, 5000, 15000})
  {
    mysqlx_session_options_t *opt = mysqlx_session_options_new();
    EXPECT_EQ(RESULT_OK, mysqlx_session_option_set(
      opt,
      OPT_HOST(get_host()),
      OPT_PORT(get_port()),
      OPT_USER(get_user()),
      OPT_PWD(get_password()),
      OPT_READ_TIMEOUT(timeout),
      PARAM_END
    ));

    local_sess = mysqlx_get_session_from_options(opt, &error);
    if (!local_sess)
    {
      mysqlx_session_close(local_sess);
      FAIL() << "Session could not be established";
    }

    const char * query = "SELECT SLEEP(10)";

    RESULT_CHECK(stmt = mysqlx_sql_new(get_session(), query, strlen(query)));
    res = mysqlx_sql(local_sess, query, strlen(query));
    switch (timeout)
    {
      case 0:
      case 15000:
        EXPECT_TRUE(res != NULL);
        break;
      case 5000:
        EXPECT_TRUE(res == NULL);
        break;
    }
    mysqlx_session_close(local_sess);
  }
#endif
}


/*
  NOTE: Test is not implemented because the write timeout is optional for
        the platforms implementation and it does not work everywhere.
        (See Timeout::write_timeout in devapi/tests/timeout-t.cc)
*/
TEST_F(xapi_timeout, write_timeout)
{
}
