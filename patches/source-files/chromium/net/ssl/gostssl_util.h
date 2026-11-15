// Copyright 2026 The Chromium Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef NET_SSL_GOSTSSL_UTIL_H_
#define NET_SSL_GOSTSSL_UTIL_H_

#include "net/base/net_export.h"

namespace net {

#ifndef NO_GOSTSSL
NET_EXPORT void EnsureGostSSLCommandLineInitialized();
#endif  // NO_GOSTSSL

}  // namespace net

#endif  // NET_SSL_GOSTSSL_UTIL_H_
