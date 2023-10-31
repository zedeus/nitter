# SPDX-License-Identifier: AGPL-3.0-only
import jester
import router_utils
import ".."/[auth, types]

proc createDebugRouter*(cfg: Config) =
  router debug:
    get "/.health":
      respJson getAccountPoolHealth()

    get "/.accounts":
      cond cfg.enableDebug
      respJson getAccountPoolDebug()
