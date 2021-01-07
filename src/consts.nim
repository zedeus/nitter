import uri, sequtils

const
  auth* = "Bearer AAAAAAAAAAAAAAAAAAAAANRILgAAAAAAnNwIzUejRCOuH5E6I8xnZz4puTs%3D1Zv7ttfk8LF81IUq16cHjhLTvJu4FA33AGWWjCpTnA"

  api = parseUri("https://api.twitter.com")
  activate* = $(api / "1.1/guest/activate.json")

  listMembers* = api / "1.1/lists/members.json"
  userShow* = api / "1.1/users/show.json"
  photoRail* = api / "1.1/statuses/media_timeline.json"
  search* = api / "2/search/adaptive.json"

  timelineApi = api / "2/timeline"
  tweet* = timelineApi / "conversation"
  timeline* = timelineApi / "profile"
  mediaTimeline* = timelineApi / "media"
  listTimeline* = timelineApi / "list.json"

  graphql = api / "graphql"
  graphUser* = graphql / "E4iSsd6gypGFWx2eUhSC1g/UserByScreenName"
  graphList* = graphql / "ErWsz9cObLel1BF-HjuBlA/ListBySlug"
  graphListId* = graphql / "JADTh6cjebfgetzvF3tQvQ/List"

  timelineParams* = {
    "include_profile_interstitial_type": "0",
    "include_blocking": "0",
    "include_blocked_by": "0",
    "include_followed_by": "0",
    "include_want_retweets": "0",
    "include_mute_edge": "0",
    "include_can_dm": "0",
    "include_can_media_tag": "1",
    "skip_status": "1",
    "cards_platform": "Web-12",
    "include_cards": "1",
    "include_composer_source": "false",
    "include_ext_alt_text": "true",
    "include_reply_count": "1",
    "tweet_mode": "extended",
    "include_entities": "true",
    "include_user_entities": "true",
    "include_ext_media_color": "false",
    "include_ext_media_availability": "true",
    "send_error_codes": "true",
    "simple_quoted_tweet": "true",
    "ext": "mediaStats",
    "include_quote_count": "true"
  }.toSeq

  searchParams* = {
    "query_source": "typed_query",
    "pc": "1",
    "spelling_corrections": "1"
  }.toSeq
  ## top: nothing
  ## latest: "tweet_search_mode: live"
  ## user:   "result_filter: user"
  ## photos: "result_filter: photos"
  ## videos: "result_filter: videos"
