# SPDX-License-Identifier: AGPL-3.0-only
import strutils, strformat, times
import karax/[karaxdsl, vdom]

import renderutils
import ".."/[types, utils, formatters]

proc renderBroadcast*(bc: Broadcast; prefs: Prefs; path: string): VNode =
  let
    isLive = bc.state == "RUNNING"
    thumb = getPicUrl(bc.thumb)
    source = if prefs.proxyVideos and bc.m3u8Url.startsWith("http"):
               getVidUrl(bc.m3u8Url) else: bc.m3u8Url
    stateText =
      if isLive: "LIVE"
      elif bc.endTime.year > 1: "Ended " & bc.endTime.format("MMM d, YYYY")
      elif bc.state.len > 0: bc.state
      else: "Ended"
    durationMs =
      if bc.startTime.year > 1 and bc.endTime.year > 1:
        int((bc.endTime - bc.startTime).inMilliseconds) - bc.replayStart * 1000
      else: 0
    duration = if durationMs > 0: getDuration(durationMs) else: ""

  buildHtml(tdiv(class="broadcast-page")):
    tdiv(class="broadcast-panel"):
      tdiv(class="broadcast-player"):
        if bc.m3u8Url.len > 0 and prefs.hlsPlayback:
          video(poster=thumb, data-url=source, data-autoload="false",
                data-start=($bc.replayStart), muted=prefs.muteVideos)
          verbatim "<div class=\"video-overlay\" onclick=\"playVideo(this)\">"
          tdiv(class="overlay-circle"): span(class="overlay-triangle")
          if isLive:
            tdiv(class="broadcast-live"): text "LIVE"
          elif duration.len > 0:
            tdiv(class="overlay-duration"): text duration
          verbatim "</div>"
        elif bc.m3u8Url.len > 0:
          img(src=thumb, alt=bc.title)
          tdiv(class="video-overlay"):
            buttonReferer "/enablehls", "Enable hls playback", path
            if isLive:
              tdiv(class="broadcast-live"): text "LIVE"
            elif duration.len > 0:
              tdiv(class="overlay-duration"): text duration
        elif bc.thumb.len > 0:
          img(src=thumb, alt=bc.title)
          tdiv(class="video-overlay"):
            if bc.availableForReplay:
              p: text "Stream unavailable"
            else:
              p: text "Replay is not available"
        else:
          tdiv(class="video-overlay"):
            p: text "Broadcast not found"

      tdiv(class="broadcast-info"):
        h2(class="broadcast-title"): text bc.title

        tdiv(class="broadcast-user-row"):
          a(class="broadcast-user", href=("/" & bc.user.username)):
            genImg(getUserPic(bc.user.userPic, "_bigger"))
            tdiv:
              tdiv:
                strong: text bc.user.fullname
                verifiedIcon(bc.user)
              span(class="broadcast-username"): text "@" & bc.user.username

          tdiv(class="broadcast-meta"):
            if bc.totalWatched > 0: 
              span: text insertSep($bc.totalWatched, ',') & " views"
            if isLive:
              span(class="broadcast-live"): text stateText
            else:
              span: text stateText
