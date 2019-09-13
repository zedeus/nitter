import karax/[karaxdsl, vdom]

proc renderAbout*(): VNode =
  buildHtml(tdiv(class="overlay-panel")):
    h1: text "About"
    p:
      text "Nitter is a free and open source alternative Twitter front-end focused on privacy. "
      text "The source is available on GitHub at "
      a(href="https://github.com/zedeus/nitter"): text "https://github.com/zedeus/nitter"

    ul(class="about-list"):
      li: text "No JavaScript or ads"
      li: text "All requests go through the backend, client never talks to Twitter"
      li: text "Prevents Twitter from tracking your IP or JavaScript fingerprint"
      li: text "Uses unofficial API (no developer account required)"
      li: text "AGPLv3 licensed, no proprietary instances permitted"
      li: text "Lightweight (for @nim_lang, 36KB vs 580KB from twitter.com)"

    h2: text "Why use Nitter?"
    p: text "It's basically impossible to use Twitter without JavaScript enabled. If you try, you're redirected to the legacy mobile version which is awful both functionally and aesthetically. For privacy-minded folks, preventing JavaScript analytics and potential IP-based tracking is important, but apart from using the legacy mobile version and a VPN, it's impossible."
    p: text "Using an instance of Nitter (hosted on a VPS for example), you can browse Twitter without JavaScript while retaining your privacy. In addition to respecting your privacy, Nitter is on average around 15 times lighter than Twitter, and in some cases serves pages faster."
    p: text "In the future a simple account system will be added that lets you follow Twitter users, allowing you to have a clean chronological timeline without needing a Twitter account."

    h2: text "Contact"
    p:
      text "Feel free to join our Freenode IRC channel at #nitter, or our "
      a(href="https://riot.im/app/#/room/#nitter:matrix.org"):
        text "Matrix server"
      text "."
