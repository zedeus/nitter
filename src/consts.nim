# SPDX-License-Identifier: AGPL-3.0-only
import strutils

const
  consumerKey* = "3nVuSoBZnx6U4vzUxf5w"
  consumerSecret* = "Bcs59EFbbsdF6Sl9Ng71smgStWEGwXXKSjYvPVt7qys"
  bearerToken* = "Bearer AAAAAAAAAAAAAAAAAAAAANRILgAAAAAAnNwIzUejRCOuH5E6I8xnZz4puTs%3D1Zv7ttfk8LF81IUq16cHjhLTvJu4FA33AGWWjCpTnA"
  bearerToken2* = "Bearer AAAAAAAAAAAAAAAAAAAAAFXzAwAAAAAAMHCxpeSDG1gLNLghVe8d74hl6k4%3DRUMF4xAQLsbeBhTSRrCiQpJtxoGWeyHrDb5te2jpGskWDFW82F"

  graphUser* = "-oaLodhGbbnzJBACb1kk2Q/UserByScreenName"
  graphUserV2* = "WEoGnYB0EG1yGwamDCF6zg/UserResultByScreenNameQuery"
  graphUserById* = "VN33vKXrPT7p35DgNR27aw/UserResultByIdQuery"
  graphUserTweetsV2* = "6QdSuZ5feXxOadEdXa4XZg/UserWithProfileTweetsQueryV2"
  graphUserTweetsAndRepliesV2* = "BDX77Xzqypdt11-mDfgdpQ/UserWithProfileTweetsAndRepliesQueryV2"
  graphUserTweets* = "oRJs8SLCRNRbQzuZG93_oA/UserTweets"
  graphUserTweetsAndReplies* = "kkaJ0Mf34PZVarrxzLihjg/UserTweetsAndReplies"
  graphUserMedia* = "36oKqyQ7E_9CmtONGjJRsA/UserMedia"
  graphUserMediaV2* = "bp0e_WdXqgNBIwlLukzyYA/MediaTimelineV2"
  graphTweet* = "Y4Erk_-0hObvLpz0Iw3bzA/ConversationTimeline"
  graphTweetDetail* = "YVyS4SfwYW7Uw5qwy0mQCA/TweetDetail"
  graphTweetResult* = "nzme9KiYhfIOrrLrPP_XeQ/TweetResultByIdQuery"
  graphSearchTimeline* = "bshMIjqDk8LTXTq4w91WKw/SearchTimeline"
  graphListById* = "cIUpT1UjuGgl_oWiY7Snhg/ListByRestId"
  graphListBySlug* = "K6wihoTiTrzNzSF8y1aeKQ/ListBySlug"
  graphListMembers* = "fuVHh5-gFn8zDBBxb8wOMA/ListMembers"
  graphListTweets* = "VQf8_XQynI3WzH6xopOMMQ/ListTimeline"

  gqlFeatures* = """{
  "android_ad_formats_media_component_render_overlay_enabled": false,
  "android_graphql_skip_api_media_color_palette": false,
  "android_professional_link_spotlight_display_enabled": false,
  "blue_business_profile_image_shape_enabled": false,
  "commerce_android_shop_module_enabled": false,
  "creator_subscriptions_subscription_count_enabled": false,
  "creator_subscriptions_tweet_preview_api_enabled": true,
  "freedom_of_speech_not_reach_fetch_enabled": true,
  "graphql_is_translatable_rweb_tweet_is_translatable_enabled": true,
  "hidden_profile_likes_enabled": false,
  "highlights_tweets_tab_ui_enabled": false,
  "interactive_text_enabled": false,
  "longform_notetweets_consumption_enabled": true,
  "longform_notetweets_inline_media_enabled": true,
  "longform_notetweets_rich_text_read_enabled": true,
  "longform_notetweets_richtext_consumption_enabled": true,
  "mobile_app_spotlight_module_enabled": false,
  "responsive_web_edit_tweet_api_enabled": true,
  "responsive_web_enhance_cards_enabled": false,
  "responsive_web_graphql_exclude_directive_enabled": true,
  "responsive_web_graphql_skip_user_profile_image_extensions_enabled": false,
  "responsive_web_graphql_timeline_navigation_enabled": true,
  "responsive_web_media_download_video_enabled": false,
  "responsive_web_text_conversations_enabled": false,
  "responsive_web_twitter_article_tweet_consumption_enabled": true,
  "unified_cards_destination_url_params_enabled": false,
  "responsive_web_twitter_blue_verified_badge_is_enabled": true,
  "rweb_lists_timeline_redesign_enabled": true,
  "spaces_2022_h2_clipping": true,
  "spaces_2022_h2_spaces_communities": true,
  "standardized_nudges_misinfo": true,
  "subscriptions_verification_info_enabled": true,
  "subscriptions_verification_info_reason_enabled": true,
  "subscriptions_verification_info_verified_since_enabled": true,
  "super_follow_badge_privacy_enabled": false,
  "super_follow_exclusive_tweet_notifications_enabled": false,
  "super_follow_tweet_api_enabled": false,
  "super_follow_user_api_enabled": false,
  "tweet_awards_web_tipping_enabled": false,
  "tweet_with_visibility_results_prefer_gql_limited_actions_policy_enabled": true,
  "tweetypie_unmention_optimization_enabled": false,
  "unified_cards_ad_metadata_container_dynamic_card_content_query_enabled": false,
  "verified_phone_label_enabled": false,
  "vibe_api_enabled": false,
  "view_counts_everywhere_api_enabled": true,
  "premium_content_api_read_enabled": false,
  "communities_web_enable_tweet_community_results_fetch": true,
  "responsive_web_jetfuel_frame": true,
  "responsive_web_grok_analyze_button_fetch_trends_enabled": false,
  "responsive_web_grok_image_annotation_enabled": true,
  "responsive_web_grok_imagine_annotation_enabled": true,
  "rweb_tipjar_consumption_enabled": true,
  "profile_label_improvements_pcf_label_in_post_enabled": true,
  "creator_subscriptions_quote_tweet_preview_enabled": false,
  "c9s_tweet_anatomy_moderator_badge_enabled": true,
  "responsive_web_grok_analyze_post_followups_enabled": true,
  "rweb_video_timestamps_enabled": false,
  "responsive_web_grok_share_attachment_enabled": true,
  "articles_preview_enabled": true,
  "immersive_video_status_linkable_timestamps": false,
  "articles_api_enabled": false,
  "responsive_web_grok_analysis_button_from_backend": true,
  "rweb_video_screen_enabled": false,
  "payments_enabled": false,
  "responsive_web_profile_redirect_enabled": false,
  "responsive_web_grok_show_grok_translated_post": false,
  "responsive_web_grok_community_note_auto_translation_is_enabled": false,
  "profile_label_improvements_pcf_label_in_profile_enabled": false,
  "grok_android_analyze_trend_fetch_enabled": false,
  "grok_translations_community_note_auto_translation_is_enabled": false,
  "grok_translations_post_auto_translation_is_enabled": false,
  "grok_translations_community_note_translation_is_enabled": false,
  "grok_translations_timeline_user_bio_auto_translation_is_enabled": false,
  "subscriptions_feature_can_gift_premium": false,
  "responsive_web_twitter_article_notes_tab_enabled": false,
  "subscriptions_verification_info_is_identity_verified_enabled": false,
  "hidden_profile_subscriptions_enabled": false
}""".replace(" ", "").replace("\n", "")

  tweetVars* = """{
  "postId": "$1",
  $2
  "includeHasBirdwatchNotes": false,
  "includePromotedContent": false,
  "withBirdwatchNotes": false,
  "withVoice": false,
  "withV2Timeline": true
}""".replace(" ", "").replace("\n", "")

  tweetDetailVars* = """{
  "focalTweetId": "$1",
  $2
  "referrer": "profile",
  "with_rux_injections": false,
  "rankingMode": "Relevance",
  "includePromotedContent": true,
  "withCommunity": true,
  "withQuickPromoteEligibilityTweetFields": true,
  "withBirdwatchNotes": true,
  "withVoice": true
}""".replace(" ", "").replace("\n", "")

  restIdVars* = """{
  "rest_id": "$1", $2
  "count": 20
}"""

  userMediaVars* = """{
  "userId": "$1", $2
  "count": 20,
  "includePromotedContent": false,
  "withClientEventToken": false,
  "withBirdwatchNotes": false,
  "withVoice": true
}""".replace(" ", "").replace("\n", "")

  userTweetsVars* = """{
  "userId": "$1", $2
  "count": 20,
  "includePromotedContent": false,
  "withQuickPromoteEligibilityTweetFields": true,
  "withVoice": true
}""".replace(" ", "").replace("\n", "")

  userTweetsAndRepliesVars* = """{
  "userId": "$1", $2
  "count": 20,
  "includePromotedContent": false,
  "withCommunity": true,
  "withVoice": true
}""".replace(" ", "").replace("\n", "")

  userFieldToggles = """{"withPayments":false,"withAuxiliaryUserLabels":true}"""
  userTweetsFieldToggles* = """{"withArticlePlainText":false}"""
  tweetDetailFieldToggles* = """{"withArticleRichContentState":true,"withArticlePlainText":false,"withGrokAnalyze":false,"withDisallowedReplyControls":false}"""
