import sass

compileFile("src/sass/index.scss",
            outputPath = "public/css/style.css",
            includePaths = @["src/sass/include"])

echo "Compiled to public/css/style.css"
