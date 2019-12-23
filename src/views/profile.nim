import strutils, strformat
import karax/[karaxdsl, vdom, vstyles]

import renderutils, search
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
          p(dir="auto"):
            verbatim replaceUrl(profile.bio, prefs)

      if profile.location.len > 0:
        tdiv(class="profile-location"):
          span: icon "location"
          let (place, url) = profile.getLocation()
          if url.len > 1:
            a(href=url): text place
          else:
            span: text place

      if profile.website.len > 0:
        tdiv(class="profile-website"):
          span:
            let url = replaceUrl(profile.website, prefs)
            icon "link"
            a(href=url): text shortLink(url)

      tdiv(class="profile-joindate"):
        span(title=getJoinDateFull(profile)):
          icon "calendar", getJoinDate(profile)

      tdiv(class="profile-card-extra-links"):
        ul(class="profile-statlist"):
          renderStat(profile.tweets, "posts", text="Tweets")
          renderStat(profile.following, "following")
          renderStat(profile.followers, "followers")
          renderStat(profile.likes, "likes")

proc renderPhotoRail(profile: Profile; photoRail: seq[GalleryPhoto]): VNode =
  buildHtml(tdiv(class="photo-rail-card")):
    tdiv(class="photo-rail-header"):
      a(href=(&"/{profile.username}/media")):
        icon "picture", $profile.media & " Photos and videos"

    input(id="photo-rail-grid-toggle", `type`="checkbox")
    label(`for`="photo-rail-grid-toggle", class="photo-rail-header-mobile"):
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

proc renderProtected(username: string): VNode =
  buildHtml(tdiv(class="timeline-container")):
    tdiv(class="timeline-header timeline-protected"):
      h2: text "This account's tweets are protected."
      p: text &"Only confirmed followers have access to @{username}'s tweets."

proc renderProfile*(profile: Profile; timeline: Timeline;
                    photoRail: seq[GalleryPhoto]; prefs: Prefs; path: string): VNode =
  timeline.query.fromUser = @[profile.username]
  buildHtml(tdiv(class="profile-tabs")):
    if not prefs.hideBanner:
      tdiv(class="profile-banner"):
        renderBanner(profile)

    let sticky = if prefs.stickyProfile: "sticky" else: "unset"
    tdiv(class="profile-tab", style={position: sticky}):
      renderProfileCard(profile, prefs)
      if photoRail.len > 0:
        renderPhotoRail(profile, photoRail)

    if profile.protected:
      renderProtected(profile.username)
    else:
      renderTweetSearch(timeline, prefs, path)
