<#
  audit.ps1 - 이미지를 못 보는 모델을 위한 HTML/CSS 디자인 점검
  사용: powershell -NoProfile -ExecutionPolicy Bypass -File audit.ps1 -Path page.html [-Design DESIGN.md] [-Json]
  종료 코드: 오류가 있으면 1, 없으면 0
#>
param(
    [Parameter(Mandatory = $true)][string]$Path,
    [string]$Design,
    [switch]$Json
)

$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [Text.Encoding]::UTF8

$htmlPath = (Resolve-Path -LiteralPath $Path).Path
$htmlDir = Split-Path $htmlPath -Parent
$html = [IO.File]::ReadAllText($htmlPath, [Text.Encoding]::UTF8)

if (-not $Design) {
    $candidate = Join-Path $htmlDir 'DESIGN.md'
    if (Test-Path -LiteralPath $candidate) { $Design = $candidate }
}

$issues = New-Object System.Collections.Generic.List[object]
function Add-Issue($level, $category, $message) {
    $issues.Add([pscustomobject]@{ Level = $level; Category = $category; Message = $message })
}

# ---------- 색 ----------
function Convert-Channel($v) {
    if ($v.EndsWith('%')) { return [double]$v.TrimEnd('%') * 2.55 }
    return [double]$v
}
function Convert-Alpha($v) {
    if (-not $v) { return 1.0 }
    if ($v.EndsWith('%')) { return [double]$v.TrimEnd('%') / 100 }
    return [double]$v
}
function ConvertFrom-Hsl($h, $s, $l) {
    $h = ($h % 360) / 360; $s = $s / 100; $l = $l / 100
    if ($s -eq 0) { $v = $l * 255; return @($v, $v, $v) }
    $q = if ($l -lt 0.5) { $l * (1 + $s) } else { $l + $s - $l * $s }
    $p = 2 * $l - $q
    $out = @()
    foreach ($t0 in @(($h + 1 / 3), $h, ($h - 1 / 3))) {
        $t = $t0
        if ($t -lt 0) { $t += 1 }
        if ($t -gt 1) { $t -= 1 }
        if ($t -lt 1 / 6) { $c = $p + ($q - $p) * 6 * $t }
        elseif ($t -lt 1 / 2) { $c = $q }
        elseif ($t -lt 2 / 3) { $c = $p + ($q - $p) * (2 / 3 - $t) * 6 }
        else { $c = $p }
        $out += $c * 255
    }
    return $out
}
function ConvertTo-Color($s) {
    $s = $s.Trim().ToLower()
    if ($s -eq 'white') { return @{ R = 255; G = 255; B = 255; A = 1.0 } }
    if ($s -eq 'black') { return @{ R = 0; G = 0; B = 0; A = 1.0 } }
    if ($s -eq 'transparent') { return @{ R = 0; G = 0; B = 0; A = 0.0 } }
    if ($s -match '^#([0-9a-f]+)$') {
        $h = $Matches[1]
        if ($h.Length -eq 3 -or $h.Length -eq 4) { $h = -join ($h.ToCharArray() | ForEach-Object { "$_$_" }) }
        if ($h.Length -ne 6 -and $h.Length -ne 8) { return $null }
        $a = 1.0
        if ($h.Length -eq 8) { $a = [Convert]::ToInt32($h.Substring(6, 2), 16) / 255 }
        return @{ R = [Convert]::ToInt32($h.Substring(0, 2), 16); G = [Convert]::ToInt32($h.Substring(2, 2), 16); B = [Convert]::ToInt32($h.Substring(4, 2), 16); A = $a }
    }
    if ($s -match '^rgba?\(\s*([\d.]+%?)[\s,]+([\d.]+%?)[\s,]+([\d.]+%?)(?:\s*[,/]\s*([\d.]+%?))?\s*\)$') {
        return @{ R = (Convert-Channel $Matches[1]); G = (Convert-Channel $Matches[2]); B = (Convert-Channel $Matches[3]); A = (Convert-Alpha $Matches[4]) }
    }
    if ($s -match '^hsla?\(\s*([\d.]+)(?:deg)?[\s,]+([\d.]+)%[\s,]+([\d.]+)%(?:\s*[,/]\s*([\d.]+%?))?\s*\)$') {
        $rgb = ConvertFrom-Hsl ([double]$Matches[1]) ([double]$Matches[2]) ([double]$Matches[3])
        return @{ R = $rgb[0]; G = $rgb[1]; B = $rgb[2]; A = (Convert-Alpha $Matches[4]) }
    }
    return $null
}
function Get-Hex($c) {
    return ('#{0:x2}{1:x2}{2:x2}' -f [int][Math]::Round($c.R), [int][Math]::Round($c.G), [int][Math]::Round($c.B))
}
function Merge-Color($fg, $bg) {
    $a = $fg.A
    return @{ R = $fg.R * $a + $bg.R * (1 - $a); G = $fg.G * $a + $bg.G * (1 - $a); B = $fg.B * $a + $bg.B * (1 - $a); A = 1.0 }
}
function Get-Luminance($c) {
    $vals = foreach ($v in @($c.R, $c.G, $c.B)) {
        $x = $v / 255
        if ($x -le 0.03928) { $x / 12.92 } else { [Math]::Pow(($x + 0.055) / 1.055, 2.4) }
    }
    return 0.2126 * $vals[0] + 0.7152 * $vals[1] + 0.0722 * $vals[2]
}
function Get-Contrast($a, $b) {
    $l1 = Get-Luminance $a; $l2 = Get-Luminance $b
    return ([Math]::Max($l1, $l2) + 0.05) / ([Math]::Min($l1, $l2) + 0.05)
}
$colorPattern = '#[0-9a-fA-F]{3,8}\b|rgba?\([^)]*\)|hsla?\([^)]*\)|\b(?:white|black|transparent)\b'
function Get-FirstColor($value) {
    foreach ($m in [regex]::Matches($value, $colorPattern)) {
        $c = ConvertTo-Color $m.Value
        if ($c) { return $c }
    }
    return $null
}

