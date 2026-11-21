<#
Skein 技能安装脚本（Windows PowerShell 5.1 / 7）
用法：
  powershell -ExecutionPolicy Bypass -File install\install.ps1
  powershell -ExecutionPolicy Bypass -File install\install.ps1 -Client all -Project "D:\work\我的工作区"

只装技能，不建库、不碰数据目录。建库由 agent 读 project-memory\references\init.md 完成。

装什么、装到哪：
  全局：只有 task-checkpoint（长任务落盘，所有工作区都要用）
  项目：agent-handoff / project-memory / agent-collab，装到 <项目>\.<客户端>\skills
#>
[CmdletBinding()]
param(
    [ValidateSet('all','claude','codex','workbuddy','custom')]
    [string]$Client = 'all',
    [string]$Dir,
    [string]$Project,
    [switch]$Force
)

$ErrorActionPreference = 'Stop'
$Repo = Split-Path -Parent $PSScriptRoot
$GlobalSkill = 'task-checkpoint'
$ProjectSkills = @('agent-handoff','project-memory','agent-collab')

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

function Install-One([string]$dest, [string]$s) {
    $source = Join-Path $Repo "skills\$s"
    $target = Join-Path $dest $s
    $skillsRoot = Join-Path $Repo 'skills'
    if ((Test-Path -LiteralPath $dest) -and
        ([System.IO.Path]::GetFullPath($dest).TrimEnd('\') -eq [System.IO.Path]::GetFullPath($skillsRoot).TrimEnd('\'))) {
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

function Install-ProjectSkills([string]$proj, [string]$clientDir) {
    $dest = Join-Path $proj "$clientDir\skills"
    foreach ($s in $ProjectSkills) { Install-One $dest $s }
    $r = Invoke-Git @('-C',$proj,'rev-parse','--git-path','info/exclude')
    if ($r.Code -ne 0 -or -not $r.Output) { return }
    $ex = ($r.Output | Select-Object -First 1).Trim()
    if ($ex -notmatch '^[A-Za-z]:/' -and -not $ex.StartsWith('/')) { $ex = Join-Path $proj $ex }
    $infoDir = Split-Path -Parent $ex
    if (-not (Test-Path -LiteralPath $infoDir)) { New-Item -ItemType Directory -Path $infoDir -Force | Out-Null }
    $prev = ''
    if (Test-Path -LiteralPath $ex) { $prev = [System.IO.File]::ReadAllText($ex) }
    $lines = @($prev -split "`r?`n")
    $add = @()
    foreach ($s in $ProjectSkills) {
        $entry = "/$clientDir/skills/$s/"
        if ($lines -notcontains $entry) { $add += $entry }
    }
    if ($add.Count -gt 0) {
        $sep = ''
        if ($prev.Length -gt 0 -and -not $prev.EndsWith("`n")) { $sep = "`n" }
        $enc = New-Object System.Text.UTF8Encoding($false)
        [System.IO.File]::WriteAllText($ex, $prev + $sep + ($add -join "`n") + "`n", $enc)
    }
}

Write-Host "== 安装全局技能（只装 $GlobalSkill）=="
$home_ = $env:USERPROFILE
switch ($Client) {
    'claude'    { Install-One (Join-Path $home_ '.claude\skills') $GlobalSkill }
    'codex'     { Install-One (Join-Path $home_ '.codex\skills') $GlobalSkill }
    'workbuddy' { Install-One (Join-Path $home_ '.workbuddy\skills') $GlobalSkill }
    'all' {
        Install-One (Join-Path $home_ '.claude\skills') $GlobalSkill
        Install-One (Join-Path $home_ '.codex\skills') $GlobalSkill
        Install-One (Join-Path $home_ '.workbuddy\skills') $GlobalSkill
    }
    'custom' {
        if (-not $Dir) { throw '-Client custom 必须同时给 -Dir' }
        Install-One $Dir $GlobalSkill
    }
}

if ($Project) {
    if (-not (Test-Path -LiteralPath $Project)) { throw "项目目录不存在：$Project" }
    $Proj = (Resolve-Path -LiteralPath $Project).Path
    Write-Host ""
    Write-Host "== 安装项目级技能 =="
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
}

Write-Host ""
Write-Host "技能装完了。下一步不是跑脚本，是让 AI 干："
Write-Host ""
Write-Host "  在这个工作区里对它说「用 project-memory 给这个工作区建库」"
Write-Host ""
Write-Host "它会读 references\init.md：写 AGENTS.local.md、建数据目录、初始化知识库并提交。"
Write-Host "建库只做一次，之后所有子项目共用这一套。"
Write-Host ""
Write-Host "重启客户端（多数客户端只在启动时扫描技能目录）。"
