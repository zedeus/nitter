import strutils, strformat
import karax/[karaxdsl, vdom, vstyles]

import ../types, ../utils, ../formatters
import tweet, timeline, renderutils

proc renderStat(stat, text: string): VNode =
  buildHtml(li(class=text)):
    span(class="profile-stat-header"): text capitalizeAscii(text)
    span(class="profile-stat-num"): text stat

proc renderProfileCard*(profile: Profile): VNode =
  buildHtml(tdiv(class="profile-card")):
    a(class="profile-card-avatar", href=profile.getUserPic().getSigUrl("pic")):
      genImg(profile.getUserpic("_200x200"))

    tdiv(class="profile-card-tabs"):
      tdiv(class="profile-card-tabs-name"):
        linkUser(profile, class="profile-card-fullname")
        linkUser(profile, class="profile-card-username")

    tdiv(class="profile-card-extra"):
      if profile.bio.len > 0:
        tdiv(class="profile-bio"):
          p: verbatim linkifyText(profile.bio)

      tdiv(class="profile-card-extra-links"):
        ul(class="profile-statlist"):
          renderStat(profile.tweets, "tweets")
          renderStat(profile.followers, "followers")
          renderStat(profile.following, "following")

proc renderPhotoRail(username: string; photoRail: seq[GalleryPhoto]): VNode =
  buildHtml(tdiv(class="photo-rail-card")):
    tdiv(class="photo-rail-header"):
      a(href=(&"/{username}/media")):
        text "🖼 Photos and videos"

    tdiv(class="photo-rail-grid"):
      for i, photo in photoRail:
        if i == 16: break
        a(href=(&"/{username}/status/{photo.tweetId}"),
          style={backgroundColor: photo.color}):
          genImg(photo.url & ":thumb")

proc renderBanner(profile: Profile): VNode =
  buildHtml():
    if "#" in profile.banner:
      tdiv(class="profile-banner-color", style={backgroundColor: profile.banner})
    else:
      a(href=getSigUrl(profile.banner, "pic")):
        genImg(profile.banner)

proc renderProfile*(profile: Profile; timeline: Timeline;
                    photoRail: seq[GalleryPhoto]): VNode =
  buildHtml(tdiv(class="profile-tabs")):
    tdiv(class="profile-banner"):
      renderBanner(profile)

    tdiv(class="profile-tab"):
      renderProfileCard(profile)
      if photoRail.len > 0:
        renderPhotoRail(profile.username, photoRail)

    tdiv(class="timeline-tab"):
      renderTimeline(timeline, profile)
