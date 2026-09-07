# Injects data/game_data.json into game/template.html and writes two outputs:
#
#   game/index.html   the Artifact source (gitignored; the Artifact runtime
#                     supplies its own doctype/head wrapper)
#   docs/index.html   a complete standalone document for GitHub Pages, which
#                     wraps nothing for you -- without the viewport meta the
#                     game renders zoomed out on phones
#
#   ./scripts/build_game.ps1

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

$template = Get-Content "game/template.html" -Raw -Encoding UTF8
$data = Get-Content "data/game_data.json" -Raw -Encoding UTF8

if ($template -notmatch "__GAME_DATA__") { throw "template.html is missing the __GAME_DATA__ placeholder" }
# A literal </script> inside the JSON would close the data block early.
if ($data -match "</script") { throw "game_data.json contains a </script sequence" }

$body = $template.Replace("__GAME_DATA__", $data)
$utf8 = New-Object System.Text.UTF8Encoding($false)

# --- artifact build ---------------------------------------------------------
[System.IO.File]::WriteAllText((Join-Path $root "game/index.html"), $body, $utf8)

# --- standalone build -------------------------------------------------------
# Pull <title> out of the body: a <title> element inside <body> is invalid and
# browsers will not reliably use it for the tab.
$title = "Move The Chains"
if ($body -match "(?s)<title>(.*?)</title>") {
    $title = $Matches[1]
    $body = $body -replace "(?s)<title>.*?</title>\s*", ""
}

$desc = "A daily NFL puzzle. Link two players through the teammates they shared a roster with, in four downs."
$icon = "data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 100 100'%3E%3Ctext y='.9em' font-size='90'%3E%F0%9F%8F%88%3C/text%3E%3C/svg%3E"

$head = @"
<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>$title</title>
<meta name="description" content="$desc">
<meta name="theme-color" content="#0A0F0D">
<meta name="color-scheme" content="dark">
<link rel="icon" href="$icon">
<meta property="og:type" content="website">
<meta property="og:title" content="$title">
<meta property="og:description" content="$desc">
<meta name="twitter:card" content="summary">
<meta name="twitter:title" content="$title">
<meta name="twitter:description" content="$desc">
<style>
  html { background: #0A0F0D; }
  body { margin: 0; }
  img { max-width: 100%; }
  [hidden] { display: none !important; }
</style>
</head>
<body>
"@

$standalone = $head + $body + "`n</body>`n</html>`n"

if (-not (Test-Path "docs")) { New-Item -ItemType Directory -Path "docs" | Out-Null }
[System.IO.File]::WriteAllText((Join-Path $root "docs/index.html"), $standalone, $utf8)
# Skip Jekyll: it is not needed and would ignore files beginning with an underscore.
[System.IO.File]::WriteAllText((Join-Path $root "docs/.nojekyll"), "", $utf8)

"{0,-18} {1,8:N1} KB" -f "game/index.html", ((Get-Item "game/index.html").Length / 1KB)
"{0,-18} {1,8:N1} KB" -f "docs/index.html", ((Get-Item "docs/index.html").Length / 1KB)
