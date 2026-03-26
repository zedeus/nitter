# Timeline API

This repository exposes JSON endpoints for a user's public timeline and for a single tweet.

## Endpoints

### User timeline

- Path: `GET /<username>/api`
- Example: `GET /SOUNDVOLTEX573/api`
- Optional query parameter: `cursor`
- Response type: `application/json; charset=utf-8`

This endpoint returns the same timeline data source used by the HTML timeline, but serialized as JSON.

### Single tweet

- Path: `GET /<username>/status/<tweet_id>/api`
- Example: `GET /SOUNDVOLTEX573/status/2035299206743961670/api`
- Response type: `application/json; charset=utf-8`

This endpoint returns one `Tweet object` using the same schema as each item inside the timeline response.

## User timeline response

```json
{
  "user": {"...": "profile fields"},
  "cursor": "DAAHCgAB...",
  "has_more": true,
  "tweets": [{"...": "tweet objects"}]
}
```

Top-level fields:

- `user`: profile metadata for the requested account
- `cursor`: pagination token for the next request
- `has_more`: whether another page is likely available
- `tweets`: recent tweets in reverse chronological order

When a profile has a pinned tweet, it is included in the `tweets` array as well. If it is not already present in the fetched timeline page, Nitter inserts it at the beginning of the response.

## Single tweet response

The single-tweet endpoint returns one tweet object directly, not a wrapper object.

```json
{
  "id": "2035299206743961670",
  "url": "http://127.0.0.1:1145/SOUNDVOLTEX573/status/2035299206743961670",
  "created_at": "2026-03-21T10:15:19Z",
  "text": "...",
  "user": {"...": "author fields"},
  "stats": {"...": "counts"},
  "media": [{"...": "media objects"}]
}
```

Real example request:

```text
GET /SOUNDVOLTEX573/status/2035299206743961670/api
```

Invalid tweet ids return JSON errors, for example:

```json
{"error":"Invalid tweet ID"}
```

## Pagination

Use the returned `cursor` value in the next request:

```text
GET /SOUNDVOLTEX573/api?cursor=DAAHCgABHEEGji___-oLAAIAAAATMjAzMDg0MjAw...
```

## Tweet object

Each entry in `tweets` is a tweet object. Common fields:

- `id`: tweet id as a string
- `url`: absolute Nitter status URL
- `created_at`: UTC timestamp in ISO-like format, for example `2026-03-23T12:34:56Z`
- `text`: plain tweet text after parsing
- `html`: text with links expanded into HTML anchors
- `available`: whether the tweet body is available
- `tombstone`: unavailable-tweet message when present
- `location`: location string if present
- `reply_to`: array of usernames being replied to
- `pinned`: whether the tweet is pinned
- `has_thread`: whether the tweet has a thread continuation
- `note`: community note text if present
- `is_ad`: ad marker
- `is_ai`: AI marker
- `user`: author object
- `stats`: engagement counts
- `media`: media array
- `history`: edit history tweet ids if available
- `poll`: optional poll object
- `card`: optional card object
- `quote`: optional nested quoted tweet object
- `retweet`: optional nested retweeted tweet object

## User object

`user` appears both at the top level and inside each tweet.

Common fields:

- `id`
- `username`
- `fullname`
- `bio`
- `location`
- `website`
- `avatar`
- `banner`
- `followers`
- `following`
- `tweets`
- `likes`
- `media`
- `verified_type`
- `protected`
- `suspended`
- `join_date`

## Stats object

```json
{
  "replies": 0,
  "retweets": 0,
  "likes": 0,
  "views": 0
}
```

## Media object

`media` is an array. Its shape depends on the media type.

Important: media link fields are not normalized to a single URL format. Depending on media type and upstream data, a field may be:

- a relative Twitter path fragment such as `media/...`
- a host-prefixed value without scheme such as `pbs.twimg.com/...` or `video.twimg.com/...`
- a full `https://...` URL

Clients should not assume every media link is already a complete URL.

### Photo

Real example from `GET /SOUNDVOLTEX573/api`:

```json
{
  "type": "photo",
  "url": "media/HD7V1wka4AEyu_W.jpg",
  "proxy_url": "/pic/media%2FHD7V1wka4AEyu_W.jpg",
  "alt_text": ""
}
```

Notes:

- `url` is usually a Twitter image path fragment, not a full URL
- To construct the original Twitter image URL, prepend `https://pbs.twimg.com/`
- `proxy_url` is the Nitter media proxy route and is the recommended fetch target for clients that want the same media behavior as the web UI

Example:

- `url`: `media/HD7V1wka4AEyu_W.jpg`
- Original image URL: `https://pbs.twimg.com/media/HD7V1wka4AEyu_W.jpg`
- Nitter proxy URL: `/pic/media%2FHD7V1wka4AEyu_W.jpg`

### Video / animated media

Real example from `GET /SOUNDVOLTEX573/api`:

```json
{
  "type": "application/x-mpegURL",
  "url": "",
  "proxy_url": "",
  "thumbnail": "media/HANAyW5bsAEeTnn.jpg",
  "duration_ms": 53000,
  "available": true,
  "reason": "",
  "title": "",
  "description": "",
  "variants": [
    {
      "content_type": "video/mp4",
      "url": "https://video.twimg.com/amplify_video/.../320x320/...mp4?tag=14",
      "bitrate": 432000,
      "resolution": 320
    },
    {
      "content_type": "application/x-mpegURL",
      "url": "https://video.twimg.com/amplify_video/.../pl/...m3u8?tag=14&v=7cf",
      "bitrate": 0,
      "resolution": 0
    }
  ]
}
```

