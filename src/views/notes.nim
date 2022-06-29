# SPDX-License-Identifier: AGPL-3.0-only
import strutils, tables, strformat, unicode
import karax/[karaxdsl, vdom, vstyles]
from jester import Request

import renderutils
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

proc renderNoteParagraph(articleParagraph: ArticleParagraph; article: Article): VNode =
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
  else:
    result = p.newVNode()

  # Assume the style applies for the entire paragraph
  for styleRange in articleParagraph.inlineStyleRanges:
    case styleRange.style
    of ArticleStyle.bold:
      result.setAttr("style", "font-weight:bold")
    of ArticleStyle.italic:
      result.setAttr("style", "font-style:italic")
    of ArticleStyle.strikethrough:
      result.setAttr("style", "text-decoration:line-through")
    else: discard

  var last = 0
  for er in articleParagraph.entityRanges:
    # prevent karax from inserting whitespaces to fix wrapping
    result.add text ""

    # flush remaining text
    if er.offset > last:
      result.add verbatim text.runeSubStr(last, er.offset - last).replaceHashtagsAndMentions
    
    let entity = article.entities[er.key]
    case entity.entityType
    of ArticleEntityType.link:
      let link = buildHtml(a(href=entity.url)):
        text text.runeSubStr(er.offset, er.length)
      result.add link
    of ArticleEntityType.media:
      for id in entity.mediaIds:
        let url = article.media[id].getSmallPic
        let image = buildHtml(span(class="image")):
          img(src=url, alt="")
        result.add image
    of ArticleEntityType.twemoji:
      let url = entity.twemoji.getSmallPic
      let emoji = buildHtml(img(src=url, alt=""))
      result.add emoji
    of ArticleEntityType.tweet:
      let url = fmt"/i/status/{entity.tweetId}/embed"
      let iframe = buildHtml(iframe(src=url, loading="lazy", frameborder="0", style={maxWidth: "100%"}))
      result.add iframe
    else: discard

    last = er.offset + er.length
  
  # flush remaining text
  if last < text.len:
    result.add verbatim text.runeSubStr(last).replaceHashtagsAndMentions

proc renderNote*(article: Article; prefs: Prefs): VNode =
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

  for paragraph in article.paragraphs:
    let node = renderNoteParagraph(paragraph, article)
    
    let currentType = paragraph.baseType
    if currentType in [ArticleType.orderedListItem, ArticleType.unorderedListItem]:
      if currentType != listType:
        # flush last list
        if list != nil:
          main.add list
          list = nil

        case currentType:
        of ArticleType.orderedListItem:
          list = ol.newVNode()
        of ArticleType.unorderedListItem:
          list = ul.newVNode()
        else: discard
        listType = currentType
      list.add node
    else:
      if list != nil:
        main.add list
        list = nil
      main.add node

  buildHtml(tdiv(class="note")):
    img(class="cover", src=(cover), alt="")
    
    main
