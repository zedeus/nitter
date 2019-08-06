import karax/[karaxdsl, vdom]

const doctype = "<!DOCTYPE html>\n"

proc renderMain*(body: VNode; title="Nitter"; titleText=""): string =
  let node = buildHtml(html(lang="en")):
    head:
      if titleText.len > 0:
        title: text titleText & " | " & title
      else:
        title: text title
      link(rel="stylesheet", `type`="text/css", href="/style.css")

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
