import std/strutils
import jsony
import ../types/guestaccount
from ../../types import GuestAccount

proc toGuestAccount(account: RawAccount): GuestAccount =
  let id = account.oauthToken[0 ..< account.oauthToken.find('-')]
  result = GuestAccount(
    id: parseBiggestInt(id),
    oauthToken: account.oauthToken,
    oauthSecret: account.oauthTokenSecret
  )

proc parseGuestAccount*(raw: string): GuestAccount =
  let rawAccount = raw.fromJson(RawAccount)
  result = rawAccount.toGuestAccount

proc parseGuestAccounts*(path: string): seq[GuestAccount] =
  let rawAccounts = readFile(path).fromJson(seq[RawAccount])
  for account in rawAccounts:
    result.add account.toGuestAccount
