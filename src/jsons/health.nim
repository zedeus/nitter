# SPDX-License-Identifier: AGPL-3.0-only
import asyncdispatch
import json

import jester

import router_utils, timeline
import "../jsons/timeline"

proc createJsonApiHealthRouter*(cfg: Config) =
  router jsonapi:
    get "/hello":
      cond cfg.enableJsonApi
      let headers = {"Content-Type": "application/json; charset=utf-8"}
      resp Http200, headers, """{"message": "Hello, world"}"""
