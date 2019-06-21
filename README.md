# Nitter (WIP)

A free and open source alternative Twitter front-end focused on privacy. \
Inspired by the [invidio.us](https://github.com/omarroth/invidious) project.

- No JavaScript or ads
- All requests go through the backend, client never talks to Twitter
- Prevents Twitter from tracking your IP or JavaScript fingerprint
- Unofficial API (no rate limits or developer account required)
- Lightweight (for [@nim_lang](https://twitter.com/nim_lang), 32KB vs 552KB from twitter.com)
- Dark theme

## Installation
```bash
git clone https://github.com/zestyr/nitter
cd nitter
nimble build
```

To run, `./src/nitter`

## Todo
- Simple account system with feed (excludes retweets)
- Hiding retweets from timelines
- Video support with hls.js
- "Cards" (link previews)
- Server config
- File caching
- Themes
- Search
- Json API

## Why?
It's basically impossible to use Twitter without JavaScript enabled. If you try, you're redirected to the legacy mobile version which is awful both functionally and aesthetically. For privacy-minded folks, preventing JavaScript analytics and potential IP-based tracking is important, but apart from using the legacy mobile version and a VPN, it's impossible. Using an instance of Nitter (hosted on a VPS for example), you can essentially browse Twitter without JavaScript, while retaining your privacy. In the future a simple account system will be added that lets you follow Twitter users, allowing you to have a clean chronological timeline without needing a Twitter account.

## Screenshot

![nitter](/screenshot.png)
