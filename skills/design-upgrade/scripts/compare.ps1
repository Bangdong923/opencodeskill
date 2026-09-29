<#
  compare.ps1 - 시안 여러 개를 나란히 보는 비교 페이지 생성
  사용: powershell -NoProfile -ExecutionPolicy Bypass -File compare.ps1 -Files "page.html,page-A.html,page-B.html" [-Out compare.html] [-Notes "원본,A: 기존 다듬기,B: 미니멀"]
  (목록은 쉼표로 구분. 그래서 설명 안에는 쉼표를 쓰지 않는다)
#>
param(
    [Parameter(Mandatory = $true)][string[]]$Files,
    [string]$Out = 'compare.html',
    [string[]]$Notes = @(),
    [string]$Title = '디자인 시안 비교'
)

$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [Text.Encoding]::UTF8

# powershell -File 로 부르면 "a","b" 가 문자열 하나("a,b")로 들어오므로 쉼표로 나눈다
$Files = @($Files | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim() } | Where-Object { $_ })
$Notes = @($Notes | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim() })

$outFull =[IO.Path]::GetFullPath((Join-Path (Get-Location) $Out))
$outDir = Split-Path $outFull -Parent
$baseUri = New-Object Uri ($outDir.TrimEnd('\') + '\')

function ConvertTo-HtmlText($s) { return [Net.WebUtility]::HtmlEncode($s) }

$cards = New-Object System.Text.StringBuilder
for ($i = 0; $i -lt $Files.Count; $i++) {
    $full = (Resolve-Path -LiteralPath $Files[$i]).Path
    $rel = [Uri]::UnescapeDataString($baseUri.MakeRelativeUri((New-Object Uri $full)).ToString())
    $name = ConvertTo-HtmlText (Split-Path $full -Leaf)
    $note = ''
    if ($i -lt $Notes.Count) { $note = ConvertTo-HtmlText $Notes[$i] }
    $src = ConvertTo-HtmlText ([Uri]::EscapeUriString($rel))
    [void]$cards.AppendLine(@"
    <section class="card">
      <header>
        <span class="badge">$($i + 1)</span>
        <div class="meta"><strong>$name</strong><span>$note</span></div>
        <a href="$src" target="_blank">새 창</a>
      </header>
      <div class="stage"><iframe src="$src" loading="lazy" title="$name"></iframe></div>
    </section>
"@)
}

$page = @"
<!doctype html>
<html lang="ko">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>$(ConvertTo-HtmlText $Title)</title>
<style>
  :root { --bg:#f4f4f5; --panel:#ffffff; --line:#e4e4e7; --text:#18181b; --sub:#71717a; --accent:#18181b; }
  @media (prefers-color-scheme: dark) { :root { --bg:#111113; --panel:#1c1c1f; --line:#2e2e33; --text:#f4f4f5; --sub:#a1a1aa; --accent:#f4f4f5; } }
  * { box-sizing:border-box; }
  body { margin:0; background:var(--bg); color:var(--text); font:15px/1.5 system-ui,-apple-system,"Malgun Gothic",sans-serif; }
  .bar { position:sticky; top:0; z-index:1; display:flex; flex-wrap:wrap; gap:12px; align-items:center; justify-content:space-between; padding:12px 16px; background:var(--panel); border-bottom:1px solid var(--line); }
  .bar h1 { font-size:16px; margin:0; }
  .seg { display:inline-flex; border:1px solid var(--line); border-radius:999px; padding:3px; gap:2px; }
  .seg button { border:0; background:none; color:var(--sub); font:inherit; font-size:13px; padding:6px 12px; border-radius:999px; cursor:pointer; min-height:32px; }
  .seg button[aria-pressed="true"] { background:var(--accent); color:var(--bg); }
  .seg button:focus-visible, .card a:focus-visible { outline:2px solid var(--accent); outline-offset:2px; }
  main { display:grid; gap:16px; padding:16px; grid-template-columns:repeat(auto-fit, minmax(min(100%, var(--col, 420px)), 1fr)); }
  .card { background:var(--panel); border:1px solid var(--line); border-radius:12px; overflow:hidden; }
  .card header { display:flex; align-items:center; gap:10px; padding:10px 12px; border-bottom:1px solid var(--line); }
  .badge { width:28px; height:28px; border-radius:8px; display:grid; place-items:center; background:var(--accent); color:var(--bg); font-weight:700; font-size:13px; flex:none; }
  .meta { display:flex; flex-direction:column; min-width:0; flex:1; }
  .meta strong { font-size:14px; overflow:hidden; text-overflow:ellipsis; white-space:nowrap; }
  .meta span { font-size:12px; color:var(--sub); }
  .card a { color:var(--sub); font-size:13px; }
  .stage { position:relative; overflow:hidden; background:#fff; }
  .stage iframe { position:absolute; top:0; left:0; border:0; transform-origin:0 0; background:#fff; }
  footer { padding:0 16px 24px; color:var(--sub); font-size:13px; }
</style>
</head>
<body>
<div class="bar">
  <h1>$(ConvertTo-HtmlText $Title)</h1>
  <div class="seg" role="group" aria-label="화면 폭">
    <button data-w="1280" aria-pressed="true">데스크톱 1280</button>
    <button data-w="768" aria-pressed="false">태블릿 768</button>
    <button data-w="390" aria-pressed="false">모바일 390</button>
  </div>
</div>
<main>
$($cards.ToString())
</main>
<footer>마음에 드는 시안과 고칠 점을 OpenCode에 말해 주세요. 예: "B안으로. 제목은 더 크게, 카드 테두리는 없애줘"</footer>
<script>
  var W = 1280, H = 900;
  function fit() {
    document.querySelectorAll('.stage').forEach(function (st) {
      var f = st.querySelector('iframe');
      var s = Math.min(1, st.clientWidth / W);
      f.style.width = W + 'px'; f.style.height = H + 'px';
      f.style.transform = 'scale(' + s + ')';
      f.style.left = Math.max(0, (st.clientWidth - W * s) / 2) + 'px';
      st.style.height = Math.round(H * s) + 'px';
    });
  }
  document.querySelectorAll('.seg button').forEach(function (b) {
    b.addEventListener('click', function () {
      W = +b.dataset.w; H = W < 500 ? 780 : 900;
      document.querySelector('main').style.setProperty('--col', W < 500 ? '300px' : '420px');
      document.querySelectorAll('.seg button').forEach(function (x) { x.setAttribute('aria-pressed', x === b); });
      fit();
    });
  });
  window.addEventListener('resize', fit);
  fit();
</script>
</body>
</html>
"@

[IO.File]::WriteAllText($outFull, $page, (New-Object Text.UTF8Encoding($false)))
"비교 페이지 생성: $outFull ($($Files.Count)개 시안)"
