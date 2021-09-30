import uri
import jester
import types, query

proc getLinkHeader*(results: Result, req: Request): string =
  let
    cursor = results.bottom
    query = results.query
  var url = if req.secure: "https://" else: "http://"
  url &= req.host & req.path
  var links = newLinkHeader()
  links["first"] = url & "?" & genQueryUrl(query)
  if results.content.len > 0 and results.bottom.len > 0:
    links["next"] = url & "?" & genQueryUrl(query) & "&cursor=" & encodeUrl(cursor)
  result = $links
