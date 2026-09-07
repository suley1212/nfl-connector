# Minimal static server for local preview of game/index.html.
#
#   ./scripts/serve.ps1     ->  http://localhost:8731/
#
# Dev convenience only; the published game is the Artifact.

$port = 8731
$root = Split-Path -Parent $PSScriptRoot

$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add("http://localhost:$port/")
try {
    $listener.Start()
} catch {
    Write-Host "Could not bind http://localhost:$port/ : $($_.Exception.Message)"
    exit 1
}
Write-Host "Serving $root on http://localhost:$port/"

while ($listener.IsListening) {
    $ctx = $listener.GetContext()
    $rel = $ctx.Request.Url.AbsolutePath
    if ($rel -eq "/") { $rel = "/game/index.html" }
    $file = Join-Path $root ($rel.TrimStart("/").Replace("/", "\"))
    try {
        if (Test-Path $file -PathType Leaf) {
            $bytes = [System.IO.File]::ReadAllBytes($file)
            $ext = [System.IO.Path]::GetExtension($file).ToLower()
            $type = "text/plain; charset=utf-8"
            if ($ext -eq ".html") { $type = "text/html; charset=utf-8" }
            elseif ($ext -eq ".json") { $type = "application/json; charset=utf-8" }
            $ctx.Response.ContentType = $type
            $ctx.Response.ContentLength64 = $bytes.Length
            $ctx.Response.OutputStream.Write($bytes, 0, $bytes.Length)
        } else {
            $ctx.Response.StatusCode = 404
        }
    } catch {
        $ctx.Response.StatusCode = 500
    }
    $ctx.Response.Close()
}
