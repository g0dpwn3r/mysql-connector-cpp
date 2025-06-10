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

#include "test.h"
#include <iostream>
#include <future>
#include <chrono>
#include <thread>
#include <map>
#include <sstream>

using std::cout;
using std::endl;
using namespace mysqlx;


class Timeout : public mysqlx::test::DevAPI
{
public:

  SessionSettings get_opt() const
  {
    return {
        SessionOption::HOST, get_host(),
        SessionOption::PORT, get_port(),
        SessionOption::USER, get_user(),
        SessionOption::PWD, get_password() ? get_password() : nullptr,
    };
  }

};


TEST_F(Timeout, timeout_opts)
{
  std::string uri = get_uri();

  // Connect timeout tests
  std::map<SessionOption::Enum, std::string> opt_map = {
    { SessionOption::CONNECT_TIMEOUT, "connect-timeout" },
    { SessionOption::READ_TIMEOUT, "read-timeout" },
    { SessionOption::WRITE_TIMEOUT, "write-timeout" },
  };

  for (auto opt : opt_map)
  {
    EXPECT_NO_THROW(
      SessionSettings settings(opt.first, 0)
    );

    EXPECT_NO_THROW(
      SessionSettings settings(uri + "?" + opt.second + "=0")
    );

    EXPECT_NO_THROW(
      SessionSettings settings(opt.first, 10)
    );

    EXPECT_NO_THROW(
      SessionSettings settings(uri + "?" + opt.second + "=10")
    );

    EXPECT_NO_THROW(
      SessionSettings settings(opt.first, std::chrono::seconds(10))
    );

    // Negative tests
    EXPECT_THROW(
      SessionSettings settings(uri + "?" + opt.second + "=ERR"),
      Error
    );

    EXPECT_THROW(
      SessionSettings settings(opt.first, "ERR"),
      Error
    );

    EXPECT_THROW(
      SessionSettings settings(uri + "?" + opt.second + "=-5"),
      Error
    );

    EXPECT_THROW(
      SessionSettings settings(opt.first, -5),
      Error
    );

    EXPECT_THROW(
      SessionSettings settings(uri + "?" + opt.second + "=10.5"),
      Error
    );

    EXPECT_THROW(
      SessionSettings settings(opt.first, 10.5),
      Error
    );
  }
}

TEST_F(Timeout, connect_timeout)
{
// Set MANUAL_TESTING to 1 and define NON_BOUNCE_SERVER
#define MANUAL_TESTING 0
#if(MANUAL_TESTING == 1)

#define NON_BOUNCE_SERVER "define.your.server"
#define NON_BOUNCE_PORT1 81
#define NON_BOUNCE_PORT2 82


  SKIP_IF_NO_XPLUGIN;
  {
    auto start = std::chrono::high_resolution_clock::now();

    // Timeout was not specified, assume 10s
    EXPECT_THROW(mysqlx::Session sess(SessionOption::HOST, NON_BOUNCE_SERVER,
                                      SessionOption::PORT, NON_BOUNCE_PORT1,
                                      SessionOption::USER, get_user(),
                                      SessionOption::PWD, get_password() ? get_password() : nullptr),
                 Error);

    auto end = std::chrono::high_resolution_clock::now();
    std::chrono::nanoseconds nsec = end - start;
    cout << "Timeout default test passed " << nsec.count()/1000000 << " ms" << endl;
  }

  {
    auto start = std::chrono::high_resolution_clock::now();

    EXPECT_THROW(mysqlx::Session sess(SessionOption::HOST, NON_BOUNCE_SERVER,
                                      SessionOption::PORT, NON_BOUNCE_PORT1,
                                      SessionOption::USER, get_user(),
                                      SessionOption::PWD, get_password() ? get_password() : nullptr,
                                      SessionOption::CONNECT_TIMEOUT,
                                      std::chrono::seconds(5)),
                 Error);

    auto end = std::chrono::high_resolution_clock::now();
    std::chrono::nanoseconds nsec = end - start;
    cout << "Timeout std::chrono::seconds(5) passed " << nsec.count() / 1000000 << " ms" << endl;
  }


  {

    SessionSettings settings(SessionOption::HOST, NON_BOUNCE_SERVER,
                             SessionOption::PORT, NON_BOUNCE_PORT1,
                             SessionOption::USER, get_user(),
                             SessionOption::PWD, get_password() ? get_password() : nullptr,
                             SessionOption::CONNECT_TIMEOUT, 1000);

    settings.erase(SessionOption::CONNECT_TIMEOUT);
    settings.set(SessionOption::CONNECT_TIMEOUT, 5000);
    auto start = std::chrono::high_resolution_clock::now();
    EXPECT_THROW(mysqlx::Session sess(settings),
                  Error);

    auto end = std::chrono::high_resolution_clock::now();
    std::chrono::nanoseconds nsec = end - start;
    cout << "Timeout plain integer 5000 ms test passed " <<
      nsec.count() / 1000000 << " ms" << endl;
  }

  {
    std::stringstream uri;
    uri << "mysqlx://" << get_user();
    if (get_password() && *get_password())
      uri << ":" << get_password();
    uri << "@" << NON_BOUNCE_SERVER << ":" << NON_BOUNCE_PORT1;
    std::stringstream str;
    str << uri.str() << "/?connect-timeout=5000";

    // Record start time
    auto start = std::chrono::high_resolution_clock::now();

    EXPECT_THROW(
      mysqlx::Session sess(str.str()),
      Error);

    auto end = std::chrono::high_resolution_clock::now();
    std::chrono::nanoseconds nsec = end - start;
    cout << "Timeout URI (connect-timeout=5000) test passed " <<
      nsec.count() / 1000000 << " ms" << endl;
  }

  {
    // Record start time
    auto start = std::chrono::high_resolution_clock::now();
    EXPECT_THROW(
    mysqlx::Session sess(SessionOption::HOST, NON_BOUNCE_SERVER,
                         SessionOption::PORT, NON_BOUNCE_PORT1,
                         SessionOption::PRIORITY, 1,
                         SessionOption::HOST, NON_BOUNCE_SERVER,
                         SessionOption::PORT, NON_BOUNCE_PORT2,
                         SessionOption::PRIORITY, 2,
                         SessionOption::CONNECT_TIMEOUT, std::chrono::seconds(3),
                         SessionOption::USER, get_user(),
                         SessionOption::PWD, get_password() ? get_password() : NULL
                      ),
                      Error);
    auto end = std::chrono::high_resolution_clock::now();
    std::chrono::nanoseconds nsec = end - start;
    cout << "Timeout multihost 2x3 sec test passed " <<
      nsec.count() / 1000000 << " ms" << endl;
  }

#ifndef _WIN32
  {
    // Record start time
    auto start = std::chrono::high_resolution_clock::now();
    EXPECT_THROW(
      // but ignore then when not having host
      mysqlx::Session sess(SessionOption::SOCKET, "/tmp/socket_wrong.sock",
                      SessionOption::USER, get_user(),
                      SessionOption::PWD, get_password(),
                      SessionOption::CONNECT_TIMEOUT, 3000
                    ),
                    Error);

    auto end = std::chrono::high_resolution_clock::now();
    cout << "Timeout socket test passed " <<
      nsec.count() / 1000000 << " ms" << endl;
  }
#endif

#endif
}

