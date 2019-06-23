import strutils, strformat, uri
import nimcrypto, regex

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

proc cleanFilename*(filename: string): string =
  const reg = re"[^A-Za-z0-9._-]"
  filename.replace(reg, "_")
