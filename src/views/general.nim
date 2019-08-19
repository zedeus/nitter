import karax/[karaxdsl, vdom]

import renderutils
import ../utils, ../types

const doctype = "<!DOCTYPE html>\n"

proc renderNavbar*(title: string): VNode =
  buildHtml(nav(id="nav", class="nav-bar container")):
    tdiv(class="inner-nav"):
      tdiv(class="item"):
        a(class="site-name", href="/"): text title

      a(href="/"): img(class="site-logo", src="/logo.png")

      tdiv(class="item right"):
        icon "info-circled", title="About", href="/about"
        icon "cog", title="Preferences", href="/settings"

proc renderMain*(body: VNode; prefs: Prefs; title="Nitter"; titleText=""; desc="";
                 `type`="article"; video=""; images: seq[string] = @[]): string =
  let node = buildHtml(html(lang="en")):
    head:
      link(rel="stylesheet", `type`="text/css", href="/css/style.css")
      link(rel="stylesheet", `type`="text/css", href="/css/fontello.css")

      if prefs.hlsPlayback:
        script(src="/js/hls.light.min.js")
        script(src="/js/hlsPlayback.js")

      title:
        if titleText.len > 0:
          text titleText & " | " & title
        else:
          text title

      meta(property="og:type", content=`type`)
      meta(property="og:title", content=titleText)
      meta(property="og:description", content=desc)
      meta(property="og:site_name", content="Twitter")

      for url in images:
        meta(property="og:image", content=getSigUrl(url, "pic"))

      if video.len > 0:
        meta(property="og:video:url", content=video)
        meta(property="og:video:secure_url", content=video)

    body:
      renderNavbar(title)

      tdiv(id="content", class="container"):
        body

  result = doctype & $node

proc renderSearch*(): VNode =
  buildHtml(tdiv(class="panel")):
    tdiv(class="search-panel"):
      form(`method`="post", action="search"):
        input(`type`="text", name="query", autofocus="", placeholder="Enter usernames...")
        button(`type`="submit"): icon "search"

proc renderError*(error: string): VNode =
  buildHtml(tdiv(class="panel")):
    tdiv(class="error-panel"):
      span: text error

proc showError*(error, title: string): string =
  renderMain(renderError(error), Prefs(), title, "Error")