TEST_F(Timeout, read_timeout)
{
  SKIP_IF_NO_XPLUGIN;
  #undef MANUAL_TESTING

  #define MANUAL_TESTING 0
  #if(MANUAL_TESTING == 1)

  for (auto timeout : {3000, 20000, 0})
  {
    SessionSettings settings(
      SessionOption::HOST, get_host(),
      SessionOption::PORT, get_port(),
      SessionOption::USER, get_user(),
      SessionOption::PWD, get_password(),
      SessionOption::READ_TIMEOUT, timeout
    );

    mysqlx::Session sess(settings);

    auto stmt = sess.sql("SELECT SLEEP(10)");

    switch (timeout)
    {
      case 0:
      case 20000:
        EXPECT_NO_THROW(stmt.execute());
        break;
      case 3000:
        EXPECT_THROW(stmt.execute(), Error);
        break;
    }
  }
  #endif
}

/*
  NOTE: The write timeout implementation is optional in many platforms and
        therefore it is not going to work everywhere.
        However, for the situations of network errors such as cable unplug
        the read timeout is going to kick in if it is set together
        with write timeout.
*/
TEST_F(Timeout, write_timeout)
{
  SKIP_IF_NO_XPLUGIN;
  #undef MANUAL_TESTING

  #define MANUAL_TESTING 0
  #if(MANUAL_TESTING == 1)

  for (auto timeout : {0, 2000})
  {
    SessionSettings settings(
      SessionOption::HOST, get_host(),
      SessionOption::PORT, get_port(),
      SessionOption::USER, get_user(),
      SessionOption::PWD, get_password(),
      SessionOption::SSL_MODE, SSLMode::DISABLED,
      SessionOption::WRITE_TIMEOUT, timeout,
      // Set read timeout to kick in if write timeout is not implemented in OS
      SessionOption::READ_TIMEOUT, timeout
    );

    mysqlx::Session sess(settings);
    size_t s = 1024*1024;

    typedef char char_type;

    size_t bs = s * sizeof(char_type);
    char_type *buf = new char_type[s]();

    sess.sql("DROP TABLE IF EXISTS test.t1").execute();
    sess.sql("CREATE TABLE test.t1(lt LONGTEXT)").execute();

    for (size_t idx = 0; idx < s; ++idx)
    {
      buf[idx] = ' ';
    }

    const char* query = "INSERT INTO test.t1 VALUES ('";
    memmove(buf, query, strlen(query) * sizeof(char_type));
    memmove(buf + s - 3, "')", 2 * sizeof(char_type));
    std::string qs(buf, bs);

    auto stmt = sess.sql(qs);

    if (timeout)
      EXPECT_THROW(stmt.execute(), Error);
    else
      EXPECT_NO_THROW(stmt.execute());
    delete[] buf;
  }
  #endif
}

