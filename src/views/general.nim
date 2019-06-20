#? stdtmpl(subsChar = '$', metaChar = '#')
#import user
#import xmltree
#
#proc renderMain*(body: string): string =
<!DOCTYPE html>
<html>
  <head>
    <title>Nitter</title>
    <link rel="stylesheet" type="text/css" href="/style.css">
  </head>

  <body>
    <nav id="nav" class="nav-bar container">
      <div class="inner-nav">
        <div class="item">
          <a href="/" class="site-name">twatter</a>
        </div>
      </div>
    </nav>

    <div id="content" class="container">
      ${body}
    </div>
  </body>
</html>
#end proc
#
#proc renderSearchPanel*(): string =
<div class="panel">
  <div class="search-panel">
    <form action="search" method="post">
      <input type="text" name="query" placeholder="Enter username...">
      <button type="submit" name="button">🔎</button>
    </form>
  </div>
</div>
#end proc
#
#proc renderError*(error: string): string =
<div class="panel">
  <div class="error-panel">
    <span>${error}</span>
  </div>
</div>
#end proc
#
#proc showError*(error: string): string =
${renderMain(renderError(error))}
#end proc
