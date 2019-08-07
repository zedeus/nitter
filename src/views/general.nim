import karax/[karaxdsl, vdom]

import ../utils

const doctype = "<!DOCTYPE html>\n"

proc renderMain*(body: VNode; title="Nitter"; titleText=""; desc="";
                 `type`="article"; video=""; images: seq[string] = @[]): string =
  let node = buildHtml(html(lang="en")):
    head:
      link(rel="stylesheet", `type`="text/css", href="/style.css")

      title:
        if titleText.len > 0:
          text titleText & " | " & title
        else:
          text title

      meta(property="og:type", content=`type`)
      meta(property="og:title", content=titleText)
      meta(property="og:url", content="https://t.co/VOkeVRgJgc")
      meta(property="og:description", content=desc)
      meta(property="og:site_name", content="Twitter")

      for url in images:
        meta(property="og:image", content=getSigUrl(url, "pic"))

      if video.len > 0:
        meta(property="og:video:url", content=video)
        meta(property="og:video:secure_url", content=video)

    body:
      nav(id="nav", class="nav-bar container"):
        tdiv(class="inner-nav"):
          tdiv(class="item"):
            a(href="/", class="site-name"): text title

      tdiv(id="content", class="container"):
        body

  result = doctype & $node

proc renderSearch*(): VNode =
  buildHtml(tdiv(class="panel")):
    tdiv(class="search-panel"):
      form(`method`="post", action="search"):
        input(`type`="text", name="query", placeholder="Enter usernames...")
        button(`type`="submit"): text "🔎"

proc renderError*(error: string): VNode =
  buildHtml(tdiv(class="panel")):
    tdiv(class="error-panel"):
      span: text error

proc showError*(error: string; title: string): string =
  renderMain(renderError(error), title=title, titleText="Error")
