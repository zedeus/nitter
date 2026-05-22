# SPDX-License-Identifier: AGPL-3.0-only
import strutils, strformat, times
import karax/[karaxdsl, vdom]

import renderutils
import ".."/[types, formatters]

proc renderAboutAccount*(info: AccountInfo): VNode =
  let user = User(
    username: info.username,
    fullname: info.fullname,
    userPic: info.userPic,
    verifiedType: info.verifiedType
  )

  buildHtml(tdiv(class="about-account")):
    tdiv(class="about-account-header"):
      a(class="about-account-avatar", href=(&"/{info.username}")):
        genImg(getUserPic(info.userPic, "_200x200"))
      tdiv(class="about-account-name"):
        linkUser(user, class="profile-card-fullname")
        verifiedIcon(user)
      linkUser(user, class="profile-card-username")

    tdiv(class="about-account-body"):
      tdiv(class="about-account-row"):
        span: icon "calendar"
        tdiv:
          span(class="about-account-label"): text "Date joined"
          span(class="about-account-value"):
            text info.joinDate.format("MMMM YYYY")

      if info.basedIn.len > 0:
        tdiv(class="about-account-row"):
          span: icon "location"
          tdiv:
            span(class="about-account-label"): text "Account based in"
            span(class="about-account-value"): text info.basedIn

      if info.verifiedType != VerifiedType.none:
        if info.overrideVerifiedYear != 0:
          tdiv(class="about-account-row"):
            span: icon "ok"
            tdiv:
              span(class="about-account-label"): text "Verified"
              span(class="about-account-value"):
                let year = abs(info.overrideVerifiedYear)
                let era = if info.overrideVerifiedYear < 0: " BCE" else: ""
                text "Since " & $year & era
        elif info.verifiedSince.year > 0:
          tdiv(class="about-account-row"):
            span: icon "ok"
            tdiv:
              span(class="about-account-label"): text "Verified"
              span(class="about-account-value"):
                text "Since " & info.verifiedSince.format("MMMM YYYY")

        if info.isIdentityVerified:
          tdiv(class="about-account-row"):
            span: icon "ok"
            tdiv:
              span(class="about-account-label"): text "ID Verified"
              span(class="about-account-value"): text "Yes"

      if info.affiliateUsername.len > 0:
        tdiv(class="about-account-row"):
          span: icon "group"
          tdiv:
            span(class="about-account-label"): text "An affiliate of"
            span(class="about-account-value"):
              a(href=(&"/{info.affiliateUsername}")):
                if info.affiliateLabel.len > 0:
                  text info.affiliateLabel & " (@" & info.affiliateUsername & ")"
                else:
                  text "@" & info.affiliateUsername

      if info.usernameChanges > 0:
        tdiv(class="about-account-row"):
          span(class="about-account-at"): text "@"
          tdiv:
            span(class="about-account-label"):
              text $info.usernameChanges & " username change"
              if info.usernameChanges > 1: text "s"
            if info.lastUsernameChange.year > 0:
              span(class="about-account-value"):
                text "Last on " & info.lastUsernameChange.format("MMMM YYYY")

      if info.source.len > 0:
        tdiv(class="about-account-row"):
          span: icon "link"
          tdiv:
            span(class="about-account-label"): text "Connected via"
            span(class="about-account-value"): text info.source
