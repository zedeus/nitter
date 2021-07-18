import jester, asyncdispatch, strutils, sequtils
import router_utils
import ../types

export follow

proc addUserToFollowing*(following, toAdd: string): string =
  var updated = following.split(",")
  if updated == @[""]:
    return toAdd
  elif toAdd in updated:
    return following
  else:
    updated = concat(updated, @[toAdd])
    result = updated.join(",")

proc removeUserFromFollowing*(following, remove: string): string =
  var updated = following.split(",")
  if updated == @[""]:
    return ""
  else:
    updated = filter(updated, proc(x: string): bool = x != remove)
    result = updated.join(",")

proc createFollowRouter*(cfg: Config) =
  router follow:
    post "/follow/@name":
      let
        following = cookiePrefs().following
        toAdd = @"name"
        updated = addUserToFollowing(following, toAdd)
      setCookie("following", updated, daysForward(360),
                httpOnly=true, secure=cfg.useHttps, path="/")
      redirect(refPath())
    post "/unfollow/@name":
      let
        following = cookiePrefs().following
        remove = @"name"
        updated = removeUserFromFollowing(following, remove)
      setCookie("following", updated, daysForward(360),
                httpOnly=true, secure=cfg.useHttps, path="/")
      redirect(refPath())
