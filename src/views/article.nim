# SPDX-License-Identifier: AGPL-3.0-only
import strutils, strformat, tables, unicode, bitops, uri
import karax/[karaxdsl, vdom]

import renderutils, tweet, timeline
import ".."/[types, utils, formatters]

proc renderAtomicParagraph(paragraph: ArticleParagraph; article: Article;
                           tweets: Table[int64, Tweet]; path: string;
                           prefs: Prefs): VNode =
  if paragraph.entityRanges.len == 0:
    return text ""

  let er = paragraph.entityRanges[0]
  if er.key notin article.entities:
    return text ""

  let entity = article.entities[er.key]

  case entity.kind
  of "MEDIA":
    buildHtml(tdiv(class="article-media")):
      for id in entity.mediaIds:
        let media = article.media.getOrDefault(id)
        if media.url.len == 0:
          continue
        case media.kind
        of "ApiGif":
          video(src=getVidUrl(media.url), controls="", autoplay="", loop="",
                muted="")
        of "ApiVideo":
          video(src=getVidUrl(media.url), controls="")
        else:
          a(href=getOrigPicUrl(media.url), target="_blank"):
            img(src=getSmallPic(media.url), alt="", loading="lazy")
  of "TWEET":
    let tweet = tweets.getOrDefault(
      try: parseBiggestInt(entity.tweetId)
      except ValueError: 0, nil)
    if tweet != nil:
      renderTweet(tweet, prefs, path)
    else:
      text ""
  of "MARKDOWN":
    var content = entity.markdown
    if content.startsWith("```"):
      let firstNl = content.find('\n')
      if firstNl >= 0: content = content[firstNl + 1 .. ^1]
      if content.endsWith("```"): content = content[0 .. ^4]
      content = content.strip
    buildHtml(pre()):
      code(): text content
  of "DIVIDER":
    buildHtml(hr(class="article-divider"))
  else:
    text ""

proc wrapStyle(node: VNode; style: int): VNode =
  result = node
  if style.testBit(4): result = buildHtml(code()): result
  if style.testBit(0): result = buildHtml(strong()): result
  if style.testBit(1): result = buildHtml(em()): result
  if style.testBit(2): result = buildHtml(del()): result
  if style.testBit(3): result = buildHtml(underlined()): result

proc addContent(target: VNode; content: string; style = 0) =
  var first = true
  for line in content.split('\n'):
    if not first:
      target.add VNode(kind: VNodeKind.br)
    first = false
    var pos = 0
    while pos < line.len:
      let atPos = line.find('@', pos)
      if atPos == -1:
        target.add wrapStyle(text line[pos .. ^1], style)
        break
      if atPos > 0 and line[atPos - 1] in Letters + Digits + {'_'}:
        target.add wrapStyle(text line[pos .. atPos], style)
        pos = atPos + 1
        continue
      var j = atPos + 1
      while j < line.len and j - atPos - 1 < 15 and
            line[j] in Letters + Digits + {'_'}:
        inc j
      if j == atPos + 1:
        target.add wrapStyle(text line[pos .. atPos], style)
        pos = atPos + 1
        continue
      if atPos > pos:
        target.add wrapStyle(text line[pos ..< atPos], style)
      let username = line[atPos + 1 ..< j]
      let link = a.newVNode()
      link.setAttr("href", "/" & username)
      link.add wrapStyle(text ("@" & username), style)
      target.add link
      pos = j

proc applyInlineStyles(target: VNode; runes: seq[Rune]; start, length: int;
                       styles: seq[ArticleStyle]) =
  if styles.len == 0:
    target.addContent($runes[start ..< start + length])
    return

  var
    lastStyle = 0
    lastStart = start
  let endPos = start + length

  for i in start ..< endPos:
    var style = 0
    for sr in styles:
      let
        sStart = sr.offset
        sEnd = sStart + sr.length
      if sStart <= i and sEnd > i:
        case sr.style
        of "Bold": style.setBit(0)
        of "Italic": style.setBit(1)
        of "Strikethrough": style.setBit(2)
        of "Underline": style.setBit(3)
        of "Code": style.setBit(4)
        else: discard

    if style != lastStyle:
      if i > lastStart:
        addContent(target, $runes[lastStart ..< i], lastStyle)
      lastStyle = style
      lastStart = i

  if lastStart < endPos:
    addContent(target, $runes[lastStart ..< endPos], lastStyle)

