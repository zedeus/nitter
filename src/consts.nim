# SPDX-License-Identifier: AGPL-3.0-only
import uri, sequtils

const
  auth* = "Bearer AAAAAAAAAAAAAAAAAAAAAPYXBAAAAAAACLXUNDekMxqa8h%2F40K4moUkGsoc%3DTYfbDKbT3jJPCEVnMYqilB28NHfOPqkca3qaAxGfsyKCs0wRbw"

  api = parseUri("https://api.twitter.com")
  activate* = $(api / "1.1/guest/activate.json")

  userShow* = api / "1.1/users/show.json"
  photoRail* = api / "1.1/statuses/media_timeline.json"
  status* = api / "1.1/statuses/show"
  search* = api / "2/search/adaptive.json"

  timelineApi = api / "2/timeline"
  timeline* = timelineApi / "profile"
  mediaTimeline* = timelineApi / "media"
  listTimeline* = timelineApi / "list.json"
  tweet* = timelineApi / "conversation"

  graphql = api / "graphql"
  graphUser* = graphql / "7mjxD3-C6BxitPMVQ6w0-Q/UserByScreenName"
  graphUserById* = graphql / "I5nvpI91ljifos1Y3Lltyg/UserByRestId"
  graphList* = graphql / "JADTh6cjebfgetzvF3tQvQ/List"
  graphListBySlug* = graphql / "ErWsz9cObLel1BF-HjuBlA/ListBySlug"
  graphListMembers* = graphql / "Ke6urWMeCV2UlKXGRy4sow/ListMembers"

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
    "include_reply_count": "1",
    "tweet_mode": "extended",
    "include_entities": "true",
    "include_user_entities": "true",
    "include_ext_media_color": "false",
    "send_error_codes": "true",
    "simple_quoted_tweet": "true",
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
