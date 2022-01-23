# SPDX-License-Identifier: AGPL-3.0-only
import httpclient

type
  HttpPool* = ref object
    conns*: seq[AsyncHttpClient]

var
  maxConns: int
  proxy: Proxy

proc setMaxHttpConns*(n: int) =
  maxConns = n

proc setHttpProxy*(url: string; auth: string) =
  if url.len > 0:
    proxy = newProxy(url, auth)
  else:
    proxy = nil

proc release*(pool: HttpPool; client: AsyncHttpClient; badClient=false) =
  if pool.conns.len >= maxConns or badClient:
    try: client.close()
    except: discard
  elif client != nil:
    pool.conns.insert(client)

proc acquire*(pool: HttpPool; heads: HttpHeaders): AsyncHttpClient =
  if pool.conns.len == 0:
    result = newAsyncHttpClient(headers=heads, proxy=proxy)
  else:
    result = pool.conns.pop()
    result.headers = heads

template use*(pool: HttpPool; heads: HttpHeaders; body: untyped): untyped =
  var
    c {.inject.} = pool.acquire(heads)
    badClient {.inject.} = false

  try:
    body
  except ProtocolError:
    # Twitter closed the connection, retry
    body
  finally:
    pool.release(c, badClient)
