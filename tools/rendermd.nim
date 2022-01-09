import std/[os, strutils]
import markdown

for file in walkFiles("public/md/*.md"):
  let
    html = markdown(readFile(file))
    output = file.replace(".md", ".html")

  output.writeFile(html)
  echo "Rendered ", output
