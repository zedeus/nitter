import strutils, strformat
import karax/[karaxdsl, vdom, vstyles]

import tweet, timeline, renderutils
import ".."/[types, utils, formatters]

proc renderStat(num, class: string; text=""): VNode =
  let t = if text.len > 0: text else: class
  buildHtml(li(class=class)):
    span(class="profile-stat-header"): text capitalizeAscii(t)
    span(class="profile-stat-num"):
      text if num.len == 0: "?" else: num

proc renderProfileCard*(profile: Profile; prefs: Prefs): VNode =
  buildHtml(tdiv(class="profile-card")):
    tdiv(class="profile-card-info"):
      let url = getPicUrl(profile.getUserPic())
      a(class="profile-card-avatar", href=url, target="_blank"):
        genImg(profile.getUserpic("_200x200"))

      tdiv(class="profile-card-tabs-name"):
        linkUser(profile, class="profile-card-fullname")
        linkUser(profile, class="profile-card-username")

    tdiv(class="profile-card-extra"):
      if profile.bio.len > 0:
        tdiv(class="profile-bio"):
          p: verbatim linkifyText(profile.bio, prefs)

      if profile.location.len > 0:
        tdiv(class="profile-location"):
          span: icon "location", profile.location

      if profile.website.len > 0:
        tdiv(class="profile-website"):
          span:
            icon "link"
            linkText(profile.website)

      tdiv(class="profile-joindate"):
        span(title=getJoinDateFull(profile)):
          icon "calendar", getJoinDate(profile)

      tdiv(class="profile-card-extra-links"):
        ul(class="profile-statlist"):
          renderStat(profile.tweets, "posts", text="Tweets")
          renderStat(profile.followers, "followers")
          renderStat(profile.following, "following")
          renderStat(profile.likes, "likes")

proc renderPhotoRail(profile: Profile; photoRail: seq[GalleryPhoto]): VNode =
  buildHtml(tdiv(class="photo-rail-card")):
    tdiv(class="photo-rail-header"):
      a(href=(&"/{profile.username}/media")):
        icon "picture", $profile.media & " Photos and videos"

    input(id="photo-rail-toggle", `type`="checkbox")
    tdiv(class="photo-rail-header-mobile"):
      label(`for`="photo-rail-toggle", class="photo-rail-label"):
        icon "picture", $profile.media & " Photos and videos"
        icon "down"

    tdiv(class="photo-rail-grid"):
      for i, photo in photoRail:
        if i == 16: break
        a(href=(&"/{profile.username}/status/{photo.tweetId}"),
          style={backgroundColor: photo.color}):
          genImg(photo.url & ":thumb")

proc renderBanner(profile: Profile): VNode =
  buildHtml():
    if "#" in profile.banner:
      tdiv(class="profile-banner-color", style={backgroundColor: profile.banner})
    else:
      a(href=getPicUrl(profile.banner), target="_blank"):
        genImg(profile.banner)

proc renderProfile*(profile: Profile; timeline: Timeline;
                    photoRail: seq[GalleryPhoto]; prefs: Prefs; path: string): VNode =
  buildHtml(tdiv(class="profile-tabs")):
    if not prefs.hideBanner:
      tdiv(class="profile-banner"):
        renderBanner(profile)

    let sticky = if prefs.stickyProfile: "sticky" else: "unset"
    tdiv(class="profile-tab", style={position: sticky}):
      renderProfileCard(profile, prefs)
      if photoRail.len > 0:
        renderPhotoRail(profile, photoRail)

    tdiv(class="timeline-tab"):
      renderTimeline(timeline, profile.username, profile.protected, prefs, path)

proc renderMulti*(timeline: Timeline; usernames: string;
                  prefs: Prefs; path: string): VNode =
  buildHtml(tdiv(class="multi-timeline")):
    tdiv(class="timeline-tab"):
      renderTimeline(timeline, usernames, false, prefs, path, multi=true)
