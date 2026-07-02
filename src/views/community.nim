# SPDX-License-Identifier: AGPL-3.0-only
import strutils, strformat, times
import karax/[karaxdsl, vdom]

import renderutils
import ".."/[types, utils, formatters]

proc renderCommunityTabs*(kind: QueryKind; community: Community): VNode =
  let
    path = &"/i/communities/{community.id}"
    q = Query(kind: kind)
  buildHtml(tdiv):
    ul(class="tab"):
      li(class=q.getTabClass(posts)):
        a(href=path): text "Top"
      li(class=q.getTabClass(replies)):
        a(href=(path & "/latest")): text "Latest"
      li(class=q.getTabClass(media)):
        a(href=(path & "/media")): text "Media"
      li(class=q.getTabClass(userList)):
        a(href=(path & "/about")): text "About"
    if community.hashtags.len > 0:
      tdiv(class="community-tags"):
        for tag in community.hashtags:
          let bare = tag.strip(chars={'#'})
          a(class="community-tag",
            href=(&"/i/communities/{community.id}/hashtag/{bare}")):
            text tag

proc renderMemberTabs*(community: Community; isModerators: bool): VNode =
  let path = &"/i/communities/{community.id}"
  buildHtml(ul(class="tab")):
    li(class=(if not isModerators: "tab-item active" else: "tab-item")):
      a(href=(path & "/members")): text "All"
    li(class=(if isModerators: "tab-item active" else: "tab-item")):
      a(href=(path & "/moderators")): text "Moderators"

proc renderHashtagHeader*(community: Community; tag: string): VNode =
  buildHtml(tdiv(class="community-hashtag-header")):
    h2(class="community-hashtag-title"): text "#" & tag

proc renderCommunityAbout*(community: Community; moderators: seq[User]): VNode =
  buildHtml(tdiv(class="community-about")):
    tdiv(class="community-info"):
      h2: text "Community Info"
      tdiv(class="community-info-item"):
        icon "group"
        if community.joinPolicy == "Open":
          text "Anyone can join this Community."
        else:
          text "Membership is by approval only."

      tdiv(class="community-info-item"):
        icon "info"
        text "All Communities are publicly visible."

      tdiv(class="community-info-item"):
        icon "calendar"
        let
          date = community.createdAt.format("MMMM d, yyyy")
          creator = community.creator.username
        span:
          text &"Created {date} by "
          a(href=(&"/{creator}")): text &"@{creator}"
          if community.creator.verifiedType != none:
            verifiedIcon(community.creator)

    if community.rules.len > 0:
      tdiv(class="community-rules"):
        h2: text "Rules"
        p(class="community-rules-intro"):
          text "These are set and enforced by Community admins and are in addition to "
          a(href="https://help.x.com/rules-and-policies/x-rules"): text "X's rules"
          text "."

        for i, rule in community.rules:
          tdiv(class="community-rule"):
            span(class="community-rule-number"): text $(i + 1)
            tdiv(class="community-rule-content"):
              strong: text rule.name
              if rule.description.len > 0:
                p: text rule.description

    if moderators.len > 0:
      tdiv(class="community-moderators"):
        h2:
          text "Moderators"
          a(class="community-mods-link",
            href=(&"/i/communities/{community.id}/moderators")):
            text "See all"
        for user in moderators:
          tdiv(class="community-moderator"):
            a(href=(&"/{user.username}")):
              genImg(user.getUserPic("_bigger"), class="community-mod-avatar")
            tdiv(class="community-mod-info"):
              a(href=(&"/{user.username}"), class="community-mod-name"):
                text user.fullname
                if user.verifiedType != none:
                  verifiedIcon(user)
              a(href=(&"/{user.username}"), class="community-mod-username"):
                text &"@{user.username}"

proc renderCommunity*(body, nav: VNode; community: Community): VNode =
  buildHtml(tdiv(class="timeline-container")):
    if community.banner.len > 0:
      tdiv(class="timeline-banner"):
        a(href=getPicUrl(community.banner), target="_blank"):
          genImg(community.banner)

    tdiv(class="community-header"):
      h1(class="community-name"):
        a(href=(&"/i/communities/{community.id}")): text community.name

      if community.category.len > 0:
        span(class="community-category"): text community.category

      if community.description.len > 0:
        tdiv(class="community-description"):
          text community.description

      tdiv(class="community-stats"):
        a(class="community-member-count",
          href=(&"/i/communities/{community.id}/members")):
          text insertSep($community.memberCount, ',')
          text " Members"

    nav
    body
