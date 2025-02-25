import std/strutils
import jsony
import ../types/session
from ../../types import Session, SessionKind

proc parseSession*(raw: string): Session =
  let session = raw.fromJson(RawSession)

  case session.kind
  of "oauth":
    let id = session.oauthToken[0 ..< session.oauthToken.find('-')]
    result = Session(
      kind: oauth,
      id: parseBiggestInt(id),
      oauthToken: session.oauthToken,
      oauthSecret: session.oauthTokenSecret
    )
  of "cookie":
    result = Session(
      kind: cookie,
      id: 999,
      ct0: session.ct0,
      authToken: session.authToken
    )
