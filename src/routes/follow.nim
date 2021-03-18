import jester
import asyncdispatch, strutils, options, router_utils
import ".."/[prefs, types, utils, redis_cache]

export follow

proc createFollowRouter*(cfg: Config) =
  router follow:
    post "/follow":
      redirect(refPath())
    post "/unfollow":
      redirect(refPath())
