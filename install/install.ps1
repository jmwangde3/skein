<#
Skein 安装脚本（Windows PowerShell 5.1 / 7）
用法：
  powershell -ExecutionPolicy Bypass -File install\install.ps1
  powershell -ExecutionPolicy Bypass -File install\install.ps1 -Client all -Project "D:\work\我的项目" -Data "D:\skein-data"
#>
[CmdletBinding()]
param(
    [ValidateSet('all','claude','codex','workbuddy','custom')]
    [string]$Client = 'all',
    [string]$Dir,
    [string]$Project,
    [string]$Data,
    [string]$Prefix = 'sk',
    [switch]$Force
)

$ErrorActionPreference = 'Stop'
$Repo = Split-Path -Parent $PSScriptRoot
$SkillNames = @('task-checkpoint','agent-handoff','project-memory','agent-collab')

function To-Fwd([string]$p) { return ($p -replace '\\','/') }

function Install-Skills([string]$dest) {
    if (-not (Test-Path -LiteralPath $dest)) {
        New-Item -ItemType Directory -Path $dest -Force | Out-Null
    }
    foreach ($s in $SkillNames) {
        $target = Join-Path $dest $s
        if ((Test-Path -LiteralPath $target) -and (-not $Force)) {
            Write-Host "  跳过（已存在）：$target"
            continue
        }
        if (Test-Path -LiteralPath $target) { Remove-Item -LiteralPath $target -Recurse -Force }
        Copy-Item -LiteralPath (Join-Path $Repo "skills\$s") -Destination $target -Recurse -Force
        Write-Host "  已装：$target"
    }
}

function Write-Utf8NoBom([string]$path, [string]$text) {
    $enc = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($path, $text, $enc)
}

Write-Host "== 1/2 安装技能 =="
$home_ = $env:USERPROFILE
switch ($Client) {
    'claude'    { Install-Skills (Join-Path $home_ '.claude\skills') }
    'codex'     { Install-Skills (Join-Path $home_ '.codex\skills') }
    'workbuddy' { Install-Skills (Join-Path $home_ '.workbuddy\skills') }
    'all' {
        Install-Skills (Join-Path $home_ '.claude\skills')
        Install-Skills (Join-Path $home_ '.codex\skills')
        Install-Skills (Join-Path $home_ '.workbuddy\skills')
    }
    'custom' {
        if (-not $Dir) { throw ' -Client custom 必须同时给 -Dir' }
        Install-Skills $Dir
    }
}

if (-not $Project) {
    Write-Host ""
    Write-Host "技能装好了。要做项目部署，再加 -Project <项目路径> 重跑。"
    exit 0
}

Write-Host ""
Write-Host "== 2/2 部署到项目 =="
if (-not (Test-Path -LiteralPath $Project)) { throw " 项目目录不存在：$Project" }
$Proj = (Resolve-Path -LiteralPath $Project).Path
$Name = Split-Path $Proj -Leaf

if ($Data) { $Root = $Data } else { $Root = Join-Path $home_ 'skein-data' }
if (-not (Test-Path -LiteralPath $Root)) { New-Item -ItemType Directory -Path $Root -Force | Out-Null }
$Root = (Resolve-Path -LiteralPath $Root).Path
$D = Join-Path $Root $Name

foreach ($p in @('store','checkpoints','backups')) {
    $full = Join-Path $D $p
    if (-not (Test-Path -LiteralPath $full)) { New-Item -ItemType Directory -Path $full -Force | Out-Null }
}
foreach ($p in @('facts','decisions','runbooks','journal','proposals','archive')) {
    $full = Join-Path $D "kb\$p"
    if (-not (Test-Path -LiteralPath $full)) { New-Item -ItemType Directory -Path $full -Force | Out-Null }
}
Write-Host "  数据目录：$(To-Fwd $D)"

