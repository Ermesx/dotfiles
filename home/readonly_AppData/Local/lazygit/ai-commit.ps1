<#
.SYNOPSIS
    Suggests Conventional Commit messages for the staged changes, one per line.

.DESCRIPTION
    Pipes a prompt plus the staged diff (lockfiles and generated files skipped, size capped) to the Claude Code CLI
    and prints the valid candidates to stdout. Called by the lazygit <c-a> custom command, but runs standalone:

        git add -p; pwsh -NoProfile -File ai-commit.ps1 -Type feat

.PARAMETER Type
    Conventional Commit type forced on every candidate, or 'ai-defined' to let the model choose per candidate.

.PARAMETER Count
    How many candidates to ask for.

.PARAMETER Model
    Model alias or id passed to `claude --model`.

.PARAMETER MaxDiffChars
    Staged diff is cut at this many characters before it is sent.

.PARAMETER DryRun
    Print the prompt that would be sent instead of calling Claude.
#>
[CmdletBinding()]
param(
    [ValidateSet('ai-defined', 'build', 'chore', 'ci', 'docs', 'feat', 'fix', 'perf', 'refactor', 'revert', 'style', 'test')]
    [string]$Type = 'ai-defined',
    [ValidateRange(1, 20)]
    [int]$Count = 8,
    [string]$Model = 'haiku',
    [ValidateRange(1, 2147483647)]
    [int]$MaxDiffChars = 20000,
    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'
# Empty-string native arguments (--tools '') are dropped under the legacy mode (default before pwsh 7.3).
$PSNativeCommandArgumentPassing = 'Standard'
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)

# Generated or low-signal files: the model gains nothing from their diff, and they dominate its size.
$exclude = @(
    '*.lock', '*lock.json', '*lock.yaml', '*.lockb', 'go.sum', '*.min.js', '*.min.css', '*.map', '*.snap'
) | ForEach-Object { ":(exclude,glob)**/$_" }

$staged = git diff --cached --name-only
if (-not $staged) {
    [Console]::Error.WriteLine('No staged changes. Stage something first.')
    exit 1
}

$stat = (git diff --cached --stat=120 -- .) -join "`n"
$diff = (git diff --cached -- . $exclude) -join "`n"
# Only generated files staged: say so instead of sending an empty section (or the diff we just filtered out).
if (-not $diff.Trim()) { $diff = '(omitted: only lockfiles or generated files are staged; infer the change from the file list)' }
if ($diff.Length -gt $MaxDiffChars) {
    $diff = $diff.Substring(0, $MaxDiffChars) + "`n[diff truncated at $MaxDiffChars characters]"
}
$previousCommits = (git log --pretty=%s -10 2>$null) -join "`n"

$typeRule = if ($Type -eq 'ai-defined') {
    'Choose the most suitable type for each message; different messages may use different types.'
} else {
    "Every message must use the type '$Type'."
}

$prompt = @"
You write Git commit messages in the Conventional Commits format. Reply with exactly $Count different candidate
messages for the staged changes below, one per line, and nothing else: no numbering, bullets, quotes, markdown or
explanations.

Format: <type>(<scope>): <description>
- Types: build, chore, ci, docs, feat, fix, perf, refactor, revert, style, test.
- $typeRule
- Always include a scope naming the affected component or area (for example auth, api, lazygit, packages).
- Use ! after the type/scope only for breaking changes.
- Description: lowercase (except proper nouns), imperative mood ("add", not "added"), no trailing period, ideally
  under 50 characters, never over 72 for the whole line.
- Describe what the changes do, based on the diff, not just which files changed.

Recent commits, for style and scope naming:
$previousCommits

Staged files (stat):
$stat

Staged diff:
$diff
"@

if ($DryRun) {
    $prompt
    exit 0
}

if (-not (Get-Command claude -ErrorAction SilentlyContinue)) {
    [Console]::Error.WriteLine('claude CLI not found on PATH.')
    exit 1
}

# A plain completion: run from the temp dir (no project CLAUDE.md), without tools, session files, user settings,
# hooks, plugins or MCP servers. Their definitions alone exceed the context window of the small models.
Push-Location $env:TEMP
try {
    $raw = $prompt | claude -p 'Follow the instructions on stdin.' --model $Model --tools '' `
        --no-session-persistence --disable-slash-commands --strict-mcp-config --setting-sources '' --output-format text 2>&1
    if ($LASTEXITCODE -ne 0) {
        [Console]::Error.WriteLine("claude exited with code ${LASTEXITCODE}:`n$($raw -join "`n")")
        exit 1
    }
}
finally {
    Pop-Location
}

$pattern = if ($Type -eq 'ai-defined') { 'build|chore|ci|docs|feat|fix|perf|refactor|revert|style|test' } else { [regex]::Escape($Type) }
$candidates = $raw -split '\r?\n' |
    ForEach-Object { ($_ -replace '^\s*(?:[-*]|\d+[.)])\s*', '').Trim().Trim('`') } |
    Where-Object { $_.Length -le 72 -and $_ -match "^($pattern)\([^)]+\)!?: \S" } |
    Select-Object -Unique -First $Count

if (-not $candidates) {
    [Console]::Error.WriteLine("No valid Conventional Commit message in the reply:`n$raw")
    exit 1
}
$candidates
