import strutils, strformat, uri
import nimcrypto

const key = "supersecretkey"

proc mimetype*(filename: string): string =
  if ".png" in filename:
    return "image/" & "png"
  elif ".jpg" in filename or ".jpeg" in filename:
    return "image/" & "jpg"
  elif ".mp4" in filename:
    return "video/" & "mp4"
  else:
    return "text/plain"

proc getHmac*(data: string): string =
  ($hmac(sha256, key, data))[0 .. 12]

proc getSigUrl*(link: string; path: string): string =
  let
    sig = getHmac(link)
    url = encodeUrl(link)
  &"/{path}/{sig}/{url}"
