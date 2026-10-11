# Static file server for local preview: powershell -ExecutionPolicy Bypass -File serve.ps1
param([int]$Port = 8765)

$root = $PSScriptRoot
$types = @{
  '.html' = 'text/html; charset=utf-8'
  '.js' = 'text/javascript; charset=utf-8'
  '.webmanifest' = 'application/manifest+json'
  '.png' = 'image/png'
}

$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add("http://localhost:$Port/")
$listener.Start()
"Serving $root at http://localhost:$Port/"

try {
  while ($listener.IsListening) {
    $ctx = $listener.GetContext()
    # One bad request (client hung up, HEAD probe) must not take the server down
    try {
      $rel = [Uri]::UnescapeDataString($ctx.Request.Url.AbsolutePath).TrimStart('/')
      if ($rel -eq '') { $rel = 'index.html' }
      $path = [IO.Path]::GetFullPath((Join-Path $root $rel))
      if ($path.StartsWith($root + [IO.Path]::DirectorySeparatorChar) -and (Test-Path -LiteralPath $path -PathType Leaf)) {
        $bytes = [IO.File]::ReadAllBytes($path)
        $type = $types[[IO.Path]::GetExtension($path)]
        if (-not $type) { $type = 'application/octet-stream' }
        $ctx.Response.ContentType = $type
        $ctx.Response.Headers['Cache-Control'] = 'no-cache'
        $ctx.Response.ContentLength64 = $bytes.Length
        if ($ctx.Request.HttpMethod -ne 'HEAD') { $ctx.Response.OutputStream.Write($bytes, 0, $bytes.Length) }
      } else {
        $ctx.Response.StatusCode = 404
      }
      $ctx.Response.Close()
    } catch {
      try { $ctx.Response.Abort() } catch {}
    }
  }
} finally {
  $listener.Stop()
}