# ---------- 길이 ----------
function ConvertTo-Px($num, $unit) {
    switch ($unit.ToLower()) {
        'px' { return [double]$num }
        'rem' { return [double]$num * 16 }
        'em' { return [double]$num * 16 }
        'pt' { return [double]$num * 4 / 3 }
    }
    return $null
}
$lengthPattern = '(-?\d*\.?\d+)(px|rem|em|pt)\b'
function Get-Lengths($value) {
    foreach ($m in [regex]::Matches($value, $lengthPattern)) {
        [Math]::Abs((ConvertTo-Px $m.Groups[1].Value $m.Groups[2].Value))
    }
}

# ---------- CSS 모으기 ----------
$cssParts = New-Object System.Collections.Generic.List[string]
foreach ($m in [regex]::Matches($html, '<style[^>]*>([\s\S]*?)</style>', 'IgnoreCase')) { $cssParts.Add($m.Groups[1].Value) }
foreach ($m in [regex]::Matches($html, '<link\b[^>]*>', 'IgnoreCase')) {
    $tag = $m.Value
    if ($tag -notmatch 'stylesheet') { continue }
    if ($tag -match 'href\s*=\s*["'']([^"'']+)["'']') {
        $href = $Matches[1]
        if ($href -match '^(https?:)?//') { continue }
        $cssFile = Join-Path $htmlDir ($href -split '[?#]')[0]
        if (Test-Path -LiteralPath $cssFile) { $cssParts.Add([IO.File]::ReadAllText($cssFile, [Text.Encoding]::UTF8)) }
        else { Add-Issue '경고' '파일' "연결된 CSS 파일을 찾을 수 없음: $href" }
    }
}
$inlineCount = 0
foreach ($m in [regex]::Matches($html, '\sstyle\s*=\s*("([^"]*)"|''([^'']*)'')', 'IgnoreCase')) {
    $inlineCount++
    $cssParts.Add("[inline-style]{" + $m.Groups[2].Value + $m.Groups[3].Value + "}")
}
$css = [regex]::Replace(($cssParts -join "`n"), '/\*[\s\S]*?\*/', '')

# 중괄호를 따라가며 규칙(선택자, 선언, 감싼 @규칙)을 뽑는다
$rules = New-Object System.Collections.Generic.List[object]
$stack = New-Object System.Collections.Generic.List[string]
$buf = New-Object System.Text.StringBuilder
foreach ($ch in $css.ToCharArray()) {
    if ($ch -eq '{') {
        $stack.Add($buf.ToString().Trim()); [void]$buf.Clear()
    }
    elseif ($ch -eq '}') {
        if ($stack.Count -eq 0) { [void]$buf.Clear(); continue }
        $sel = $stack[$stack.Count - 1]; $stack.RemoveAt($stack.Count - 1)
        $body = $buf.ToString().Trim(); [void]$buf.Clear()
        $wrap = ($stack | Where-Object { $_.StartsWith('@') }) -join ' '
        if (-not $sel.StartsWith('@') -and $body -and $wrap -notmatch '@(-webkit-)?keyframes') {
            $rules.Add([pscustomobject]@{ Selector = $sel; Body = $body; Wrap = $wrap })
        }
    }
    elseif ($ch -eq ';' -and $stack.Count -eq 0) {
        [void]$buf.Clear()
    }
    else { [void]$buf.Append($ch) }
}

