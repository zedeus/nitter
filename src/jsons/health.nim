# SPDX-License-Identifier: AGPL-3.0-only
import std/[json]
import asyncdispatch

import jester

import ".."/routes/[router_utils]
import "../jsons/timeline"

proc createJsonApiHealthRouter*(cfg: Config) =
  router jsonapi_health:
    get "/api/health":
      cond cfg.enableJsonApi
      let origin = corsOrigin()
      let headers = {
        "Content-Type": "application/json; charset=utf-8",
        "Vary": "Origin",
        "Access-Control-Allow-Origin": origin,
        "Access-Control-Allow-Credentials": "true"
      }
      resp Http200, headers, """{"message": "OK"}"""
