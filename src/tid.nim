import std/[asyncdispatch, base64, httpclient, random, strutils, sequtils, times]
import nimcrypto
import experimental/parser/tid

randomize()

const defaultKeyword = "obfiowerehiring";
const pairsUrl =
  "https://raw.githubusercontent.com/fa0311/x-client-transaction-id-pair-dict/refs/heads/main/pair.json";

var
  cachedPairs: seq[TidPair] = @[]
  lastCached = 0
  # refresh every hour
  ttlSec = 60 * 60

proc getPair(): Future[TidPair] {.async.} =
  if cachedPairs.len == 0 or int(epochTime()) - lastCached > ttlSec:
    lastCached = int(epochTime())

    let client = newAsyncHttpClient()
    defer: client.close()

    let resp = await client.get(pairsUrl)
    if resp.status == $Http200:
      cachedPairs = parseTidPairs(await resp.body)

  return sample(cachedPairs)

proc encodeSha256(text: string): array[32, byte] =
  let
    data = cast[ptr byte](addr text[0])
    dataLen = uint(len(text))
    digest = sha256.digest(data, dataLen)
  return digest.data

proc encodeBase64[T](data: T): string =
  return encode(data).replace("=", "")

proc decodeBase64(data: string): seq[byte] =
  return cast[seq[byte]](decode(data))

proc genTid*(path: string): Future[string] {.async.} =
  let 
    pair = await getPair()

    timeNow = int(epochTime() - 1682924400)
    timeNowBytes = @[
      byte(timeNow and 0xff),
      byte((timeNow shr 8) and 0xff),
      byte((timeNow shr 16) and 0xff),
      byte((timeNow shr 24) and 0xff)
    ]

    data = "GET!" & path & "!" & $timeNow & defaultKeyword & pair.animationKey
    hashBytes = encodeSha256(data)
    keyBytes = decodeBase64(pair.verification)
    bytesArr = keyBytes & timeNowBytes & hashBytes[0 ..< 16] & @[3'u8]
    randomNum = byte(rand(256))
    tid = @[randomNum] & bytesArr.mapIt(it xor randomNum)

  return encodeBase64(tid)
