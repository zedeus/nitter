# SPDX-License-Identifier: AGPL-3.0-only
import uri, sequtils, strutils

const
  auth* = "Bearer AAAAAAAAAAAAAAAAAAAAAFQODgEAAAAAVHTp76lzh3rFzcHbmHVvQxYYpTw%3DckAlMINMjmCwxUcaXbAN4XqJVdgMJaHqNOFgPMK0zN1qLqLQCF"

  api = parseUri("https://api.twitter.com")
  activate* = $(api / "1.1/guest/activate.json")

  photoRail* = api / "1.1/statuses/media_timeline.json"
  userSearch* = api / "1.1/users/search.json"

  graphql = api / "graphql"
  graphUser* = graphql / "u7wQyGi6oExe8_TRWGMq4Q/UserResultByScreenNameQuery"
  graphUserById* = graphql / "oPppcargziU1uDQHAUmH-A/UserResultByIdQuery"
  graphUserTweets* = graphql / "3JNH4e9dq1BifLxAa3UMWg/UserWithProfileTweetsQueryV2"
  graphUserTweetsAndReplies* = graphql / "8IS8MaO-2EN6GZZZb8jF0g/UserWithProfileTweetsAndRepliesQueryV2"
  graphUserMedia* = graphql / "PDfFf8hGeJvUCiTyWtw4wQ/MediaTimelineV2"
  graphTweet* = graphql / "83h5UyHZ9wEKBVzALX8R_g/ConversationTimelineV2"
  graphTweetResult* = graphql / "sITyJdhRPpvpEjg4waUmTA/TweetResultByIdQuery"
  graphSearchTimeline* = graphql / "gkjsKepM6gl_HmFWoWKfgg/SearchTimeline"
  graphListById* = graphql / "iTpgCtbdxrsJfyx0cFjHqg/ListByRestId"
  graphListBySlug* = graphql / "-kmqNvm5Y-cVrfvBy6docg/ListBySlug"
  graphListMembers* = graphql / "P4NpVZDqUD_7MEM84L-8nw/ListMembers"
  graphListTweets* = graphql / "BbGLL1ZfMibdFNWlk7a0Pw/ListTimeline"

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
  "android_graphql_skip_api_media_color_palette": false,
  "blue_business_profile_image_shape_enabled": false,
  "creator_subscriptions_subscription_count_enabled": false,
  "creator_subscriptions_tweet_preview_api_enabled": true,
  "freedom_of_speech_not_reach_fetch_enabled": false,
  "graphql_is_translatable_rweb_tweet_is_translatable_enabled": false,
  "hidden_profile_likes_enabled": false,
  "highlights_tweets_tab_ui_enabled": false,
  "interactive_text_enabled": false,
  "longform_notetweets_consumption_enabled": true,
  "longform_notetweets_inline_media_enabled": false,
  "longform_notetweets_richtext_consumption_enabled": true,
  "longform_notetweets_rich_text_read_enabled": false,
  "responsive_web_edit_tweet_api_enabled": false,
  "responsive_web_enhance_cards_enabled": false,
  "responsive_web_graphql_exclude_directive_enabled": true,
  "responsive_web_graphql_skip_user_profile_image_extensions_enabled": false,
  "responsive_web_graphql_timeline_navigation_enabled": false,
  "responsive_web_media_download_video_enabled": false,
  "responsive_web_text_conversations_enabled": false,
  "responsive_web_twitter_article_tweet_consumption_enabled": false,
  "responsive_web_twitter_blue_verified_badge_is_enabled": true,
  "rweb_lists_timeline_redesign_enabled": true,
  "spaces_2022_h2_clipping": true,
  "spaces_2022_h2_spaces_communities": true,
  "standardized_nudges_misinfo": false,
  "subscriptions_verification_info_enabled": true,
  "subscriptions_verification_info_reason_enabled": true,
  "subscriptions_verification_info_verified_since_enabled": true,
  "super_follow_badge_privacy_enabled": false,
  "super_follow_exclusive_tweet_notifications_enabled": false,
  "super_follow_tweet_api_enabled": false,
  "super_follow_user_api_enabled": false,
  "tweet_awards_web_tipping_enabled": false,
  "tweet_with_visibility_results_prefer_gql_limited_actions_policy_enabled": false,
  "tweetypie_unmention_optimization_enabled": false,
  "unified_cards_ad_metadata_container_dynamic_card_content_query_enabled": false,
  "verified_phone_label_enabled": false,
  "vibe_api_enabled": false,
  "view_counts_everywhere_api_enabled": false
}""".replace(" ", "").replace("\n", "")

  tweetVariables* = """{
  "focalTweetId": "$1",
  $2
  "includeHasBirdwatchNotes": false
}"""

  userTweetsVariables* = """{
  "rest_id": "$1", $2
  "count": 20
}"""

  listTweetsVariables* = """{
  "rest_id": "$1", $2
  "count": 20
}"""
