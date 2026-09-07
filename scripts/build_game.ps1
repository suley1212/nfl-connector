# Injects data/game_data.json into game/template.html -> game/index.html
#
#   ./scripts/build_game.ps1
#
# index.html is the file published as the Artifact. It is generated, so it is
# not tracked in git; template.html and game_data.json are the sources.

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

$template = Get-Content "game/template.html" -Raw -Encoding UTF8
$data = Get-Content "data/game_data.json" -Raw -Encoding UTF8

if ($template -notmatch "__GAME_DATA__") { throw "template.html is missing the __GAME_DATA__ placeholder" }
# A literal </script> inside the JSON would close the data block early.
if ($data -match "</script") { throw "game_data.json contains a </script sequence" }

$out = $template.Replace("__GAME_DATA__", $data)
[System.IO.File]::WriteAllText((Join-Path $root "game/index.html"), $out, (New-Object System.Text.UTF8Encoding($false)))

$kb = [math]::Round((Get-Item "game/index.html").Length / 1KB, 1)
Write-Host "Wrote game/index.html ($kb KB)"
