import std/[macros, htmlgen, unicode]
import ../types/common
import ".."/../[formatters, utils]

type
  ReplaceSliceKind = enum
    rkRemove, rkUrl, rkHashtag, rkMention

  ReplaceSlice* = object
    slice: Slice[int]
    kind: ReplaceSliceKind
    url, display: string

proc cmp*(x, y: ReplaceSlice): int = cmp(x.slice.a, y.slice.b)

proc dedupSlices*(s: var seq[ReplaceSlice]) =
  var
    len = s.len
    i = 0
  while i < len:
    var j = i + 1
    while j < len:
      if s[i].slice.a == s[j].slice.a:
        s.del j
        dec len
      else:
        inc j
    inc i

proc extractUrls*(result: var seq[ReplaceSlice]; url: Url;
                  textLen: int; hideTwitter = false) =
  let
    link = url.expandedUrl
    slice = url.indices[0] ..< url.indices[1]

  if hideTwitter and slice.b.succ >= textLen and link.isTwitterUrl:
    if slice.a < textLen:
      result.add ReplaceSlice(kind: rkRemove, slice: slice)
  else:
    result.add ReplaceSlice(kind: rkUrl, url: link,
                            display: link.shortLink, slice: slice)

proc replacedWith*(runes: seq[Rune]; repls: openArray[ReplaceSlice];
                   textSlice: Slice[int]): string =
  template extractLowerBound(i: int; idx): int =
    if i > 0: repls[idx].slice.b.succ else: textSlice.a

  result = newStringOfCap(runes.len)

  for i, rep in repls:
    result.add $runes[extractLowerBound(i, i - 1) ..< rep.slice.a]
    case rep.kind
    of rkHashtag:
      let
        name = $runes[rep.slice.a.succ .. rep.slice.b]
        symbol = $runes[rep.slice.a]
      result.add a(symbol & name, href = "/search?q=%23" & name)
    of rkMention:
      result.add a($runes[rep.slice], href = rep.url, title = rep.display)
    of rkUrl:
      result.add a(rep.display, href = rep.url)
    of rkRemove:
      discard

  let rest = extractLowerBound(repls.len, ^1) ..< textSlice.b
  if rest.a <= rest.b:
    result.add $runes[rest]
