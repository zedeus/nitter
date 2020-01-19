import httpclient, strutils

proc getGuestId*(): string =
  let client = newHttpClient()
  for i in 0 .. 10:
    try:
      let req = client.get("https://twitter.com")
      if "react-root" in req.body: continue
      for k, v in req.headers:
        if "guest_id" in v:
          return v[v.find("=") + 1 .. v.find(";")]
    except:
      discard
    finally:
      try: client.close()
      except: discard
