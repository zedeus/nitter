# SPDX-License-Identifier: AGPL-3.0-only
import strutils, tables, unicode, bitops
import karax/[karaxdsl, vdom]
from jester import Request

import renderutils, tweet
import ".."/[types, utils, formatters]

const doctype = "<!DOCTYPE html>\n"

proc getSmallPic(url: string): string =
  result = url
  if "?" notin url and not url.endsWith("placeholder.png"):
    result &= "?name=small"
  result = getPicUrl(result)

proc renderMiniAvatar(user: User; prefs: Prefs): VNode =
  let url = getPicUrl(user.getUserPic("_mini"))
  buildHtml():
    img(class=(prefs.getAvatarClass & " mini"), src=url)

proc renderNoteParagraph(articleParagraph: ArticleParagraph; article: Article; tweets: Table[int64, Tweet]; path: string; prefs: Prefs): VNode =
  if articleParagraph.baseType == ArticleType.atomic:
    let er = articleParagraph.entityRanges[0]
    let entity = article.entities[er.key]

    case entity.entityType
    of ArticleEntityType.media:
      for id in entity.mediaIds:
        let media = article.media.getOrDefault(id)
        if media.url == "":
          discard
        case media.mediaType:
        of ArticleMediaType.image:
          let image = buildHtml(span(class="image")):
            img(src=media.url.getSmallPic, alt="")
          result = image
        of ArticleMediaType.gif:
          let video = buildHtml(span(class="image")):
            video(src=media.url.getVidUrl, controls="", autoplay="", loop="")
          result = video
        else: discard
    of ArticleEntityType.tweet:
      let tweet = tweets.getOrDefault(entity.tweetId.parseInt, nil)
      if tweet == nil: discard
      result = renderTweet(tweet, prefs, path, mainTweet=true)
    else: discard
  else:
    let text = articleParagraph.text

    case articleParagraph.baseType
    of ArticleType.headerOne:
      result = h1.newVNode()
    of ArticleType.headerTwo:
      result = h2.newVNode()
    of ArticleType.headerThree:
      result = h3.newVNode()
    of ArticleType.orderedListItem:
      result = li.newVNode()
    of ArticleType.unorderedListItem:
      result = li.newVNode()
    of ArticleType.atomic:
      result = nil
    else:
      result = p.newVNode()

    proc flushPlainText(target: VNode; start: int; len: int): void =
      if articleParagraph.inlineStyleRanges.len == 0:
        target.add verbatim text.runeSubStr(start, len).replaceHashtagsAndMentions
      else:

        proc flushInternal(start: int, len: int, style: int): void =
          let content = text.runeSubStr(start, len).replaceHashtagsAndMentions
          if style == 0:
            target.add text content
          else:
            let container = span.newVNode()
            container.add text content
            var styleStr = ""
            if style.testBit(0):
              styleStr.add "font-weight:bold;"
            if style.testBit(1):
              styleStr.add "font-style:italic;"
            if style.testBit(2):
              styleStr.add "text-decoration:line-through;"
            container.setAttr("style", styleStr)
            target.add container

        var
          lastStyle = 0
          lastStart = start

        for i in start..(start + len):
          var style = 0
          for styleRange in articleParagraph.inlineStyleRanges:
            let
              styleStart = styleRange.offset
              styleEnd = styleStart + styleRange.length
            if styleStart <= i and styleEnd > i:
              case styleRange.style:
              of ArticleStyle.bold:
                style.setBit(0)
              of ArticleStyle.italic:
                style.setBit(1)
              of ArticleStyle.strikethrough:
                style.setBit(2)
              else: discard
          
          if style != lastStyle:
            if i > lastStart:
              flushInternal(lastStart, i - lastStart, lastStyle)

            lastStyle = style
            lastStart = i
            
        if lastStart < len:
          flushInternal(lastStart, len - lastStart, lastStyle)

    var last = 0
    for er in articleParagraph.entityRanges:
      # prevent karax from inserting whitespaces to fix wrapping
      result.add text ""

      if er.offset > last:
        flushPlainText(result, last, er.offset - last)

      let entity = article.entities[er.key]
      case entity.entityType
      of ArticleEntityType.link:
        let link = buildHtml(a(href=entity.url)):
          text text.runeSubStr(er.offset, er.length)
        result.add link
      of ArticleEntityType.twemoji:
        let url = entity.twemoji.getSmallPic
        let emoji = buildHtml(img(class="twemoji", src=url, alt=""))
        result.add emoji
      else: discard

      last = er.offset + er.length

    # flush remaining text
    if last < text.len:
      flushPlainText(result, last, text.len - last)

proc renderNote*(article: Article; tweets: Table[int64, Tweet]; path: string; prefs: Prefs): VNode =
  let cover = getSmallPic(article.coverImage)
  let author = article.user

  # build header
  let main = buildHtml(article):
    h1: text article.title
    
    tdiv(class="author"):
      renderMiniAvatar(author, prefs)
      linkUser(author, class="fullname")
      linkUser(author, class="username")
      text " · "
      text article.time.getShortTime

  # add paragraphs
  var listType = ArticleType.unknown
  var list: VNode = nil

  proc flushList() =
    if list != nil:
      main.add list
      list = nil
      listType = ArticleType.unknown

  for paragraph in article.paragraphs:
    let node = renderNoteParagraph(paragraph, article, tweets, path, prefs)
    
    let currentType = paragraph.baseType
    if currentType in [ArticleType.orderedListItem, ArticleType.unorderedListItem]:
      if currentType != listType:
        flushList()

        case currentType:
        of ArticleType.orderedListItem:
          list = ol.newVNode()
        of ArticleType.unorderedListItem:
          list = ul.newVNode()
        else: discard
        listType = currentType
      list.add node
    else:
      flushList()
      main.add node
  
  flushList()

  buildHtml(tdiv(class="note")):
    img(class="cover", src=(cover), alt="")
    
    main
