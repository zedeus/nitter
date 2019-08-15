# Nitter (WIP)

A free and open source alternative Twitter front-end focused on privacy. \
Inspired by the [invidio.us](https://github.com/omarroth/invidious) project.

- No JavaScript or ads
- All requests go through the backend, client never talks to Twitter
- Prevents Twitter from tracking your IP or JavaScript fingerprint
- Unofficial API (no rate limits or developer account required)
- AGPLv3 licensed, no proprietary instances permitted
- Dark theme
- Lightweight (for [@nim_lang](https://twitter.com/nim_lang), 36KB vs 580KB from twitter.com)

## Installation

You need to install nim on your system: https://nim-lang.org/install.html
It is possible to install nim system wide or in the user directory you create below.

```bash
# useradd -m nitter
# su nitter
$ git clone https://github.com/zedeus/nitter
$ cd nitter
$ nimble build -d:release
$ mkdir ./tmp
```

To run nitter, execute `./nitter`. It's currently not possible to change any settings or things
like the title, this will change as the project matures a bit. For now the focus
is on implementing missing features.

You should put nitter behind a reverse proxy with e.g. nginx or apache.

It is also possible to run nitter via systemd:

```bash
[Unit]
Description=Nitter (An alternative Twitter front-end)
After=syslog.target
After=network.target

[Service]
Type=simple

# set user and group
User=nitter
Group=nitter

# configure location
WorkingDirectory=/home/nitter/nitter
ExecStart=/home/nitter/nitter/nitter

Restart=always
RestartSec=15

[Install]
WantedBy=multi-user.target
```

Then enable and start
`systemctl enable --now nitter.service`

## Todo (roughly in this order)

- Search (images/videos, hashtags, etc.)
- Custom timeline filter
- More caching (waiting for [moigagoo/norm#19](https://github.com/moigagoo/norm/pull/19))
- Simple account system with customizable feed
- Video support with hls.js
- Json API endpoints
- Themes
- Nitter logo
- Emoji support (WIP, uses native font for now)

## Why?

It's basically impossible to use Twitter without JavaScript enabled. If you try,
you're redirected to the legacy mobile version which is awful both functionally
and aesthetically. For privacy-minded folks, preventing JavaScript analytics and
potential IP-based tracking is important, but apart from using the legacy mobile
version and a VPN, it's impossible. Using an instance of Nitter (hosted on a VPS
for example), you can essentially browse Twitter without JavaScript, while
retaining your privacy. In addition to respecting your privacy, Nitter is on
average around 15 times lighter than Twitter, and in some cases serves pages
faster. In the future a simple account system will be added that lets you follow
Twitter users, allowing you to have a clean chronological timeline without
needing a Twitter account.

## Screenshot

![nitter](/screenshot.png)

## Contact

Feel free to join our [Matrix Server](https://riot.im/app/#/room/#nitter:matrix.org), or #nitter on Freenode.
