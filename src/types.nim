import times, sequtils

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
    verified*: bool
    protected*: bool

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
    retweetBy*: string
    pinned*: bool
    photos*: seq[string]
    gif*: string

  Tweets* = seq[Tweet]

  Conversation* = object
    tweet*: Tweet
    before*: Tweets
    after*: Tweets
    replies*: seq[Tweets]

proc contains*(thread: Tweets; tweet: Tweet): bool =
  thread.anyIt(it.id == tweet.id)
