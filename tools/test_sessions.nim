# SPDX-License-Identifier: AGPL-3.0-only
# Test each cookie session in a JSONL file by hitting the UserMedia endpoint.
#
# Usage:
#   nim r --path:src tools/test_sessions.nim [sessions_file] [--delay N]
#
# Examples:
#   nim r --path:src tools/test_sessions.nim
#   nim r --path:src tools/test_sessions.nim sessions_cookie.jsonl --delay 1

import asyncdispatch, httpclient, strutils, uri, os, zippy
import apiutils, auth, consts, types
import experimental/parser/session

const
  # jack (id=12) — public account with media, same target as ratelimit_probe.py
  testVars = userMediaVars % ["12", "", "20"]

# Build the ApiReq once — same for every session
let
  testUrl = ApiUrl(endpoint: graphUserMedia,
                   params: @[("variables", testVars), ("features", gqlFeatures)])
  testReq = ApiReq(cookie: testUrl, oauth: testUrl)
  url = testReq.toUrl(SessionKind.cookie)

proc parseCookieSessions(path: string): seq[Session] =
  var skipped = 0
  for line in path.lines:
    let s = line.strip()
    if s.len == 0: continue
    try:
      let sess = parseSession(s)
      if sess.kind == SessionKind.cookie:
        result.add sess
      else:
        inc skipped
    except Exception as e:
      echo "  [!] Parse error: ", e.msg
  if skipped > 0:
    echo "  (skipped ", skipped, " non-cookie sessions)"

proc testSession(session: Session): Future[tuple[ok: bool, code: int,
    remaining, limit: int, detail: string]] {.async.} =
  let headers = await genHeaders(session, url, skipTid = false)
  let client = newAsyncHttpClient(headers = headers)
  defer: client.close()

  try:
    let resp = await client.get($url)
    var body = await resp.body
    if resp.headers.getOrDefault("content-encoding") == "gzip":
      body = uncompress(body, dfGzip)

    var remaining, limit: int
    if resp.headers.hasKey("x-rate-limit-remaining"):
      remaining = parseInt(resp.headers["x-rate-limit-remaining"])
    if resp.headers.hasKey("x-rate-limit-limit"):
      limit = parseInt(resp.headers["x-rate-limit-limit"])

    if resp.code == Http200:
      return (true, resp.code.int, remaining, limit, "")
    else:
      let detail = if body.len in 1..120: body else: ""
      return (false, resp.code.int, remaining, limit, detail)
  except Exception as e:
    return (false, 0, 0, 0, e.msg[0 ..< min(e.msg.len, 120)])

proc main() {.async.} =
  var
    sessionsPath = "sessions.jsonl"
    delay = 500  # ms
    i = 1

  while i <= paramCount():
    let arg = paramStr(i)
    case arg
    of "--delay":
      inc i
      if i > paramCount():
        echo "Error: --delay requires a value (seconds)"; quit(1)
      delay = int(parseFloat(paramStr(i)) * 1000)
    of "--help", "-h":
      echo "Usage: nim r --path:src tools/test_sessions.nim [sessions_file] [--delay N]"
      return
    else:
      sessionsPath = arg
    inc i

  if not fileExists(sessionsPath):
    echo "File not found: ", sessionsPath; quit(1)

  setApiProxy("")
  setDisableTid(false)

  let sessions = parseCookieSessions(sessionsPath)
  if sessions.len == 0:
    echo "No cookie sessions found in ", sessionsPath; quit(0)

  echo "Testing ", sessions.len, " sessions from ", sessionsPath
  echo ""

  var
    nValid, nFail: int
    failures: seq[string]

  for idx, session in sessions:
    let
      num = idx + 1
      prefix = "[" & $num & "/" & $sessions.len & "] " & session.pretty
      res = await testSession(session)

    if res.ok:
      inc nValid
      var extra = ""
      if res.limit > 0:
        extra = "  remaining=" & $res.remaining & "/" & $res.limit
      echo prefix, "  ✓ ", res.code, extra
    else:
      inc nFail
      let detail = if res.code > 0: $res.code else: "error: " & res.detail
      failures.add session.pretty & "  " & detail
      echo prefix, "  ✗ ", detail

    if num < sessions.len and delay > 0:
      await sleepAsync(delay)

  echo ""
  echo "Done: ", nValid, " valid, ", nFail, " invalid  [", sessions.len, " total]"

  if failures.len > 0:
    echo ""
    echo "Failures:"
    for f in failures:
      echo "  ", f

waitFor main()