$importantCount = 0
$vars = @{}
foreach ($r in $rules) {
    $decls = [ordered]@{}
    foreach ($part in ($r.Body -split ';')) {
        $i = $part.IndexOf(':')
        if ($i -lt 1) { continue }
        $prop = $part.Substring(0, $i).Trim().ToLower()
        $val = $part.Substring($i + 1).Trim()
        if ($val -match '!important') { $importantCount++; $val = ($val -replace '\s*!important', '').Trim() }
        $decls[$prop] = $val
        if ($prop.StartsWith('--')) { $vars[$prop] = $val }
    }
    $r | Add-Member -NotePropertyName Decls -NotePropertyValue $decls
}

function Resolve-Var($value) {
    for ($n = 0; $n -lt 6 -and $value -match 'var\('; $n++) {
        $value = [regex]::Replace($value, 'var\(\s*(--[\w-]+)\s*(?:,\s*([^()]*))?\)', {
                param($m)
                $key = $m.Groups[1].Value
                if ($vars.ContainsKey($key)) { return $vars[$key] }
                return $m.Groups[2].Value
            })
    }
    return $value
}

# ---------- DESIGN.md 토큰 ----------
$tokens = @{}
if ($Design) {
    $designText = [IO.File]::ReadAllText((Resolve-Path -LiteralPath $Design).Path, [Text.Encoding]::UTF8)
    if ($designText -match '```tokens\s*\r?\n([\s\S]*?)```') {
        foreach ($line in ($Matches[1] -split '\r?\n')) {
            if ($line -match '^\s*([\w-]+)\s*:\s*(.+)$') {
                $tokens[$Matches[1].ToLower()] = @($Matches[2] -split '\s*,\s*' | ForEach-Object { $_.Trim() } | Where-Object { $_ })
            }
        }
    }
    else { Add-Issue '경고' '기준' "DESIGN.md에 ```tokens 블록이 없어 토큰 비교를 건너뜀" }
}
function Get-TokenNumbers($key) {
    if (-not $tokens.ContainsKey($key)) { return $null }
    return @($tokens[$key] | ForEach-Object { [double]($_ -replace '[^\d.]', '') })
}
$tokenColors = $null
if ($tokens.ContainsKey('colors')) {
    $tokenColors = @($tokens['colors'] | ForEach-Object { $c = ConvertTo-Color $_; if ($c) { Get-Hex $c } })
}
$tokenSizes = Get-TokenNumbers 'font-sizes'
$tokenSpacing = Get-TokenNumbers 'spacing'
$tokenRadius = Get-TokenNumbers 'radius'
$tokenFonts = $null
if ($tokens.ContainsKey('fonts')) { $tokenFonts = @($tokens['fonts'] | ForEach-Object { $_.Trim('"', "'").ToLower() }) }
function Test-OnScale($px, $scale) {
    foreach ($s in $scale) { if ([Math]::Abs($s - $px) -lt 0.6) { return $true } }
    return $false
}

# ---------- 페이지 배경 ----------
$pageBg = @{ R = 255; G = 255; B = 255; A = 1.0 }
foreach ($r in $rules) {
    if ($r.Wrap) { continue }
    $sels = $r.Selector -split ',' | ForEach-Object { $_.Trim() }
    if (-not ($sels | Where-Object { $_ -in @('html', 'body', ':root') })) { continue }
    foreach ($p in @('background-color', 'background')) {
        if ($r.Decls.Contains($p)) {
            $c = Get-FirstColor (Resolve-Var $r.Decls[$p])
            if ($c -and $c.A -gt 0) { $pageBg = Merge-Color $c @{ R = 255; G = 255; B = 255; A = 1.0 } }
        }
    }
}

