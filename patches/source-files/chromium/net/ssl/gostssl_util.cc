// Copyright 2026 The Chromium Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifdef UNSAFE_BUFFERS_BUILD
// Atom Browser: GOST patch code uses raw buffers. TODO: convert to base::span.
#pragma allow_unsafe_buffers
#endif


#include "net/ssl/gostssl_util.h"

#ifndef NO_GOSTSSL

#include <mutex>
#include <string>

#include "base/command_line.h"

extern "C" {
void gostssl_commandline(const char* ciphers,
                         const char* tlsmode,
                         const char* issuersfilter);
}

namespace net {

void EnsureGostSSLCommandLineInitialized() {
  static std::once_flag once;
  std::call_once(once, [] {
    base::CommandLine* command_line = base::CommandLine::ForCurrentProcess();

    std::string ciphers;
    if (command_line->HasSwitch("ciphers"))
      ciphers = command_line->GetSwitchValueASCII("ciphers");

    std::string tlsmode;
    if (command_line->HasSwitch("tlsmode"))
      tlsmode = command_line->GetSwitchValueASCII("tlsmode");

    std::string issuersfilter;
    if (command_line->HasSwitch("issuersfilter"))
      issuersfilter = command_line->GetSwitchValueASCII("issuersfilter");

    gostssl_commandline(ciphers.c_str(), tlsmode.c_str(),
                        issuersfilter.c_str());
  });
}

}  // namespace net

#endif  // NO_GOSTSSL
