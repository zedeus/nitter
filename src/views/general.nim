import karax/[karaxdsl, vdom]

import renderutils
import ../utils, ../types

const doctype = "<!DOCTYPE html>\n"

proc renderNavbar*(title, path, rss: string): VNode =
  buildHtml(nav):
    tdiv(class="inner-nav"):
      tdiv(class="nav-item"):
        a(class="site-name", href="/"): text title

      a(href="/"): img(class="site-logo", src="/logo.png")

      tdiv(class="nav-item right"):
        icon "search", title="Search", href="/search"
        if rss.len > 0:
          icon "rss", title="RSS Feed", href=rss
        icon "info-circled", title="About", href="/about"
        iconReferer "cog", "/settings", path, title="Preferences"

proc renderMain*(body: VNode; prefs: Prefs; title="Nitter"; titleText=""; desc=""; path="/";
                 rss=""; `type`="article"; video=""; images: seq[string] = @[]): string =
  let node = buildHtml(html(lang="en")):
    head:
      link(rel="stylesheet", `type`="text/css", href="/css/style.css")
      link(rel="stylesheet", `type`="text/css", href="/css/fontello.css")

      if rss.len > 0:
        link(rel="alternate", `type`="application/rss+xml", href=rss, title="RSS feed")

      if prefs.hlsPlayback:
        script(src="/js/hls.light.min.js")
        script(src="/js/hlsPlayback.js")

      title:
        if titleText.len > 0:
          text titleText & " | " & title
        else:
          text title

      meta(name="viewport", content="width=device-width, initial-scale=1.0")
      meta(property="og:type", content=`type`)
      meta(property="og:title", content=titleText)
      meta(property="og:description", content=desc)
      meta(property="og:site_name", content="Nitter")

      for url in images:
        meta(property="og:image", content=getPicUrl(url))

      if video.len > 0:
        meta(property="og:video:url", content=video)
        meta(property="og:video:secure_url", content=video)

    body:
      renderNavbar(title, path, rss)

      tdiv(class="container"):
        body

  result = doctype & $node

proc renderError*(error: string): VNode =
  buildHtml(tdiv(class="panel-container")):
    tdiv(class="error-panel"):
      span: text error

proc showError*(error, title: string): string =
  renderMain(renderError(error), Prefs(), title, "Error")