# ---------- 규칙별 점검 ----------
$colorUse = @{}; $sizeUse = @{}; $spaceUse = @{}; $radiusUse = @{}; $fontUse = @{}
$contrastFails = New-Object System.Collections.Generic.List[string]
$hasMaxWidth = $false; $hasFocus = $false; $hasMotion = $false; $hasReducedMotion = $false
$genericFonts = @('serif', 'sans-serif', 'monospace', 'system-ui', 'cursive', 'fantasy', 'inherit', 'initial', 'ui-sans-serif', 'ui-serif', 'ui-monospace', '-apple-system', 'blinkmacsystemfont')
function Add-Count($table, $key) { if ($table.ContainsKey($key)) { $table[$key]++ } else { $table[$key] = 1 } }

if ($css -match '@media[^{]*prefers-reduced-motion') { $hasReducedMotion = $true }
$mediaCount = ([regex]::Matches($css, '@media\b')).Count

foreach ($r in $rules) {
    $d = $r.Decls
    if ($r.Selector -match ':focus') { $hasFocus = $true }
    foreach ($prop in @($d.Keys)) {
        if ($prop.StartsWith('--')) { continue }
        $val = Resolve-Var $d[$prop]

        if ($prop -match '^(color|background(-color)?|border(-(top|right|bottom|left))?(-color)?|outline(-color)?|fill|stroke|box-shadow|text-decoration-color)$') {
            foreach ($m in [regex]::Matches($val, $colorPattern)) {
                $c = ConvertTo-Color $m.Value
                if ($c -and $c.A -gt 0) { Add-Count $colorUse (Get-Hex $c) }
            }
        }
        if ($prop -eq 'font-size') {
            if ($val -match '(clamp|min|max|calc)\(') { Add-Count $sizeUse 'fluid(clamp 등)' }
            else { foreach ($px in (Get-Lengths $val | Select-Object -First 1)) { Add-Count $sizeUse ([Math]::Round($px, 1)) } }
        }
        if ($prop -match '^(margin|padding)(-(top|right|bottom|left|inline|block)(-(start|end))?)?$|^(gap|row-gap|column-gap)$') {
            if ($val -notmatch '(clamp|min|max|calc)\(') {
                foreach ($px in (Get-Lengths $val)) { if ($px -gt 2) { Add-Count $spaceUse ([Math]::Round($px, 1)) } }
            }
        }
        if ($prop -eq 'border-radius') {
            foreach ($px in (Get-Lengths $val)) { if ($px -gt 0) { Add-Count $radiusUse ([Math]::Round($px, 1)) } }
        }
        if ($prop -eq 'font-family') {
            $first = (($val -split ',')[0]).Trim().Trim('"', "'")
            if ($first -and ($genericFonts -notcontains $first.ToLower())) { Add-Count $fontUse $first }
        }
        if ($prop -eq 'max-width' -and $val -ne 'none') { $hasMaxWidth = $true }
        if ($prop -match '^(transition|animation)') { $hasMotion = $true }
    }

    # 대비: 같은 규칙의 배경, 없으면 페이지 배경 위라고 가정
    if ($d.Contains('color')) {
        $fg = Get-FirstColor (Resolve-Var $d['color'])
        if ($fg -and $fg.A -gt 0) {
            $bg = $null
            foreach ($p in @('background-color', 'background')) {
                if (-not $bg -and $d.Contains($p)) {
                    $bv = Resolve-Var $d[$p]
                    if ($bv -notmatch 'gradient|url\(') { $bg = Get-FirstColor $bv }
                }
            }
            if (-not $bg -or $bg.A -eq 0) { $bg = $pageBg } elseif ($bg.A -lt 1) { $bg = Merge-Color $bg $pageBg }
            $fgFlat = Merge-Color $fg $bg
            $ratio = Get-Contrast $fgFlat $bg
            $large = $r.Selector -match '(^|[\s,>])h[1-3]\b'
            if ($d.Contains('font-size')) {
                $fs = Get-Lengths (Resolve-Var $d['font-size']) | Select-Object -First 1
                if ($fs -ge 24) { $large = $true }
            }
            $need = if ($large) { 3.0 } else { 4.5 }
            if ($ratio -lt $need) {
                $contrastFails.Add(('{0}  글자 {1} / 배경 {2} = {3:N2}:1 (기준 {4}:1)' -f $r.Selector, (Get-Hex $fgFlat), (Get-Hex $bg), $ratio, $need))
            }
        }
    }

    # 고정 폭: 모바일에서 넘칠 수 있음
    if ($r.Wrap -notmatch 'min-width') {
        foreach ($p in @('width', 'min-width')) {
            if ($d.Contains($p) -and (Resolve-Var $d[$p]) -match '^\s*(\d+(\.\d+)?)px\s*$' -and [double]$Matches[1] -ge 480 -and -not $d.Contains('max-width')) {
                Add-Issue '경고' '반응형' ("{0} {{ {1}: {2} }} 고정 폭이라 모바일(390px)에서 넘칠 수 있음 -> max-width 또는 %로" -f $r.Selector, $p, $d[$p])
            }
        }
    }

    # 누르는 영역
    if ($r.Selector -match 'button|\.btn|\binput\b|role=.?button|(^|[\s,>])a([\s:.,\[]|$)') {
        foreach ($p in @('height', 'min-height')) {
            if ($d.Contains($p)) {
                $h = Get-Lengths (Resolve-Var $d[$p]) | Select-Object -First 1
                if ($h -and $h -lt 44) { Add-Issue '경고' '터치' ("{0} {{ {1}: {2} }} 누르는 영역이 44px보다 작음" -f $r.Selector, $p, $d[$p]) }
            }
        }
    }
}

