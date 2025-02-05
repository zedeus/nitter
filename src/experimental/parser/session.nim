import std/strutils
import jsony
import ../types/session
from ../../types import Session

proc parseSession*(raw: string): Session =
  let 
    session = raw.fromJson(RawSession)
    id = session.oauthToken[0 ..< session.oauthToken.find('-')]

  result = Session(
    id: parseBiggestInt(id),
    oauthToken: session.oauthToken,
    oauthSecret: session.oauthTokenSecret
  )
