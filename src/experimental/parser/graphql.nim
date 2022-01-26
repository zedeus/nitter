import jsony
import ../types/graphql, user
from ../../types import User

proc parseGraphUser*(json: string): User =
  let raw = json.fromJson(GraphUser)
  result = toUser raw.data.user.result.legacy
  result.id = raw.data.user.result.restId
