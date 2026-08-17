# SPDX-License-Identifier: AGPL-3.0-only
import strutils

const
  consumerKey* = "3nVuSoBZnx6U4vzUxf5w"
  consumerSecret* = "Bcs59EFbbsdF6Sl9Ng71smgStWEGwXXKSjYvPVt7qys"
  bearerToken* = "Bearer AAAAAAAAAAAAAAAAAAAAANRILgAAAAAAnNwIzUejRCOuH5E6I8xnZz4puTs%3D1Zv7ttfk8LF81IUq16cHjhLTvJu4FA33AGWWjCpTnA"
  bearerToken2* = "Bearer AAAAAAAAAAAAAAAAAAAAAFXzAwAAAAAAMHCxpeSDG1gLNLghVe8d74hl6k4%3DRUMF4xAQLsbeBhTSRrCiQpJtxoGWeyHrDb5te2jpGskWDFW82F"

  graphUser* = "Gb-d6r0vxPOADdG62OEBpQ/UserByScreenName"
  graphUserV2* = "-ZzAG_Bckx16LMbEvHC3lg/UserResultByScreenNameQuery"
  graphUserById* = "xvmVfRLmnr1alc5f2dib0Q/UserByRestId"
  graphUserTweetsV2* = "LE3eTyeqhBh2g-fX85O2eQ/UserWithProfileTweetsQueryV2"
  graphUserTweetsAndRepliesV2* = "AcYHjc_YAx-9_rKWdMsKvA/UserWithProfileTweetsAndRepliesQueryV2"
  graphUserTweets* = "SXVCYB8XHSS25nzIljNtZA/UserTweets"
  graphUserTweetsAndReplies* = "qUpkZU6eN8MbtQb7rC_pYg/UserTweetsAndReplies"
  graphUserMedia* = "VyudDWQnr9vJNw7GasFz2g/UserMedia"
  graphUserMediaV2* = "WK111rbR0vM0ZX4lyZCYjw/MediaTimelineV2"
  graphTweet* = "OZMbEnEa96AN8Pq6HyTWdw/ConversationTimeline"
  graphTweetDetail* = "XMOz5h24KAZ86qKffKTLdQ/TweetDetail"
  graphTweetResult* = "xYOrBQoTlfKJJPsX76MZEw/TweetResultByIdQuery"
  graphTweetEditHistory* = "1izbuOcH_QpuMcyCxOXkAg/TweetEditHistory"
  graphSearchTimeline* = "hyPfJYJ_XAtDYoslQc-Rgg/SearchTimeline"

  graphListById* = "niz0TtOxL2zIcbq6_NQiNw/ListByRestId"
  graphListBySlug* = "RqkWNDQpOntlxNtJa4RIoQ/ListBySlug"
  graphListMembers* = "8rYmkvWQe9jRRZdy_-vkGA/ListMembers"
  graphListTweets* = "0QJtcuMzVywHGAWD6Dtjlw/ListTimeline"
  graphAboutAccount* = "TzOG2twZEfhr9KmClvVVqA/AboutAccountQuery"

  graphCommunity* = "-ElI1vg3dYbttVMhBhGdLw/CommunityQuery"
  graphCommunityTweets* = "EwftYyqQemkckQ0wzGM6uw/CommunityTweetsTimeline"
  graphCommunityMedia* = "ESJtwnI_apuGesbJncpc0Q/CommunityMediaTimeline"
  graphCommunityMembers* = "woAp_YdzAdqnWDrqLTNpAw/membersSliceTimeline_Query"
  graphCommunityModerators* = "0oYT9GRiWUhrz5xoqFE9uw/moderatorsSliceTimeline_Query"
  graphCommunityHashtags* = "D5EqomOIWeJnSkMhL-FLew/CommunityHashtagsTimeline"

  graphTweetResultByRestId* = "GZsN2Pc4knAoit6pXa4HSA/TweetResultByRestId"
  graphTweetResultsByRestIds* = "Pho4sg8jLcrVlMeclMayrg/TweetResultsByRestIds"

  graphBroadcast* = "RG6wSogandh6WPIzxW9aag/BroadcastQuery"
  graphAudioSpace* = "Bh0L6azTQoMs9rJKeCF4wQ/AudioSpaceById"
  restLiveStream* = "1.1/live_video_stream/status/"

  graphFollowers* = "JNyQdTISpzCkj_1fqxDvFg/Followers"
  graphFollowing* = "qGZZDF3mp91q7X22s3HxpA/Following"

  gqlFeatures* = """{
  "rweb_video_screen_enabled": false,
  "rweb_cashtags_enabled": true,
  "profile_label_improvements_pcf_label_in_post_enabled": true,
  "responsive_web_profile_redirect_enabled": false,
  "rweb_tipjar_consumption_enabled": false,
  "verified_phone_label_enabled": false,
  "creator_subscriptions_tweet_preview_api_enabled": true,
  "responsive_web_graphql_timeline_navigation_enabled": true,
  "responsive_web_graphql_skip_user_profile_image_extensions_enabled": false,
  "premium_content_api_read_enabled": false,
  "communities_web_enable_tweet_community_results_fetch": true,
  "c9s_tweet_anatomy_moderator_badge_enabled": true,
  "c9s_list_members_action_api_enabled": false,
  "c9s_superc9s_indication_enabled": false,
  "responsive_web_grok_analyze_button_fetch_trends_enabled": false,
  "responsive_web_grok_analyze_post_followups_enabled": true,
  "rweb_cashtags_composer_attachment_enabled": true,
  "responsive_web_jetfuel_frame": true,
  "responsive_web_grok_share_attachment_enabled": true,
  "responsive_web_grok_annotations_enabled": true,
  "articles_preview_enabled": true,
  "responsive_web_edit_tweet_api_enabled": true,
  "rweb_conversational_replies_downvote_enabled": false,
  "graphql_is_translatable_rweb_tweet_is_translatable_enabled": true,
  "view_counts_everywhere_api_enabled": true,
  "longform_notetweets_consumption_enabled": true,
  "responsive_web_twitter_article_tweet_consumption_enabled": true,
  "content_disclosure_indicator_enabled": true,
  "content_disclosure_ai_generated_indicator_enabled": true,
  "responsive_web_grok_show_grok_translated_post": true,
  "responsive_web_grok_analysis_button_from_backend": true,
  "post_ctas_fetch_enabled": true,
  "freedom_of_speech_not_reach_fetch_enabled": true,
  "standardized_nudges_misinfo": true,
  "tweet_with_visibility_results_prefer_gql_limited_actions_policy_enabled": true,
  "longform_notetweets_rich_text_read_enabled": true,
  "longform_notetweets_inline_media_enabled": false,
  "responsive_web_grok_image_annotation_enabled": true,
  "responsive_web_grok_imagine_annotation_enabled": true,
  "responsive_web_grok_community_note_auto_translation_is_enabled": true,
  "responsive_web_enhance_cards_enabled": false
}""".replace(" ", "").replace("\n", "")

  tweetVars* = """{
  "postId": "$1",
  $2
  "ranking_mode": "$3",
  "includeHasBirdwatchNotes": false,
  "includePromotedContent": false,
  "withBirdwatchNotes": true,
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

  tweetEditHistoryVars* = """{
  "tweetId": "$1",
  "withQuickPromoteEligibilityTweetFields": true
}""".replace(" ", "").replace("\n", "")

  restIdVars* = """{
  "rest_id": "$1", $2
  "count": $3
}""".replace(" ", "").replace("\n", "")

  userMediaVars* = """{
  "userId": "$1", $2
  "count": $3,
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

  articleVars* = """{
  "tweetId": "$1",
  "includePromotedContent": false,
  "withBirdwatchNotes": true,
  "withVoice": true,
  "withCommunity": true
}""".replace(" ", "").replace("\n", "")

  articleBatchVars* = """{
  "tweetIds": $1,
  "includePromotedContent": false,
  "withBirdwatchNotes": true,
  "withVoice": true,
  "withCommunity": true
}""".replace(" ", "").replace("\n", "")

  articleFieldToggles* = """{"withArticleRichContentState":true,"withArticlePlainText":false,"withArticleSummaryText":true,"withArticleVoiceOver":true}"""

  tweetByRestIdVars* = """{
  "tweetId": "$1",
  "includePromotedContent": false,
  "withBirdwatchNotes": false,
  "withVoice": false,
  "withCommunity": false
}""".replace(" ", "").replace("\n", "")

  userByRestIdVars* = """{
  "userId": "$1",
  "withSafetyModeUserFields": true
}""".replace(" ", "").replace("\n", "")

  communityTweetsVars* = """{
  "communityId": "$1", $2
  "count": 20,
  "displayLocation": "Community",
  "rankingMode": "$3",
  "withCommunity": true
}""".replace(" ", "").replace("\n", "")

  communityMediaVars* = """{
  "communityId": "$1", $2
  "count": 20,
  "withCommunity": true
}""".replace(" ", "").replace("\n", "")

  communityMembersVars* = """{
  "communityId": "$1",
  "cursor": $2
}""".replace(" ", "").replace("\n", "")

  communityHashtagsVars* = """{
  "communityId": "$1", $2
  "count": 20,
  "hashtags": ["$3"],
  "withCommunity": true
}""".replace(" ", "").replace("\n", "")

  userFieldToggles = """{"withPayments":false,"withAuxiliaryUserLabels":true}"""
  userTweetsFieldToggles* = """{"withArticleRichContentState":true,"withArticlePlainText":false}"""
  tweetDetailFieldToggles* = """{"withArticleRichContentState":true,"withArticlePlainText":false,"withGrokAnalyze":false,"withDisallowedReplyControls":false}"""
