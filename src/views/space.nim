# SPDX-License-Identifier: AGPL-3.0-only
import strutils, times
import karax/[karaxdsl, vdom]

import renderutils
import ".."/[types, utils, formatters]

proc renderParticipant(p: SpaceParticipant; role: string): VNode =
  buildHtml(tdiv(class="space-participant")):
    a(href=("/" & p.username)):
      genImg(p.avatarUrl.replace("_normal", "_bigger"))
      tdiv(class="participant-info"):
        tdiv(class="participant-name"):
          strong: text p.displayName
          if p.isVerified:
            tdiv(class="verified-icon blue"):
              icon "circle", class="verified-icon-circle", title="Verified account"
              icon "ok", class="verified-icon-check", title="Verified account"
          if role.len > 0:
            span(class="host-badge"): text role
        span(class="participant-username"): text "@" & p.username

proc renderSpace*(sp: AudioSpace; prefs: Prefs; path: string): VNode =
  let
    isLive = sp.state == "RUNNING"
    source = if prefs.proxyVideos and sp.m3u8Url.startsWith("http"):
               getVidUrl(sp.m3u8Url) else: sp.m3u8Url
    stateText =
      if isLive: "LIVE"
      elif sp.endTime.year > 1: "Ended " & sp.endTime.format("MMM d, YYYY")
      elif sp.state.len > 0: sp.state
      else: "Ended"
    durationMs =
      if sp.startTime.year > 1 and sp.endTime.year > 1:
        int((sp.endTime - sp.startTime).inMilliseconds)
      else: 0
    duration = if durationMs > 0: getDuration(durationMs) else: ""
    totalListeners =
      if sp.totalReplayWatched > 0: sp.totalReplayWatched
      else: sp.totalLiveListeners

  buildHtml(tdiv(class="space-page")):
    tdiv(class="space-panel"):
      tdiv(class="space-player"):
        if sp.m3u8Url.len > 0 and prefs.hlsPlayback:
          audio(data-url=source, data-autoload="false")
          verbatim "<div class=\"video-overlay\" onclick=\"playAudio(this)\">"
          tdiv(class="overlay-circle"): span(class="overlay-triangle")
          if isLive:
            tdiv(class="space-live"): text "LIVE"
          elif duration.len > 0:
            tdiv(class="overlay-duration"): text duration
          verbatim "</div>"
        elif sp.m3u8Url.len > 0:
          tdiv(class="video-overlay"):
            buttonReferer "/enablehls", "Enable hls playback", path
            if isLive:
              tdiv(class="space-live"): text "LIVE"
            elif duration.len > 0:
              tdiv(class="overlay-duration"): text duration
        elif sp.availableForReplay:
          tdiv(class="video-overlay"):
            p: text "Audio stream unavailable"
        else:
          tdiv(class="video-overlay"):
            p: text "Replay is not available"

      tdiv(class="space-info"):
        tdiv(class="space-header"):
          h2(class="space-title"): text sp.title
          tdiv(class="space-meta"):
            if totalListeners > 0:
              span(class="listener-count"): text insertSep($totalListeners, ',') & " listeners"
            if isLive:
              span(class="space-live"): text stateText
            else:
              span(class="space-state"): text stateText

        if sp.admins.len > 0 or sp.speakers.len > 0:
          tdiv(class="space-participants"):
            for admin in sp.admins:
              let role = if admin.username == sp.creator.username: "Host"
                         else: "Co-host"
              renderParticipant(admin, role)
            for speaker in sp.speakers:
              renderParticipant(speaker, "")
