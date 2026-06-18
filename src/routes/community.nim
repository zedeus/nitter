# SPDX-License-Identifier: AGPL-3.0-only
import strformat

import jester

import router_utils
import ".."/[types, redis_cache, api]
import ../views/[general, timeline, community]

export community

template respCommunity*(cmty: Community; title: string; nav, vnode: typed) =
  if cmty.id.len == 0 or cmty.name.len == 0:
    resp Http404, showError(&"""Community "{@"id"}" not found""", cfg)

  let html = renderCommunity(vnode, nav, cmty)
  resp renderMain(html, request, cfg, prefs, titleText=title, banner=cmty.banner)

proc createCommunityRouter*(cfg: Config) =
  router community:
    get "/i/communities/@id/?":
      cond '.' notin @"id"
      let
        prefs = requestPrefs()
        cmty = await getCachedCommunity(@"id")
        tl = await getGraphCommunityTweets(cmty.id, "Relevance", getCursor())
      respCommunity(cmty, cmty.name,
                     renderCommunityTabs(QueryKind.posts, cmty),
                     renderTimelineTweets(tl, prefs, request.path))

    get "/i/communities/@id/latest":
      cond '.' notin @"id"
      let
        prefs = requestPrefs()
        cmty = await getCachedCommunity(@"id")
        tl = await getGraphCommunityTweets(cmty.id, "Recency", getCursor())
      respCommunity(cmty, cmty.name & " - Latest",
                     renderCommunityTabs(QueryKind.replies, cmty),
                     renderTimelineTweets(tl, prefs, request.path))

    get "/i/communities/@id/media":
      cond '.' notin @"id"
      let
        prefs = requestPrefs()
        cmty = await getCachedCommunity(@"id")
        tl = await getGraphCommunityMedia(cmty.id, getCursor())
      respCommunity(cmty, cmty.name & " - Media",
                     renderCommunityTabs(QueryKind.media, cmty),
                     renderTimelineTweets(tl, prefs, request.path))

    get "/i/communities/@id/about":
      cond '.' notin @"id"
      let
        prefs = requestPrefs()
        cmty = await getCachedCommunity(@"id")
        mods = await getCachedCommunityModerators(cmty.id)
      respCommunity(cmty, cmty.name & " - About",
                     renderCommunityTabs(QueryKind.userList, cmty),
                     renderCommunityAbout(cmty, mods))

    get "/i/communities/@id/members":
      cond '.' notin @"id"
      let
        prefs = requestPrefs()
        cmty = await getCachedCommunity(@"id")
        members = await getGraphCommunityMembers(cmty.id, getCursor())
      respCommunity(cmty, cmty.name & " - Members",
                     renderMemberTabs(cmty, false),
                     renderTimelineUsers(members, prefs, request.path))

    get "/i/communities/@id/moderators":
      cond '.' notin @"id"
      let
        prefs = requestPrefs()
        cmty = await getCachedCommunity(@"id")
        mods = await getCachedCommunityModerators(cmty.id)
      respCommunity(cmty, cmty.name & " - Moderators",
                     renderMemberTabs(cmty, true),
                     renderTimelineUsers(Result[User](content: mods), prefs, request.path))

    get "/i/communities/@id/hashtag/@tag":
      cond '.' notin @"id"
      let
        prefs = requestPrefs()
        cmty = await getCachedCommunity(@"id")
        tl = await getGraphCommunityHashtags(cmty.id, @"tag", getCursor())
      respCommunity(cmty, cmty.name & " - #" & @"tag",
                     renderHashtagHeader(cmty, @"tag"),
                     renderTimelineTweets(tl, prefs, request.path))
