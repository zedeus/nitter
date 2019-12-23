import uri, strutils, strformat
import karax/[karaxdsl, vdom]

import renderutils
import ../utils, ../types, ../prefs, ../formatters

import jester

const doctype = "<!DOCTYPE html>\n"

proc renderNavbar*(title, rss: string; req: Request): VNode =
  let twitterPath = getTwitterLink(req.path, req.params)
  var path = $(parseUri(req.path) ? filterParams(req.params))
  if "/status" in path: path.add "#m"

  buildHtml(nav):
    tdiv(class="inner-nav"):
      tdiv(class="nav-item"):
        a(class="site-name", href="/"): text title

      a(href="/"): img(class="site-logo", src="/logo.png")

      tdiv(class="nav-item right"):
        icon "search", title="Search", href="/search"
        if rss.len > 0:
          icon "rss-feed", title="RSS Feed", href=rss
        icon "bird", title="Open in Twitter", href=twitterPath
        icon "info-circled", title="About", href="/about"
        iconReferer "cog", "/settings", path, title="Preferences"

proc renderHead*(prefs: Prefs; cfg: Config; titleText=""; desc=""; video="";
                 images: seq[string] = @[]): VNode =
  let ogType =
    if video.len > 0: "video"
    elif images.len > 0: "photo"
    else: "article"

  buildHtml(head):
    link(rel="stylesheet", `type`="text/css", href="/css/style.css")
    link(rel="stylesheet", `type`="text/css", href="/css/fontello.css")
    link(rel="apple-touch-icon", sizes="180x180", href="/apple-touch-icon.png")
    link(rel="icon", type="image/png", sizes="32x32", href="/favicon-32x32.png")
    link(rel="icon", type="image/png", sizes="16x16", href="/favicon-16x16.png")
    link(rel="manifest", href="/site.webmanifest")
    link(rel="mask-icon", href="/safari-pinned-tab.svg", color="#ff6c60")

    if prefs.hlsPlayback:
      script(src="/js/hls.light.min.js")
      script(src="/js/hlsPlayback.js")

    title:
      if titleText.len > 0:
        text titleText & " | " & cfg.title
      else:
        text cfg.title

    meta(name="viewport", content="width=device-width, initial-scale=1.0")
    meta(property="og:type", content=ogType)
    meta(property="og:title", content=titleText)
    meta(property="og:description", content=stripHtml(desc))
    meta(property="og:site_name", content="Nitter")

    for url in images:
      meta(property="og:image", content=getPicUrl(url))

    if video.len > 0:
      meta(property="og:video:url", content=video)
      meta(property="og:video:secure_url", content=video)
      meta(property="og:video:type", content="text/html")

proc renderMain*(body: VNode; req: Request; cfg: Config; titleText=""; desc="";
                 rss=""; video=""; images: seq[string] = @[]): string =
  let prefs = getPrefs(req.cookies.getOrDefault("preferences"), cfg)
  let theme = toLowerAscii(prefs.theme).replace(" ", "_")

  let node = buildHtml(html(lang="en")):
    renderHead(prefs, cfg, titleText, desc, video, images):
      if theme.len > 0:
        link(rel="stylesheet", `type`="text/css", href=(&"/css/themes/{theme}.css"))

      if rss.len > 0:
        link(rel="alternate", `type`="application/rss+xml", href=rss, title="RSS feed")

    body:
      renderNavbar(cfg.title, rss, req)

      tdiv(class="container"):
        body

  result = doctype & $node

proc renderError*(error: string): VNode =
  buildHtml(tdiv(class="panel-container")):
    tdiv(class="error-panel"):
      span: text error

template showError*(error: string; cfg: Config): string =
  renderMain(renderError(error), request, cfg, "Error")
