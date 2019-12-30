import asyncdispatch, httpclient

import ".."/[formatters, types]

proc resolve*(url: string; prefs: Prefs): Future[string] {.async.} =
  let client = newAsyncHttpClient(maxRedirects=0)
  try:
    let resp = await client.request(url, $HttpHead)
    result = resp.headers["location"].replaceUrl(prefs)
  except:
    discard
  finally:
    client.close()
