# SPDX-License-Identifier: AGPL-3.0-only

import jester

import router_utils
import ".."/[types, auth]

proc createAuthRouter*(cfg: Config) =
  router auth:
    get "/.well-known/nitter-auth":
      cond cfg.guestAccountsUsePool
      resp Http200, {"content-type": "text/plain"}, getAuthHash(cfg)
