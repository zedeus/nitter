# SPDX-License-Identifier: AGPL-3.0-only
import jester
import router_utils
import ".."/[tokens, types]

proc createDebugRouter*(cfg: Config) =
  router debug:
    get "/.tokens":
      cond cfg.enableDebug
      respJson getPoolJson()
