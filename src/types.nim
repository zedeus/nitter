import times, sequtils, strutils, options
import norm/sqlite

export sqlite, options

db("cache.db", "", "", ""):
  type
    Profile* = object
      username*: string
      fullname*: string
      description*: string
      userpic*: string
      banner*: string
      following*: string
      followers*: string
      tweets*: string
      verified* {.
          dbType: "STRING",
          parseIt: parseBool(it.s)
          formatIt: $it
        .}: bool
      protected* {.
          dbType: "STRING",
          parseIt: parseBool(it.s)
          formatIt: $it
        .}: bool
      updated* {.
          dbType: "INTEGER",
          parseIt: it.i.fromUnix(),
          formatIt: getTime().toUnix()
        .}: Time

type
  Tweet* = object
    id*: string
    profile*: Profile
    link*: string
    text*: string
    time*: Time
    shortTime*: string
    replies*: string
    retweets*: string
    likes*: string
    pinned*: bool
    photos*: seq[string]
    retweetBy*: Option[string]
    gif*: Option[string]
    video*: Option[string]
    videoThumb*: Option[string]

  Tweets* = seq[Tweet]

  Conversation* = object
    tweet*: Tweet
    before*: Tweets
    after*: Tweets
    replies*: seq[Tweets]

proc contains*(thread: Tweets; tweet: Tweet): bool =
  thread.anyIt(it.id == tweet.id)
