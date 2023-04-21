# SPDX-License-Identifier: AGPL-3.0-only
import uri, sequtils, strutils

const
  auth* = "Bearer AAAAAAAAAAAAAAAAAAAAANRILgAAAAAAnNwIzUejRCOuH5E6I8xnZz4puTs%3D1Zv7ttfk8LF81IUq16cHjhLTvJu4FA33AGWWjCpTnA"

  api = parseUri("https://api.twitter.com")
  activate* = $(api / "1.1/guest/activate.json")

  photoRail* = api / "1.1/statuses/media_timeline.json"
  userSearch* = api / "1.1/users/search.json"

  graphql = api / "graphql"
  graphUser* = graphql / "8mPfHBetXOg-EHAyeVxUoA/UserByScreenName"
  graphUserById* = graphql / "nI8WydSd-X-lQIVo6bdktQ/UserByRestId"
  graphUserTweets* = graphql / "9rys0A7w1EyqVd2ME0QCJg/UserTweets"
  graphUserTweetsAndReplies* = graphql / "ehMCHF3Mkgjsfz_aImqOsg/UserTweetsAndReplies"
  graphUserMedia* = graphql / "MA_EP2a21zpzNWKRkaPBMg/UserMedia"
  graphTweet* = graphql / "6I7Hm635Q6ftv69L8VrSeQ/TweetDetail"
  graphTweetResult* = graphql / "rt-rHeSJ-2H9O9gxWQcPcg/TweetResultByRestId"
  graphSearchTimeline* = graphql / "gkjsKepM6gl_HmFWoWKfgg/SearchTimeline"
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
    "include_ext_is_blue_verified": "1",
    "skip_status": "1",
    "cards_platform": "Web-12",
    "include_cards": "1",
    "include_composer_source": "0",
    "include_reply_count": "1",
    "tweet_mode": "extended",
    "include_entities": "1",
    "include_user_entities": "1",
    "include_ext_media_color": "0",
    "send_error_codes": "1",
    "simple_quoted_tweet": "1",
    "include_quote_count": "1"
  }.toSeq

  gqlFeatures* = """{
  "blue_business_profile_image_shape_enabled": false,
  "freedom_of_speech_not_reach_fetch_enabled": false,
  "graphql_is_translatable_rweb_tweet_is_translatable_enabled": false,
  "interactive_text_enabled": false,
  "longform_notetweets_consumption_enabled": true,
  "longform_notetweets_richtext_consumption_enabled": true,
  "longform_notetweets_rich_text_read_enabled": false,
  "responsive_web_edit_tweet_api_enabled": false,
  "responsive_web_enhance_cards_enabled": false,
  "responsive_web_graphql_exclude_directive_enabled": true,
  "responsive_web_graphql_skip_user_profile_image_extensions_enabled": false,
  "responsive_web_graphql_timeline_navigation_enabled": false,
  "responsive_web_text_conversations_enabled": false,
  "responsive_web_twitter_blue_verified_badge_is_enabled": true,
  "spaces_2022_h2_clipping": true,
  "spaces_2022_h2_spaces_communities": true,
  "standardized_nudges_misinfo": false,
  "tweet_awards_web_tipping_enabled": false,
  "tweet_with_visibility_results_prefer_gql_limited_actions_policy_enabled": false,
  "tweetypie_unmention_optimization_enabled": false,
  "verified_phone_label_enabled": false,
  "vibe_api_enabled": false,
  "view_counts_everywhere_api_enabled": false
}""".replace(" ", "").replace("\n", "")

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
  "withVoice": false,
  "withV2Timeline": true
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
