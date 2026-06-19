# SPDX-License-Identifier: AGPL-3.0-only
import asyncdispatch, strutils
import jester

import router_utils
import ".."/[types, formatters, redis_cache]
import ../views/[general, space]
import media

export space

proc createSpaceRouter*(cfg: Config) =
  router spaceRoute:
    get "/i/spaces/@id":
      cond @"id".allCharsInSet({'a'..'z', 'A'..'Z', '0'..'9'})
      let sp = await getCachedAudioSpace(@"id")

      if sp.id.len == 0:
        resp Http404, showError("Space not found", cfg)

      let prefs = requestPrefs()
      resp renderMain(renderSpace(sp, prefs, request.path), request, cfg, prefs,
                      sp.title, ogTitle=sp.title)

    get "/i/spaces/@id/stream":
      cond @"id".allCharsInSet({'a'..'z', 'A'..'Z', '0'..'9'})
      let sp = await getCachedAudioSpace(@"id")

      if sp.m3u8Url.len == 0:
        resp Http404

      let manifest = await safeFetch(sp.m3u8Url)
      if manifest.len == 0:
        resp Http502

      resp proxifyVideo(manifest, requestPrefs().proxyVideos, sp.m3u8Url), m3u8Mime
