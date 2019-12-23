import asyncfile, uri, strutils, httpclient, os, mimetypes

import jester, regex

import router_utils
import ".."/[types, formatters]
import ../views/general

export asyncfile, httpclient, os, strutils
export regex

proc createMediaRouter*(cfg: Config) =
  router media:
    get "/pic/@url":
      cond "http" in @"url"
      cond "twimg" in @"url"

      let uri = parseUri(decodeUrl(@"url"))
      cond isTwitterUrl($uri) == true

      let path = uri.path.split("/")[2 .. ^1].join("/")
      let filename = cfg.cacheDir / cleanFilename(path & uri.query)

      if path.len == 0:
        resp Http404

      if not existsDir(cfg.cacheDir):
        createDir(cfg.cacheDir)

      if not existsFile(filename):
        let client = newAsyncHttpClient()
        try:
          await client.downloadFile($uri, filename)
          client.close()
        except HttpRequestError:
          removeFile(filename)
          resp Http404

      sendFile(filename)

    get "/gif/@url":
      cond "http" in @"url"
      cond "twimg" in @"url"
      cond "mp4" in @"url" or "gif" in @"url"

      let url = decodeUrl(@"url")
      cond isTwitterUrl(url) == true

      let content = await safeFetch(url)
      if content.len == 0: resp Http404

      let filename = parseUri(url).path.split(".")[^1]
      resp content, settings.mimes.getMimetype(filename)

    get "/video/@sig/@url":
      cond "http" in @"url"
      var url = decodeUrl(@"url")
      let prefs = cookiePrefs()

      if getHmac(url) != @"sig":
        resp showError("Failed to verify signature", cfg)

      var content = await safeFetch(url)
      if content.len == 0: resp Http404

      if ".vmap" in url:
        var m: RegexMatch
        discard content.find(re"""url="(.+.m3u8)"""", m)
        url = decodeUrl(content[m.group(0)[0]])
        content = await safeFetch(url)

      if ".m3u8" in url:
        content = proxifyVideo(content, prefs.proxyVideos)

      let ext = parseUri(url).path.split(".")[^1]
      resp content, settings.mimes.getMimetype(ext)
