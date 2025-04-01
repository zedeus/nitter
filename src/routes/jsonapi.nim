# SPDX-License-Identifier: AGPL-3.0-only
import asyncdispatch
import json

import jester

import router_utils, timeline

proc createJsonApiRouter*(cfg: Config) =
    router jsonapi:
        get "/hello":
            cond cfg.enableJsonApi
            let headers = {"Content-Type": "application/json; charset=utf-8"}
            resp Http200, headers, """{"message": "Hello, world"}"""

        get "/i/lists/@id/json":
            cond cfg.enableJsonApi
            let list = await getCachedList(id=(@"id"))
            if list.id.len == 0:
                resp Http404, showError(&"""List "{@"id"}" not found""", cfg)
            resp Http200, headers, $getListJson(list)
