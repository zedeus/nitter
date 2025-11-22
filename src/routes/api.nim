# SPDX-License-Identifier: AGPL-3.0-only
import jester, uri, re
import ".."/[utils, types, formatters]

proc decode*(req: jester.Request; index: int): string =
  decodeUrl(req.matches[index])

proc createApiRouter*(cfg: Config) =
  router api:
    get re"^\/api\/video\/(.+)":
      cond cfg.enableApi
      let link = decode(request, 0)

      if link == nil:
        resp Http404

      redirect getVidUrl(link)

    get re"^\/api\/pic\/(.+)":
      cond cfg.enableApi
      let link = decode(request, 0)

      if link == nil:
        resp Http404

      redirect getPicUrl(link)