# ---------- 판정 ----------
foreach ($f in $contrastFails) { Add-Issue '오류' '대비' $f }

if ($html -notmatch '<meta[^>]+name\s*=\s*["'']?viewport') { Add-Issue '오류' '반응형' '<meta name="viewport"> 없음 -> 모바일에서 축소돼 보임' }
if ($mediaCount -eq 0 -and $css -notmatch '(clamp|min|max)\(') { Add-Issue '경고' '반응형' '@media도 clamp()도 없음 -> 모바일 대응이 없을 가능성' }
if (-not $hasMaxWidth) { Add-Issue '경고' '레이아웃' 'max-width가 하나도 없음 -> 넓은 화면에서 본문 줄이 너무 길어짐 (본문 60~72ch 권장)' }
if (-not $hasFocus -and $html -match '<(a|button|input)\b') { Add-Issue '경고' '접근성' ':focus / :focus-visible 스타일 없음 -> 키보드 사용자가 위치를 못 봄' }
if ($hasMotion -and -not $hasReducedMotion) { Add-Issue '경고' '접근성' '움직임이 있는데 prefers-reduced-motion 대응 없음' }
$noAlt = ([regex]::Matches($html, '<img\b(?![^>]*\balt\s*=)[^>]*>', 'IgnoreCase')).Count
if ($noAlt -gt 0) { Add-Issue '경고' '접근성' "alt 없는 <img> $noAlt 개" }
if ($importantCount -gt 5) { Add-Issue '경고' '코드' "!important $importantCount 회 -> 규칙 충돌 가능성" }
if ($inlineCount -gt 10) { Add-Issue '경고' '코드' "인라인 style 속성 $inlineCount 개 -> 클래스로 옮기면 일관성 유지가 쉬움" }

foreach ($r in $rules) {
    if ($r.Selector -match '(^|[\s,])(body|p|html)\b' -and $r.Decls.Contains('line-height')) {
        $lh = Resolve-Var $r.Decls['line-height']
        if ($lh -match '^\s*(\d*\.?\d+)\s*$' -and [double]$Matches[1] -lt 1.4) { Add-Issue '경고' '글자' ("{0} line-height {1} -> 본문은 1.5~1.7 권장" -f $r.Selector, $lh) }
    }
}

$numericSizes = @($sizeUse.Keys | Where-Object { $_ -is [double] })
if ($tokenSizes) {
    foreach ($s in $numericSizes) { if (-not (Test-OnScale $s $tokenSizes)) { Add-Issue '경고' '토큰' "글자 크기 ${s}px 가 DESIGN.md 단계에 없음 ($($sizeUse[$s])회)" } }
}
elseif ($numericSizes.Count -gt 8) { Add-Issue '경고' '글자' "글자 크기가 $($numericSizes.Count)종류 -> 6~8단계로 줄이면 위계가 선명해짐" }

if ($tokenSpacing) {
    foreach ($s in $spaceUse.Keys) { if (-not (Test-OnScale $s $tokenSpacing)) { Add-Issue '경고' '토큰' "여백 ${s}px 가 DESIGN.md 단계에 없음 ($($spaceUse[$s])회)" } }
}
else {
    foreach ($s in $spaceUse.Keys) { if ($s % 4 -ne 0) { Add-Issue '경고' '여백' "여백 ${s}px 가 4의 배수가 아님 ($($spaceUse[$s])회)" } }
}

