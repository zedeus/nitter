import std/strutils
import jsony
import ../types/session
from ../../types import Session, SessionKind

proc parseSession*(raw: string): Session =
  let session = raw.fromJson(RawSession)
  let kind = if session.kind == "": "oauth" else: session.kind

  case kind
  of "oauth":
    let id = session.oauthToken[0 ..< session.oauthToken.find('-')]
    result = Session(
      kind: SessionKind.oauth,
      id: parseBiggestInt(id),
      oauthToken: session.oauthToken,
      oauthSecret: session.oauthTokenSecret
    )
  of "cookie":
    result = Session(
      kind: SessionKind.cookie,
      id: 999,
      authToken: session.authToken,
      ct0: session.ct0
    )
  else:
    raise newException(ValueError, "Unknown session kind: " & kind)
