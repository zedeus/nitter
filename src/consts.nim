# SPDX-License-Identifier: AGPL-3.0-only
import uri, sequtils

const
  auth* = "Bearer AAAAAAAAAAAAAAAAAAAAAPYXBAAAAAAACLXUNDekMxqa8h%2F40K4moUkGsoc%3DTYfbDKbT3jJPCEVnMYqilB28NHfOPqkca3qaAxGfsyKCs0wRbw"

  api = parseUri("https://api.twitter.com")
  activate* = $(api / "1.1/guest/activate.json")

  photoRail* = api / "1.1/statuses/media_timeline.json"
  status* = api / "1.1/statuses/show"
  search* = api / "2/search/adaptive.json"

  graphql = api / "graphql"
  graphUser* = graphql / "8mPfHBetXOg-EHAyeVxUoA/UserByScreenName"
  graphUserById* = graphql / "nI8WydSd-X-lQIVo6bdktQ/UserByRestId"
  graphUserTweets* = graphql / "9rys0A7w1EyqVd2ME0QCJg/UserTweets"
  graphUserTweetsAndReplies* = graphql / "ehMCHF3Mkgjsfz_aImqOsg/UserTweetsAndReplies"
  graphUserMedia* = graphql / "MA_EP2a21zpzNWKRkaPBMg/UserMedia"
  graphTweet* = graphql / "6I7Hm635Q6ftv69L8VrSeQ/TweetDetail"
  graphTweetResult* = graphql / "rt-rHeSJ-2H9O9gxWQcPcg/TweetResultByRestId"
  graphListById* = graphql / "iTpgCtbdxrsJfyx0cFjHqg/ListByRestId"
  graphListBySlug* = graphql / "-kmqNvm5Y-cVrfvBy6docg/ListBySlug"
  graphListMembers* = graphql / "P4NpVZDqUD_7MEM84L-8nw/ListMembers"
  graphListTweets* = graphql / "jZntL0oVJSdjhmPcdbw_eA/ListLatestTweetsTimeline"

  timelineParams* = {
    "include_profile_interstitial_type": "0",
    "include_blocking": "0",
    "include_blocked_by": "0",
    "include_followed_by": "0",
    "include_want_retweets": "0",
    "include_mute_edge": "0",
    "include_can_dm": "0",
    "include_can_media_tag": "1",
    "include_ext_is_blue_verified": "true",
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

  gqlFeatures* = """{
  "longform_notetweets_consumption_enabled": true,
  "longform_notetweets_richtext_consumption_enabled": true,
  "responsive_web_twitter_blue_verified_badge_is_enabled": true,
  "responsive_web_graphql_exclude_directive_enabled": true,
  "freedom_of_speech_not_reach_fetch_enabled": false,
  "graphql_is_translatable_rweb_tweet_is_translatable_enabled": false,
  "interactive_text_enabled": false,
  "responsive_web_edit_tweet_api_enabled": false,
  "responsive_web_enhance_cards_enabled": false,
  "responsive_web_graphql_skip_user_profile_image_extensions_enabled": false,
  "responsive_web_graphql_timeline_navigation_enabled": false,
  "responsive_web_text_conversations_enabled": false,
  "standardized_nudges_misinfo": false,
  "tweet_awards_web_tipping_enabled": false,
  "tweet_with_visibility_results_prefer_gql_limited_actions_policy_enabled": false,
  "tweetypie_unmention_optimization_enabled": false,
  "view_counts_everywhere_api_enabled": false,
  "vibe_api_enabled": false,
  "verified_phone_label_enabled": false
}"""

  tweetVariables* = """{
  "focalTweetId": "$1",
  $2
  "withBirdwatchNotes": false,
  "includePromotedContent": false,
  "withDownvotePerspective": false,
  "withReactionsMetadata": false,
  "withReactionsPerspective": false,
  "withVoice": false
}"""

  tweetResultVariables* = """{
  "tweetId": "$1",
  "includePromotedContent": false,
  "withDownvotePerspective": false,
  "withReactionsMetadata": false,
  "withReactionsPerspective": false,
  "withVoice": false,
  "withCommunity": false
}"""

  userTweetsVariables* = """{
  "userId": "$1", $2
  "count": 20,
  "includePromotedContent": false,
  "withDownvotePerspective": false,
  "withReactionsMetadata": false,
  "withReactionsPerspective": false,
  "withVoice": false
}"""

  listTweetsVariables* = """{
  "listId": "$1", $2
  "count": 20,
  "includePromotedContent": false,
  "withDownvotePerspective": false,
  "withReactionsMetadata": false,
  "withReactionsPerspective": false,
  "withVoice": false
}"""
