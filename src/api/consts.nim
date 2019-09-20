import uri

const
  lang* = "en-US,en;q=0.9"
  auth* = "Bearer AAAAAAAAAAAAAAAAAAAAAPYXBAAAAAAACLXUNDekMxqa8h%2F40K4moUkGsoc%3DTYfbDKbT3jJPCEVnMYqilB28NHfOPqkca3qaAxGfsyKCs0wRbw"
  htmlAccept* = "text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3"
  jsonAccept* = "application/json, text/javascript, */*; q=0.01"

  base* = parseUri("https://twitter.com/")
  apiBase* = parseUri("https://api.twitter.com/1.1/")

  timelineUrl* = "i/profiles/show/$1/timeline/tweets"
  timelineMediaUrl* = "i/profiles/show/$1/media_timeline"
  listUrl* = "$1/lists/$2/timeline"
  listMembersUrl* = "$1/lists/$2/members"
  profilePopupUrl* = "i/profiles/popup"
  profileIntentUrl* = "intent/user"
  searchUrl* = "i/search/timeline"
  tweetUrl* = "status"
  videoUrl* = "videos/tweet/config/$1.json"
  tokenUrl* = "guest/activate.json"
  cardUrl* = "i/cards/tfw/v1/$1"
  pollUrl* = cardUrl & "?cardname=poll2choice_text_only&lang=en"
