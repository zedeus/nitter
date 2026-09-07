import options, strutils, unittest
import karax/vdom

import ../src/types
import ../src/views/[search, tweet]

suite "linkified feed users":
  test "multi-feed header links each username":
    let timeline = Timeline(query: Query(kind: tweets, fromUser: @["alice", "bob"]))

    let html = $renderTweetSearch(timeline, Prefs(), "")

    check "href=\"/alice\"" in html
    check "href=\"/bob\"" in html

  test "retweet header links the retweeter":
    let original = Tweet(
      available: true,
      user: User(username: "author", fullname: "Author")
    )
    let repost = Tweet(
      available: true,
      user: User(username: "booster", fullname: "Booster"),
      retweet: some(original)
    )

    let html = $renderTweet(repost, Prefs(), "")

    check "href=\"/booster\"" in html
    check "Booster retweeted" in html