if ($tokenRadius) {
    foreach ($s in $radiusUse.Keys) { if (-not (Test-OnScale $s $tokenRadius)) { Add-Issue '경고' '토큰' "모서리 ${s}px 가 DESIGN.md 단계에 없음 ($($radiusUse[$s])회)" } }
}
elseif ($radiusUse.Count -gt 3) { Add-Issue '경고' '모서리' "border-radius가 $($radiusUse.Count)종류 -> 1~2종 권장" }

if ($tokenColors) {
    foreach ($c in $colorUse.Keys) { if ($tokenColors -notcontains $c) { Add-Issue '경고' '토큰' "색 $c 가 DESIGN.md에 없음 ($($colorUse[$c])회)" } }
}
elseif ($colorUse.Count -gt 12) { Add-Issue '경고' '색' "색이 $($colorUse.Count)종류 -> 중립색 몇 개 + 강조색 1개로 줄이기" }

if ($tokenFonts) {
    foreach ($f in $fontUse.Keys) { if ($tokenFonts -notcontains $f.ToLower()) { Add-Issue '경고' '토큰' "글꼴 '$f' 가 DESIGN.md에 없음" } }
}
elseif ($fontUse.Count -gt 2) { Add-Issue '경고' '글자' "글꼴이 $($fontUse.Count)종류 ($(@($fontUse.Keys) -join ', ')) -> 2종 이하 권장" }

# ---------- 출력 ----------
$errors = @($issues | Where-Object { $_.Level -eq '오류' }).Count
$warns = @($issues | Where-Object { $_.Level -eq '경고' }).Count
function Format-Table2($table) {
    (@($table.GetEnumerator() | Sort-Object { $_.Value } -Descending | ForEach-Object { "$($_.Key)×$($_.Value)" }) -join ', ')
}

if ($Json) {
    function ConvertTo-StringKeys($table) { $o = [ordered]@{}; foreach ($k in $table.Keys) { $o["$k"] = $table[$k] }; return $o }
    foreach ($name in 'colorUse', 'sizeUse', 'spaceUse', 'radiusUse', 'fontUse') { Set-Variable $name (ConvertTo-StringKeys (Get-Variable $name -ValueOnly)) }
    [pscustomobject]@{
        file   = $htmlPath
        design = $Design
        errors = $errors
        warnings = $warns
        issues = $issues
        stats  = [pscustomobject]@{ colors = $colorUse; fontSizes = $sizeUse; spacing = $spaceUse; radius = $radiusUse; fonts = $fontUse; mediaQueries = $mediaCount; pageBackground = (Get-Hex $pageBg) }
    } | ConvertTo-Json -Depth 5
}
else {
    "=== 디자인 점검: $(Split-Path $htmlPath -Leaf) ==="
    if ($Design) { "기준: $(Split-Path $Design -Leaf) (토큰 $(if ($tokens.Count) { '있음' } else { '없음' }))" } else { '기준: 없음 (DESIGN.md 없이 일반 규칙으로 점검)' }
    ''
    $limit = 12
    foreach ($g in ($issues | Group-Object Category)) {
        $items = @($g.Group | Sort-Object { if ($_.Level -eq '오류') { 0 } else { 1 } })
        foreach ($it in ($items | Select-Object -First $limit)) { "[$($it.Level)] $($it.Category) | $($it.Message)" }
        if ($items.Count -gt $limit) { "[$($items[0].Level)] $($g.Name) | ... 외 $($items.Count - $limit)건" }
    }
    ''
    '--- 사용 현황 ---'
    "페이지 배경: $(Get-Hex $pageBg)"
    "색 $($colorUse.Count)종: $(Format-Table2 $colorUse)"
    "글자 크기 $($sizeUse.Count)종(px): $(Format-Table2 $sizeUse)"
    "여백 $($spaceUse.Count)종(px): $(Format-Table2 $spaceUse)"
    "모서리 $($radiusUse.Count)종(px): $(Format-Table2 $radiusUse)"
    "글꼴: $(Format-Table2 $fontUse)"
    "@media: $mediaCount 개"
    ''
    '참고: 대비는 CSS 규칙 단위 추정(같은 규칙 배경, 없으면 페이지 배경). 그라데이션/이미지 위 글자는 따로 확인.'
    "요약: 오류 $errors · 경고 $warns"
}
if ($errors -gt 0) { exit 1 } else { exit 0 }
