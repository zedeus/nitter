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
  graphUserTweets* = graphql / "9rys0A7w1EyqVd2ME0QCJg/UserTweets"
  graphUserTweetsAndReplies* = graphql / "ehMCHF3Mkgjsfz_aImqOsg/UserTweetsAndReplies"
  graphTweet* = graphql / "6lWNh96EXDJCXl05SAtn_g/TweetDetail"
  graphUser* = graphql / "nZjSkpOpSL5rWyIVdsKeLA/UserByScreenName"
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

  userTweetsVariables* = """{
  "userId": "$1",
  $2
  "count": 20,
  "includePromotedContent": false,
  "withDownvotePerspective": false,
  "withReactionsMetadata": false,
  "withReactionsPerspective": false,
  "withVoice": false,
  "withV2Timeline": true
}"""

  userTweetsFeatures* = """{
  "responsive_web_twitter_blue_verified_badge_is_enabled": true,
  "responsive_web_graphql_exclude_directive_enabled": false,
  "verified_phone_label_enabled": false,
  "responsive_web_graphql_timeline_navigation_enabled": false,
  "responsive_web_graphql_skip_user_profile_image_extensions_enabled": false,
  "tweetypie_unmention_optimization_enabled": false,
  "vibe_api_enabled": false,
  "responsive_web_edit_tweet_api_enabled": false,
  "graphql_is_translatable_rweb_tweet_is_translatable_enabled": false,
  "view_counts_everywhere_api_enabled": false,
  "longform_notetweets_consumption_enabled": true,
  "tweet_awards_web_tipping_enabled": false,
  "freedom_of_speech_not_reach_fetch_enabled": false,
  "standardized_nudges_misinfo": false,
  "tweet_with_visibility_results_prefer_gql_limited_actions_policy_enabled": false,
  "interactive_text_enabled": false,
  "responsive_web_text_conversations_enabled": false,
  "longform_notetweets_richtext_consumption_enabled": false,
  "responsive_web_enhance_cards_enabled": false
}"""

  tweetVariables* = """{
  "focalTweetId": "$1",
  $2
  "includePromotedContent": false,
  "withBirdwatchNotes": false,
  "withDownvotePerspective": false,
  "withReactionsMetadata": false,
  "withReactionsPerspective": false,
  "withSuperFollowsTweetFields": false,
  "withSuperFollowsUserFields": false,
  "withVoice": false,
  "withV2Timeline": true
}"""

  tweetFeatures* = """{
  "graphql_is_translatable_rweb_tweet_is_translatable_enabled": false,
  "responsive_web_graphql_timeline_navigation_enabled": false,
  "standardized_nudges_misinfo": false,
  "verified_phone_label_enabled": false,
  "responsive_web_twitter_blue_verified_badge_is_enabled": true,
  "tweet_with_visibility_results_prefer_gql_limited_actions_policy_enabled": false,
  "view_counts_everywhere_api_enabled": false,
  "responsive_web_edit_tweet_api_enabled": false,
  "tweetypie_unmention_optimization_enabled": false,
  "vibe_api_enabled": false,
  "longform_notetweets_consumption_enabled": true,
  "responsive_web_text_conversations_enabled": false,
  "responsive_web_enhance_cards_enabled": false,
  "interactive_text_enabled": false
}"""

  userFeatures* = """{
  "responsive_web_twitter_blue_verified_badge_is_enabled": true,
  "verified_phone_label_enabled": false,
  "responsive_web_graphql_timeline_navigation_enabled": false,
  "responsive_web_graphql_exclude_directive_enabled": true,
  "responsive_web_graphql_skip_user_profile_image_extensions_enabled": true
}"""