proc renderTextParagraph(paragraph: ArticleParagraph; article: Article): VNode =
  let text = paragraph.text

  result = case paragraph.kind
    of "header-one": h1.newVNode()
    of "header-two": h2.newVNode()
    of "header-three": h3.newVNode()
    of "ordered-list-item", "unordered-list-item": li.newVNode()
    of "blockquote": VNode(kind: VNodeKind.blockquote)
    of "code-block":
      let pre = pre.newVNode()
      let code = code.newVNode()
      code.add text text
      pre.add code
      return pre
    else: p.newVNode()

  let
    runes = text.toRunes
    textLen = runes.len
  var last = 0
  for er in paragraph.entityRanges:
    if er.offset > last:
      applyInlineStyles(result, runes, last, er.offset - last,
                        paragraph.inlineStyles)

    last = er.offset + er.length

    var target = result
    if er.key in article.entities:
      let entity = article.entities[er.key]
      if entity.kind == "LINK":
        let parsed = parseUri(entity.url)
        if parsed.scheme in ["http", "https"]:
          target = a.newVNode()
          if parsed.isTwitterUrl:
            target.setAttr("href", parsed.path)
          else:
            target.setAttr("href", entity.url)

    applyInlineStyles(target, runes, er.offset, er.length,
                      paragraph.inlineStyles)
    if target != result:
      result.add target

  if last < textLen:
    applyInlineStyles(result, runes, last, textLen - last,
                      paragraph.inlineStyles)

  if paragraph.kind == "blockquote" and result.len > 0:
    let lastChild = result[result.len - 1]
    if lastChild.kind == VNodeKind.strong and lastChild.len > 0 and
       lastChild[0].kind == VNodeKind.text:
      lastChild.setAttr("class", "blockquote-attribution")

proc renderArticle*(article: Article; tweets: Table[int64, Tweet];
                    path: string; prefs: Prefs; tweetId=""): VNode =
  let author = article.user

  let main = buildHtml(article(class="article-body")):
    h1(class="article-title"): text article.title

    tdiv(class="article-author"):
      tdiv(class="article-author-row"):
        a(class="article-avatar", href=("/" & author.username)):
          genImg(author.getUserPic("_bigger"), class=prefs.getAvatarClass)
        tdiv(class="article-author-info"):
          tdiv(class="article-author-name"):
            linkUser(author, class="fullname")
            verifiedIcon(author)
          tdiv(class="article-author-meta"):
            linkUser(author, class="username")
            span(class="article-date-sep"): text " · "
            a(class="article-date",
              href=("/" & author.username & "/status/" & tweetId)):
              text article.time.getShortTime
      if not prefs.hideTweetStats:
        renderStats(article.stats)

  var listKind = ""
  var list: VNode = nil

  for paragraph in article.paragraphs:
    let isListItem = paragraph.kind in [
      "ordered-list-item", "unordered-list-item"]

    if not isListItem and list != nil:
      main.add list
      list = nil
      listKind = ""

    if paragraph.kind == "atomic":
      main.add renderAtomicParagraph(paragraph, article, tweets, path, prefs)
    elif isListItem:
      if paragraph.kind != listKind:
        if list != nil:
          main.add list
        list = if paragraph.kind == "ordered-list-item": ol.newVNode()
               else: ul.newVNode()
        listKind = paragraph.kind
      list.add renderTextParagraph(paragraph, article)
    else:
      main.add renderTextParagraph(paragraph, article)

  if list != nil:
    main.add list

  buildHtml(tdiv(class="article-page")):
    if article.coverImage.len > 0:
      a(href=getOrigPicUrl(article.coverImage), target="_blank"):
        img(class="article-cover", src=getSmallPic(article.coverImage), alt="")
    main
    renderToTop()
