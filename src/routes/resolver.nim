# SPDX-License-Identifier: AGPL-3.0-only
import strutils

import jester

import router_utils
import ".."/[types, api]
import ../views/general

template respResolved*(url, kind: string): untyped =
  let u = url
  if u.len == 0:
    resp showError("Invalid $1 link" % kind, cfg)
  else:
    redirect(u)

proc createResolverRouter*(cfg: Config) =
  router resolver:
    get "/cards/@card/@id":
      let url = "https://cards.twitter.com/cards/$1/$2" % [@"card", @"id"]
      respResolved(await resolve(url, cookiePrefs()), "card")

    get "/t.co/@url":
      let url = "https://t.co/" & @"url"
      respResolved(await resolve(url, cookiePrefs()), "t.co")
