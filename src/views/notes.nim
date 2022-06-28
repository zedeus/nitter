# SPDX-License-Identifier: AGPL-3.0-only
import strutils, tables, strformat
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
  result = p.newVNode()

  if articleParagraph.inlineStyleRanges.len > 0:
    # Assume the style applies for the entire paragraph
    result.setAttr("style", "font-style:" & articleParagraph.inlineStyleRanges[0].style.toLowerAscii)

  var last = 0
  for er in articleParagraph.entityRanges:
    # flush remaining text
    if er.offset > last:
      result.add text text.substr(last, er.offset - 1)
    
    let entity = article.entities[er.key]
    case entity.entityType
    of ArticleEntityType.link:
      let link = buildHtml(a(href=entity.url)):
        text text.substr(er.offset, er.offset + er.length - 1)
      result.add link
    of ArticleEntityType.media:
      for id in entity.mediaIds:
        let url: string = article.media[id]
        let image = buildHtml(span(class="image")):
          img(src=url, alt="")
        result.add image
    of ArticleEntityType.tweet:
      let url = fmt"/i/status/{entity.tweetId}/embed"
      let iframe = buildHtml(iframe(src=url, loading="lazy", frameborder="0", style={maxWidth: "100%"}))
      result.add iframe
    else: discard

    last = er.offset + er.length
  
  # flush remaining text
  if last < text.len:
    result.add text text.substr(last)

proc renderNote*(article: Article; prefs: Prefs): VNode =
  let cover = getSmallPic(article.coverImage)
  let author = article.user

  buildHtml(tdiv(class="note")):
      img(class="cover", src=(cover), alt="")
      
      article:
        h1: text article.title
        
        tdiv(class="author"):
          renderMiniAvatar(author, prefs)
          linkUser(author, class="fullname")
          linkUser(author, class="username")
          text " · "
          text article.time.getShortTime

        for paragraph in article.paragraphs:
          renderNoteParagraph(paragraph, article)
