<#
Skein 安装脚本（Windows PowerShell 5.1 / 7）
用法：
  powershell -ExecutionPolicy Bypass -File install\install.ps1
  powershell -ExecutionPolicy Bypass -File install\install.ps1 -Client all -Project "D:\work\我的项目" -Data "D:\skein-data"

装什么、装到哪：
  全局：只有 task-checkpoint（长任务落盘，所有项目都要用）
  项目：agent-handoff / project-memory / agent-collab，装到 <项目>\.<客户端>\skills
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
$GlobalSkill = 'task-checkpoint'
$ProjectSkills = @('agent-handoff','project-memory','agent-collab')

function To-Fwd([string]$p) { return ($p -replace '\\','/') }

function Write-Utf8NoBom([string]$path, [string]$text) {
    $enc = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($path, $text, $enc)
}

function Install-One([string]$dest, [string]$s) {
    $source = Join-Path $Repo "skills\$s"
    $target = Join-Path $dest $s
    if ((Test-Path -LiteralPath $dest) -and ([System.IO.Path]::GetFullPath($dest).TrimEnd('\') -eq [System.IO.Path]::GetFullPath((Join-Path $Repo 'skills')).TrimEnd('\'))) {
        throw "拒绝：安装目标就是技能源目录 $target"
    }
    $existing = Get-Item -LiteralPath $target -Force -ErrorAction SilentlyContinue
    if ($existing -and ($existing.Attributes -band [System.IO.FileAttributes]::ReparsePoint)) {
        if ($Force) { throw "拒绝用 -Force 拆除符号链接：$target（由 skills-manager 管理，请在那边卸载）" }
        Write-Host "  跳过（符号链接）：$target"
        return
    }
    if ($existing -and (-not $Force)) {
        Write-Host "  跳过（已存在）：$target"
        return
    }
    if (-not (Test-Path -LiteralPath $dest)) { New-Item -ItemType Directory -Path $dest -Force | Out-Null }
    $stage = Join-Path $dest ('.skein-' + $s + '-' + [Guid]::NewGuid().ToString('N'))
    try {
        Copy-Item -LiteralPath $source -Destination $stage -Recurse -Force
        if ($existing) { Remove-Item -LiteralPath $target -Recurse -Force }
        Move-Item -LiteralPath $stage -Destination $target
    } finally {
        if (Test-Path -LiteralPath $stage) { Remove-Item -LiteralPath $stage -Recurse -Force }
    }
    Write-Host "  已装：$target"
}

function Install-Globals([string]$dest) { Install-One $dest $GlobalSkill }

function Invoke-Git([string[]]$gitArgs) {
    # 原生命令往 stderr 写东西时，$ErrorActionPreference='Stop' 会把它当异常抛出，
    # 所以这些"失败很正常"的探测统一在这里降级处理，只看退出码。
    $prev = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $out = & git @gitArgs 2>$null
        $code = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $prev
    }
    return [pscustomobject]@{ Output = $out; Code = $code }
}

function Get-ExcludePath([string]$proj) {
    $r = Invoke-Git @('-C',$proj,'rev-parse','--git-path','info/exclude')
    if ($r.Code -ne 0 -or -not $r.Output) { return $null }
    $ex = ($r.Output | Select-Object -First 1).Trim()
    if ($ex -match '^[A-Za-z]:/' -or $ex.StartsWith('/')) { return $ex }
    return (Join-Path $proj $ex)
}

function Add-ExcludeLine([string]$ex, [string]$line) {
    $prev = ''
    if (Test-Path -LiteralPath $ex) { $prev = [System.IO.File]::ReadAllText($ex) }
    $lines = @($prev -split "`r?`n")
    if ($lines -contains $line) { return }
    $sep = ''
    if ($prev.Length -gt 0 -and -not $prev.EndsWith("`n")) { $sep = "`n" }
    Write-Utf8NoBom $ex ($prev + $sep + $line + "`n")
}

function Install-ProjectSkills([string]$proj, [string]$clientDir) {
    $dest = Join-Path $proj "$clientDir\skills"
    foreach ($s in $ProjectSkills) { Install-One $dest $s }
    $ex = Get-ExcludePath $proj
    if ($ex) {
        $infoDir = Split-Path -Parent $ex
        if (-not (Test-Path -LiteralPath $infoDir)) { New-Item -ItemType Directory -Path $infoDir -Force | Out-Null }
        foreach ($s in $ProjectSkills) { Add-ExcludeLine $ex "/$clientDir/skills/$s/" }
    }
}

Write-Host "== 1/2 安装全局技能（只有 $GlobalSkill）=="
$home_ = $env:USERPROFILE
switch ($Client) {
    'claude'    { Install-Globals (Join-Path $home_ '.claude\skills') }
    'codex'     { Install-Globals (Join-Path $home_ '.codex\skills') }
    'workbuddy' { Install-Globals (Join-Path $home_ '.workbuddy\skills') }
    'all' {
        Install-Globals (Join-Path $home_ '.claude\skills')
        Install-Globals (Join-Path $home_ '.codex\skills')
        Install-Globals (Join-Path $home_ '.workbuddy\skills')
    }
    'custom' {
        if (-not $Dir) { throw '-Client custom 必须同时给 -Dir' }
        Install-Globals $Dir
    }
}

if (-not $Project) {
    Write-Host ""
    Write-Host "全局技能装好了。要做项目部署，再加 -Project <项目路径> 重跑。"
    exit 0
}

Write-Host ""
Write-Host "== 2/2 部署到项目 =="
if (-not (Test-Path -LiteralPath $Project)) { throw "项目目录不存在：$Project" }
$Proj = (Resolve-Path -LiteralPath $Project).Path
$Name = Split-Path $Proj -Leaf

if ($Data) { $Root = $Data } else { $Root = Join-Path $home_ 'skein-data' }
if (-not (Test-Path -LiteralPath $Root)) { New-Item -ItemType Directory -Path $Root -Force | Out-Null }
$Root = (Resolve-Path -LiteralPath $Root).Path
$D = Join-Path $Root $Name

# 私有数据不许落在代码仓里
$topR = Invoke-Git @('-C',$Proj,'rev-parse','--show-toplevel')
if ($topR.Code -eq 0 -and $topR.Output) {
    $top = (Resolve-Path -LiteralPath ($topR.Output | Select-Object -First 1).Trim()).Path
    $rootCmp = $Root.TrimEnd('\')
    if ($rootCmp.StartsWith($top.TrimEnd('\') + '\', [StringComparison]::OrdinalIgnoreCase)) {
        throw "拒绝：数据家 $Root 在代码仓 $top 里面。私有知识库会被提交，可能被推送出去。换一个仓外的位置，例如 -Data ""$home_\skein-data"""
    }
}

# 同名项目：已有路由指向别处时停下
$Local = Join-Path $Proj 'AGENTS.local.md'
if (Test-Path -LiteralPath $Local) {
    $old = Select-String -LiteralPath $Local -Pattern '^store:\s*(.+)$' -Encoding UTF8 | Select-Object -First 1
    if ($old) {
        $oldStore = $old.Matches[0].Groups[1].Value.Trim()
        $newStore = "$(To-Fwd $D)/store"
        if ($oldStore -and $oldStore -ne $newStore) {
            throw "拒绝：$Local 里 store 指向 $oldStore，与本次算出的 $newStore 不一致。两个叫 $Name 的项目不能共用一份数据。换 -Data，或手工改 AGENTS.local.md 后再跑。"
        }
    }
}

# 数据目录已经装着别的项目，而当前项目没有路由
if ((Test-Path -LiteralPath (Join-Path $D 'kb\INDEX.md')) -and (-not (Test-Path -LiteralPath $Local))) {
    throw "拒绝：$D 已经有知识库，但 $Proj 没有 AGENTS.local.md。若是同一个项目，把路由文件找回来再跑；否则换一个 -Data。"
}

# 已被 git 跟踪的路由文件，忽略规则救不回来
$tracked = Invoke-Git @('-C',$Proj,'ls-files','--error-unmatch','AGENTS.local.md')
if ($tracked.Code -eq 0) {
    throw "拒绝：AGENTS.local.md 已被 git 跟踪，忽略规则对它无效，本机路径会随提交推出去。确认不提交后执行：git -C `"$(To-Fwd $Proj)`" rm --cached AGENTS.local.md"
}

# 既有知识库如果配了远程，就不是私有离线库
$KbPath = Join-Path $D 'kb'
if (Test-Path -LiteralPath (Join-Path $KbPath '.git')) {
    $remoteR = Invoke-Git @('-C',$KbPath,'remote')
    $remotes = @($remoteR.Output | Where-Object { $_ })
    if ($remoteR.Code -eq 0 -and $remotes.Count -gt 0) {
        throw "拒绝：$KbPath 已经配置了远程，私有库不该有远程。先人工核对。"
    }
}

foreach ($p in @('store','checkpoints','backups')) {    $full = Join-Path $D $p
    if (-not (Test-Path -LiteralPath $full)) { New-Item -ItemType Directory -Path $full -Force | Out-Null }
}
foreach ($p in @('facts','decisions','runbooks','journal','proposals','archive')) {
    $full = Join-Path $D "kb\$p"
    if (-not (Test-Path -LiteralPath $full)) { New-Item -ItemType Directory -Path $full -Force | Out-Null }
}
Write-Host "  数据目录：$(To-Fwd $D)"

if (Test-Path -LiteralPath $Local) {
    Write-Host "  AGENTS.local.md 已存在，保留不动"
} else {
    $tpl = Get-Content -LiteralPath (Join-Path $Repo 'templates\AGENTS.local.md') -Raw -Encoding UTF8
    $tpl = $tpl.Replace('{{PROJECT}}', $Name).Replace('{{DATA}}', (To-Fwd $D)).Replace('{{WORKTREE_ROOT}}', (To-Fwd $Root))
    Write-Utf8NoBom $Local $tpl
    Write-Host "  已生成：AGENTS.local.md"
}

$ex = Get-ExcludePath $Proj
if ($ex) {
    $infoDir = Split-Path -Parent $ex
    if (-not (Test-Path -LiteralPath $infoDir)) { New-Item -ItemType Directory -Path $infoDir -Force | Out-Null }
    Add-ExcludeLine $ex '/AGENTS.local.md'
    Write-Host "  已加入 .git/info/exclude"
} else {
    Write-Host "  提示：这个目录还不是 git 仓，AGENTS.local.md 暂时无处排除；git init 后重跑本脚本即可"
}

# 项目级三个技能：只在项目里出现，并在本机忽略（想提交进仓库就删掉那三行）
switch ($Client) {
    'all' {
        Install-ProjectSkills $Proj '.claude'
        Install-ProjectSkills $Proj '.codex'
        Install-ProjectSkills $Proj '.workbuddy'
    }
    'claude'    { Install-ProjectSkills $Proj '.claude' }
    'codex'     { Install-ProjectSkills $Proj '.codex' }
    'workbuddy' { Install-ProjectSkills $Proj '.workbuddy' }
    'custom'    { Write-Host "  -Client custom：项目级三个技能请自行放到客户端能扫到的项目目录" }
}

# 知识库：独立仓、无远程。只建空骨架，内容由 project-memory 接手
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
    git -C $Kb -c core.autocrlf=false -c user.name=skein -c user.email=skein@local commit -q -m "kb: 初始化骨架"
    if ($LASTEXITCODE -eq 0) { Write-Host "  知识库已提交（空骨架，内容整理交给 project-memory）" }
}

$Store = Join-Path $D 'store'
$bd = Get-Command bd -ErrorAction SilentlyContinue
if (Test-Path -LiteralPath (Join-Path $Store '.beads')) {
    Write-Host "  任务库已存在，跳过 init"
} elseif ($bd) {
    Push-Location $Store
    $prevEap = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        # 直接调用，不经 cmd 拼接参数；bd 在非 git 目录的警告走 stderr，不影响退出码
        & bd init --prefix $Prefix --non-interactive --stealth --skip-agents 2>&1 | Out-Null
        $rc = $LASTEXITCODE
    }
    finally {
        $ErrorActionPreference = $prevEap
        Pop-Location
    }
    if ($rc -eq 0) {
        Write-Host "  任务库已初始化（前缀 $Prefix）"
    } else {
        Write-Host "  任务库初始化失败（退出码 $rc）。可手动重试：cd `"$(To-Fwd $Store)`" ; bd init --prefix $Prefix --non-interactive --stealth --skip-agents"
    }
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
Write-Host "装了什么："
Write-Host "  全局         $GlobalSkill"
Write-Host "  项目级       $($ProjectSkills -join ' / ')"
Write-Host "  数据目录     $(To-Fwd $D)\{store,checkpoints,kb,backups}"
Write-Host ""
Write-Host "默认是复制，改本仓库的 skills\ 不会自动生效。想让改动即时生效，"
Write-Host "用 skills-manager 部署（它建符号链接），见 README「4.1 档一」。"