Notes:

- `type` is the main playback type reported by Nitter
- `thumbnail` is usually a Twitter image path fragment and can be turned into `https://pbs.twimg.com/<thumbnail>`
- `variants` contains the actual playable URLs
- For video-like media, prefer the `variants` array over the top-level `url`
- MP4 variant URLs are full `https://video.twimg.com/...` URLs
- HLS variants use `content_type = application/x-mpegURL`
- The top-level `url` field is not guaranteed to be populated for videos; it may be empty
- As a result, the top-level `proxy_url` for videos may also be empty

### GIF

Animated GIF entries are exposed as `type = "gif"` and typically look like this structurally:

```json
{
  "type": "gif",
  "url": "video.twimg.com/tweet_video/...mp4",
  "proxy_url": "/video/<signature>/video.twimg.com%2Ftweet_video%2F...mp4",
  "thumbnail": "media/...jpg",
  "alt_text": ""
}
```

Notes:

- `url` is commonly a host-prefixed value without scheme, such as `video.twimg.com/...`
- To construct the original direct URL, prepend `https://` when the value starts with `video.twimg.com/`
- `thumbnail` follows the same rules as photo thumbnails and is often a `media/...` fragment

### Media URL normalization rules

Recommended client-side normalization:

- If a media field starts with `http://` or `https://`, use it directly
- If it starts with `pbs.twimg.com/`, `abs.twimg.com/`, or `video.twimg.com/`, prepend `https://`
- Otherwise, for image-like fields such as photo `url`, `thumbnail`, or card `image`, treat it as a Twitter path fragment and prepend `https://pbs.twimg.com/`
- For video playback, prefer `variants[].url` over top-level `url`

## Card object

Tweets that link to external pages may include a `card` object.

Real examples from `GET /SOUNDVOLTEX573/api`:

```json
{
  "kind": "summary_large_image",
  "url": "https://p.eagate.573.jp/game/eacsdvx/vi/index.html",
  "title": "「コナステ版 SOUND VOLTEX EXCEED GEAR」公式サイト",
  "destination": "p.eagate.573.jp",
  "text": "KONAMIのBEMANIシリーズ「SOUND VOLTEX EXCEED GEAR」のコナステ版公式サイトです。",
  "image": "card_img/2033187085960577024/Q_VjFFyE?format=jpg&name=800x419"
}
```

```json
{
  "kind": "summary",
  "url": "https://p.eagate.573.jp/game/sdvx/",
  "title": "SOUND VOLTEX ∇",
  "destination": "p.eagate.573.jp",
  "text": "KONAMIのBEMANIシリーズ「SOUND VOLTEX ∇」の公式サイトです。",
  "image": "card_img/2035203185200308226/-E9tk0W6?format=jpg&name=420x420_2"
}
```

Notes:

- `kind` is the Twitter card type, for example `summary` or `summary_large_image`
- `url` is the external target URL
- `destination` is the host/domain label shown in the card
- `image` is not normalized to one fixed format

In real responses, `card.image` may be:

- a path fragment such as `card_img/...` or `media/...`
- a host-prefixed value such as `pbs.twimg.com/media/HEAEEKPbgAATKZa.jpg`
- in some cases, a full `https://...` URL

For card images:

- If `image` already starts with `http://` or `https://`, use it directly
- If `image` starts with `pbs.twimg.com/`, prepend `https://`
- Otherwise, construct the original image URL as `https://pbs.twimg.com/<image>`
- The Nitter proxy form is `/pic/` plus the URL-encoded raw `image` value exactly as returned by the API

Example:

- `image`: `card_img/2033187085960577024/Q_VjFFyE?format=jpg&name=800x419`
- Original image URL: `https://pbs.twimg.com/card_img/2033187085960577024/Q_VjFFyE?format=jpg&name=800x419`
- Nitter proxy URL: `/pic/card_img%2F2033187085960577024%2FQ_VjFFyE%3Fformat%3Djpg%26name%3D800x419`

Another real example:

- `image`: `pbs.twimg.com/media/HEAEEKPbgAATKZa.jpg`
- Original image URL: `https://pbs.twimg.com/media/HEAEEKPbgAATKZa.jpg`
- Nitter proxy URL: `/pic/pbs.twimg.com%2Fmedia%2FHEAEEKPbgAATKZa.jpg`

Some card types may also include a nested `video` object with the same structure as video media.

## Error responses

Not found and similar failures return JSON:

```json
{
  "error": "User not found"
}
```

Typical cases:

- `404`: user not found or suspended

## Client recommendations

- Use `proxy_url` when present if you want your client to follow Nitter's media proxy behavior
- Treat `url`, `thumbnail`, and `card.image` as possibly relative fragments, host-prefixed values, or full URLs
- For video playback, inspect `variants` and choose the best supported `content_type`
- Do not assume top-level video `url` or `proxy_url` is populated
- Do not assume `quote`, `retweet`, `poll`, `card`, or `media` are always present
- Preserve `cursor` exactly as returned when paginating
