import asyncfile, uri, strutils, httpclient, os

import jester, regex

import router_utils
import ".."/[types, formatters, utils, prefs]
import ../views/general

export asyncfile, httpclient, os, strutils
export regex
export utils

proc createMediaRouter*(cfg: Config) =
  router media:
    get "/pic/@sig/@url":
      cond "http" in @"url"
      cond "twimg" in @"url"
      let
        uri = parseUri(decodeUrl(@"url"))
        path = uri.path.split("/")[2 .. ^1].join("/")
        filename = cfg.cacheDir / cleanFilename(path & uri.query)

      if getHmac($uri) != @"sig":
        resp showError("Failed to verify signature", cfg.title)

      if not existsDir(cfg.cacheDir):
        createDir(cfg.cacheDir)

      if not existsFile(filename):
        let client = newAsyncHttpClient()
        await client.downloadFile($uri, filename)
        client.close()

      if not existsFile(filename):
        resp Http404

      let file = openAsync(filename)
      let buf = await readAll(file)
      file.close()

      resp buf, mimetype(filename)

    get "/video/@sig/@url":
      cond "http" in @"url"
      var url = decodeUrl(@"url")
      let prefs = cookiePrefs()

      if getHmac(url) != @"sig":
        resp showError("Failed to verify signature", cfg.title)

      let client = newAsyncHttpClient()
      var content = await client.getContent(url)

      if ".vmap" in url:
        var m: RegexMatch
        discard content.find(re"""url="(.+.m3u8)"""", m)
        url = decodeUrl(content[m.group(0)[0]])
        content = await client.getContent(url)

      if ".m3u8" in url:
        content = proxifyVideo(content, prefs.proxyVideos)

      client.close()
      resp content, mimetype(url)
