# SPDX-License-Identifier: AGPL-3.0-only
import std/[strutils, tables, times, options]
import jsony
import utils, graphql, ../types/article
from ../../types import Article, ArticleParagraph, ArticleEntity, ArticleMedia,
                        User, TweetStats

proc parseGraphArticle*(json: string): Article =
  if json.len == 0 or json[0] != '{':
    return

  var raw: GraphArticle
  try:
    raw = json.fromJson(GraphArticle)
  except CatchableError:
    return

  let
    tweet = raw.data.tweetResult.result
    article = tweet.article.articleResults.result

  if article.title.len == 0:
    return

  let publishedAt = article.metadata.firstPublishedAtSecs
  var articleTime: DateTime
  if publishedAt > 0:
    articleTime = publishedAt.int64.fromUnix.utc
  elif tweet.legacy.createdAt.len > 0:
    articleTime = parseTwitterDate(tweet.legacy.createdAt)

  result = Article(
    title: article.title,
    coverImage: getImageUrl(article.coverMedia.mediaInfo.originalImgUrl),
    time: articleTime,
    user: parseUserResult(tweet.core.userResults.result),
  )

  result.stats = TweetStats(
    replies: tweet.legacy.replyCount,
    retweets: tweet.legacy.retweetCount,
    likes: tweet.legacy.favoriteCount,
  )
  if tweet.views.count.len > 0:
    try: result.stats.views = parseInt(tweet.views.count)
    except ValueError: discard

  for blk in article.contentState.blocks:
    result.paragraphs.add ArticleParagraph(
      text: blk.text,
      kind: blk.blockKind,
      inlineStyles: blk.inlineStyleRanges,
      entityRanges: blk.entityRanges,
    )

  for entry in article.contentState.entityMap:
    let key = try: parseInt(entry.key) except ValueError: continue
    var entity = ArticleEntity(kind: entry.value.entityKind)
    case entity.kind
    of "LINK": entity.url = entry.value.data.url
    of "MEDIA":
      for mi in entry.value.data.mediaItems:
        entity.mediaIds.add mi.mediaId
      entity.caption = entry.value.data.caption
    of "TWEET": entity.tweetId = entry.value.data.tweetId
    of "MARKDOWN": entity.markdown = entry.value.data.markdown
    else: discard
    result.entities[key] = entity

  for me in article.mediaEntities:
    let typeName = me.mediaInfo.typeName
    var media = ArticleMedia(kind: typeName)
    if me.mediaInfo.videoInfo.isSome:
      let variants = me.mediaInfo.videoInfo.get.variants
      case typeName
      of "ApiGif":
        if variants.len > 0:
          media.url = variants[0].url
      of "ApiVideo":
        var bestBitrate = -1
        for v in variants:
          if v.bitrate > bestBitrate:
            bestBitrate = v.bitrate
            media.url = v.url
      else: discard
    elif typeName == "ApiImage":
      media.url = getImageUrl(me.mediaInfo.originalImgUrl)
    result.media[me.mediaId] = media
