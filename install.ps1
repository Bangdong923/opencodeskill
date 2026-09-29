<#
  install.ps1 - OpenCode 스킬 키트 설치
  사용: 압축을 푼 폴더에서
        powershell -NoProfile -ExecutionPolicy Bypass -File install.ps1
  다른 위치에 설치: -Target "D:\somewhere\opencode"
#>
param([string]$Target = (Join-Path $HOME '.config\opencode'))

$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [Text.Encoding]::UTF8
$src = $PSScriptRoot
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$backup = Join-Path $Target "backup-design-kit-$stamp"
$utf8 = New-Object Text.UTF8Encoding($false)

function Backup-Item($path) {
    if (Test-Path -LiteralPath $path) {
        New-Item -ItemType Directory -Force $backup | Out-Null
        Move-Item -LiteralPath $path -Destination $backup
        "  기존 항목 백업: $(Split-Path $path -Leaf) -> $backup"
    }
}

New-Item -ItemType Directory -Force (Join-Path $Target 'skills'), (Join-Path $Target 'commands') | Out-Null

"스킬 설치 -> $Target\skills"
foreach ($dir in Get-ChildItem (Join-Path $src 'skills') -Directory) {
    $dst = Join-Path $Target "skills\$($dir.Name)"
    Backup-Item $dst
    Copy-Item -LiteralPath $dir.FullName -Destination $dst -Recurse
    "  + $($dir.Name)"
}

"명령어 설치 -> $Target\commands"
foreach ($file in Get-ChildItem (Join-Path $src 'commands') -File) {
    $dst = Join-Path $Target "commands\$($file.Name)"
    Backup-Item $dst
    Copy-Item -LiteralPath $file.FullName -Destination $dst
    "  + /$($file.BaseName)"
}

# 스킬·명령어 안의 {{KIT_DIR}}를 실제 경로로 바꾼다 (슬래시 경로는 cmd, bash, PowerShell 모두에서 동작)
$kitDir = (Join-Path $Target 'skills\design-upgrade') -replace '\\', '/'
$targets = @((Join-Path $Target 'skills\design-upgrade\SKILL.md')) + @(Get-ChildItem (Join-Path $src 'commands') -File | ForEach-Object { Join-Path $Target "commands\$($_.Name)" })
foreach ($f in $targets) {
    $text = [IO.File]::ReadAllText($f, [Text.Encoding]::UTF8)
    [IO.File]::WriteAllText($f, $text.Replace('{{KIT_DIR}}', $kitDir), $utf8)
}

# 인터넷에서 받은 zip이면 스크립트에 붙은 '다운로드됨' 표시를 지운다
Get-ChildItem (Join-Path $Target 'skills\design-upgrade\scripts') -Filter *.ps1 | Unblock-File

''
'점검 스크립트 동작 확인...'
$test = & powershell -NoProfile -ExecutionPolicy Bypass -File "$kitDir/scripts/audit.ps1" -Path (Join-Path $src 'example\sample.html') 2>&1
$last = ($test | Select-Object -Last 1)
if ($last -match '요약') { "  OK  ($last)" } else { '  실패: 아래 메시지를 확인하세요'; $test }

''
'설치 완료. OpenCode를 다시 시작한 뒤:'
'  /upgrade-design 파일.html    디자인 업그레이드 (시안 + 비교 페이지)'
'  /design-audit 파일.html      점검만'
