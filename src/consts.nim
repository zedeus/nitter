# SPDX-License-Identifier: AGPL-3.0-only
import uri, strutils

const
  consumerKey* = "3nVuSoBZnx6U4vzUxf5w"
  consumerSecret* = "Bcs59EFbbsdF6Sl9Ng71smgStWEGwXXKSjYvPVt7qys"

  gql = parseUri("https://api.x.com") / "graphql"

  graphUser* = gql / "u7wQyGi6oExe8_TRWGMq4Q/UserResultByScreenNameQuery"
  graphUserById* = gql / "oPppcargziU1uDQHAUmH-A/UserResultByIdQuery"
  graphUserTweets* = gql / "JLApJKFY0MxGTzCoK6ps8Q/UserWithProfileTweetsQueryV2"
  graphUserTweetsAndReplies* = gql / "Y86LQY7KMvxn5tu3hFTyPg/UserWithProfileTweetsAndRepliesQueryV2"
  graphUserMedia* = gql / "PDfFf8hGeJvUCiTyWtw4wQ/MediaTimelineV2"
  graphTweet* = gql / "Vorskcd2tZ-tc4Gx3zbk4Q/ConversationTimelineV2"
  graphTweetResult* = gql / "sITyJdhRPpvpEjg4waUmTA/TweetResultByIdQuery"
  graphSearchTimeline* = gql / "KI9jCXUx3Ymt-hDKLOZb9Q/SearchTimeline"
  graphListById* = gql / "oygmAig8kjn0pKsx_bUadQ/ListByRestId"
  graphListBySlug* = gql / "88GTz-IPPWLn1EiU8XoNVg/ListBySlug"
  graphListMembers* = gql / "kSmxeqEeelqdHSR7jMnb_w/ListMembers"
  graphListTweets* = gql / "BbGLL1ZfMibdFNWlk7a0Pw/ListTimeline"

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
  "view_counts_everywhere_api_enabled": false,
  "premium_content_api_read_enabled": false,
  "communities_web_enable_tweet_community_results_fetch": false,
  "responsive_web_jetfuel_frame": false,
  "responsive_web_grok_analyze_button_fetch_trends_enabled": false,
  "responsive_web_grok_image_annotation_enabled": false,
  "rweb_tipjar_consumption_enabled": false,
  "profile_label_improvements_pcf_label_in_post_enabled": false,
  "creator_subscriptions_quote_tweet_preview_enabled": false,
  "c9s_tweet_anatomy_moderator_badge_enabled": false,
  "responsive_web_grok_analyze_post_followups_enabled": false,
  "rweb_video_timestamps_enabled": false,
  "responsive_web_grok_share_attachment_enabled": false,
  "articles_preview_enabled": false,
  "immersive_video_status_linkable_timestamps": false,
  "articles_api_enabled": false,
  "responsive_web_grok_analysis_button_from_backend": false
}""".replace(" ", "").replace("\n", "")

  tweetVariables* = """{
  "focalTweetId": "$1",
  $2
  "includeHasBirdwatchNotes": false,
  "includePromotedContent": false,
  "withBirdwatchNotes": false,
  "withVoice": false,
  "withV2Timeline": true
}""".replace(" ", "").replace("\n", "")

#   oldUserTweetsVariables* = """{
#   "userId": "$1", $2
#   "count": 20,
#   "includePromotedContent": false,
#   "withDownvotePerspective": false,
#   "withReactionsMetadata": false,
#   "withReactionsPerspective": false,
#   "withVoice": false,
#   "withV2Timeline": true
# }
# """

  userTweetsVariables* = """{
  "rest_id": "$1", $2
  "count": 20
}"""

  listTweetsVariables* = """{
  "rest_id": "$1", $2
  "count": 20
}"""
