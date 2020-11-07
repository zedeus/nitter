import asyncdispatch, httpclient

type
  HttpPool* = ref object
    conns*: seq[AsyncHttpClient]

var maxConns {.threadvar.}: int

let keepAlive* = newHttpHeaders({
  "Connection": "Keep-Alive"
})

proc setMaxHttpConns*(n: int) =
  maxConns = n

proc release*(pool: HttpPool; client: AsyncHttpClient) =
  if pool.conns.len >= maxConns:
    client.close()
  elif client != nil:
    pool.conns.insert(client)

template use*(pool: HttpPool; heads: HttpHeaders; body: untyped): untyped =
  var c {.inject.}: AsyncHttpClient

  if pool.conns.len == 0:
    c = newAsyncHttpClient(headers=heads)
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
