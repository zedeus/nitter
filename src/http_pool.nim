# SPDX-License-Identifier: AGPL-3.0-only
import asyncdispatch, httpclient

type
  HttpPool* = ref object
    conns*: seq[AsyncHttpClient]

var maxConns {.threadvar.}: int
var proxy {.threadvar.}: Proxy

proc setMaxHttpConns*(n: int) =
  maxConns = n

proc setHttpProxy*(url: string; auth: string) =
  if url.len > 0:
    proxy = newProxy(url, auth)
  else:
    proxy = nil

proc release*(pool: HttpPool; client: AsyncHttpClient) =
  if pool.conns.len >= maxConns:
    client.close()
  elif client != nil:
    pool.conns.insert(client)

template use*(pool: HttpPool; heads: HttpHeaders; body: untyped): untyped =
  var c {.inject.}: AsyncHttpClient

  if pool.conns.len == 0:
    c = newAsyncHttpClient(headers=heads, proxy=proxy)
  else:
    c = pool.conns.pop()
    c.headers = heads

  try:
    body
  except ProtocolError:
    # Twitter closed the connection, retry
    body
  finally:
    pool.release(c)