$Local = Join-Path $Proj 'AGENTS.local.md'
if (Test-Path -LiteralPath $Local) {
    Write-Host "  AGENTS.local.md 已存在，保留不动"
} else {
    $tpl = Get-Content -LiteralPath (Join-Path $Repo 'templates\AGENTS.local.md') -Raw -Encoding UTF8
    $tpl = $tpl.Replace('{{PROJECT}}', $Name).Replace('{{DATA}}', (To-Fwd $D)).Replace('{{WORKTREE_ROOT}}', (To-Fwd $Root))
    Write-Utf8NoBom $Local $tpl
    Write-Host "  已生成：AGENTS.local.md"
}

$gitDir = Join-Path $Proj '.git'
if (Test-Path -LiteralPath $gitDir) {
    $ex = Join-Path $gitDir 'info\exclude'
    $infoDir = Join-Path $gitDir 'info'
    if (-not (Test-Path -LiteralPath $infoDir)) { New-Item -ItemType Directory -Path $infoDir -Force | Out-Null }
    $exists = $false
    if (Test-Path -LiteralPath $ex) {
        $exists = (Get-Content -LiteralPath $ex) -contains '/AGENTS.local.md'
    }
    if (-not $exists) {
        Add-Content -LiteralPath $ex -Value '/AGENTS.local.md' -Encoding ASCII
    }
    Write-Host "  已加入 .git/info/exclude"
} else {
    Write-Host "  提示：这个目录还不是 git 仓，AGENTS.local.md 暂时无处排除；git init 后重跑本脚本即可"
}

$Kb = Join-Path $D 'kb'
if (-not (Test-Path -LiteralPath (Join-Path $Kb '.git'))) {
    git -C $Kb init -q
    Write-Host "  知识库已初始化（独立仓）"
}
$indexPath = Join-Path $Kb 'INDEX.md'
if (-not (Test-Path -LiteralPath $indexPath)) {
    $idx = Get-Content -LiteralPath (Join-Path $Repo 'templates\kb-INDEX.md') -Raw -Encoding UTF8
    Write-Utf8NoBom $indexPath $idx.Replace('{{PROJECT}}', $Name)
}
$curPath = Join-Path $Kb 'current.md'
if (-not (Test-Path -LiteralPath $curPath)) {
    Copy-Item -LiteralPath (Join-Path $Repo 'templates\kb-current.md') -Destination $curPath
}
$hasHead = $false
& git -C $Kb rev-parse --verify --quiet HEAD | Out-Null
if ($LASTEXITCODE -eq 0) { $hasHead = $true }
if (-not $hasHead) {
    git -C $Kb -c core.autocrlf=false add -A
    git -C $Kb -c core.autocrlf=false -c user.name=skein -c user.email=skein@local commit -q -m "kb: 初始化"
    Write-Host "  知识库已提交"
}

$Store = Join-Path $D 'store'
$bd = Get-Command bd -ErrorAction SilentlyContinue
if (Test-Path -LiteralPath (Join-Path $Store '.beads')) {
    Write-Host "  任务库已存在，跳过 init"
} elseif ($bd) {
    Push-Location $Store
    try {
        # 用 cmd 吞掉 stderr：bd init 在非 git 目录会打一条无害警告，PowerShell 会当成错误刷屏
        & cmd /c "bd init --prefix $Prefix --non-interactive --stealth --skip-agents >nul 2>nul"
    }
    finally { Pop-Location }
    Write-Host "  任务库已初始化（前缀 $Prefix）"
} else {
    Write-Host "  未找到 bd，任务库留空。装好 Beads 后进入目录再 init："
    Write-Host "    cd `"$(To-Fwd $Store)`" ; bd init --prefix $Prefix --non-interactive --stealth --skip-agents"
}

Write-Host ""
Write-Host "完成。还差三步手工动作："
Write-Host ""
Write-Host "1. 把 templates\AGENTS.md.pointer.md 里「Skein 协作」那一节贴进 $Name\AGENTS.md"
Write-Host "2. 重启 AI 客户端（多数客户端只在启动时扫描技能目录）"
Write-Host "3. 自检：git -C `"$(To-Fwd $Kb)`" remote -v   必须没有任何输出"
Write-Host ""
Write-Host "数据目录结构："
Write-Host "  $(To-Fwd $D)\{store,checkpoints,kb,backups}"
