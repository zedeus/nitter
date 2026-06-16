import std/options
import graphuser
from ../../types import ArticleStyle, ArticleEntityRange

type
  GraphArticle* = object
    data*: tuple[tweetResult: tuple[result: TweetResultNode]]

  TweetResultNode* = object
    article*: tuple[articleResults: tuple[result: ArticleResultNode]]
    legacy*: TweetLegacy
    core*: tuple[userResults: UserData]
    views*: tuple[count: string]

  TweetLegacy* = object
    createdAt*: string
    replyCount*: int
    retweetCount*: int
    favoriteCount*: int

  ArticleResultNode* = object
    title*: string
    coverMedia*: tuple[mediaInfo: MediaInfoNode]
    contentState*: ContentState
    metadata*: tuple[firstPublishedAtSecs: int]
    mediaEntities*: seq[RawMediaEntity]

  ContentState* = object
    blocks*: seq[ContentBlock]
    entityMap*: seq[EntityMapEntry]

  ContentBlock* = object
    text*: string
    blockKind*: string
    inlineStyleRanges*: seq[ArticleStyle]
    entityRanges*: seq[ArticleEntityRange]

  EntityMapEntry* = object
    key*: string
    value*: EntityMapValue

  EntityMapValue* = object
    entityKind*: string
    data*: EntityDataNode

  EntityDataNode* = object
    url*: string
    mediaItems*: seq[tuple[mediaId: string]]
    tweetId*: string
    markdown*: string

  RawMediaEntity* = object
    mediaId*: string
    mediaInfo*: MediaInfoNode

  MediaInfoNode* = object
    typeName*: string
    originalImgUrl*: string
    videoInfo*: Option[VideoInfoNode]

  VideoInfoNode* = object
    variants*: seq[VideoVariant]

  VideoVariant* = object
    url*: string
    bitrate*: int

proc renameHook*(v: var ContentBlock; fieldName: var string) =
  if fieldName == "type":
    fieldName = "blockKind"

proc renameHook*(v: var EntityMapValue; fieldName: var string) =
  if fieldName == "type":
    fieldName = "entityKind"

proc renameHook*(v: var MediaInfoNode; fieldName: var string) =
  if fieldName == "__typename":
    fieldName = "typeName"
