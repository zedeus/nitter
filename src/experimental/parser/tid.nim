import jsony
import ../types/tid
export TidPair

proc parseTidPairs*(raw: string): seq[TidPair] =
  result = raw.fromJson(seq[TidPair])
  if result.len == 0:
    raise newException(ValueError, "Parsing pairs failed: " & raw)
