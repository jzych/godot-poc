param(
    [string]$ProjectKey = "",
    [string]$Branch = "",
    [string]$OutputPath = "",
    [string]$SonarBaseUrl = "https://sonarcloud.io"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Get-RepositoryRoot {
    return (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
}

function Resolve-ProjectKey {
    param(
        [string]$RepoRoot,
        [string]$ProvidedProjectKey
    )

    if (-not [string]::IsNullOrWhiteSpace($ProvidedProjectKey)) {
        return $ProvidedProjectKey
    }

    $candidateFiles = @()

    $sonarPropertiesPath = Join-Path $RepoRoot "sonar-project.properties"
    if (Test-Path $sonarPropertiesPath) {
        $candidateFiles += $sonarPropertiesPath
    }

    $workflowDirectory = Join-Path $RepoRoot ".github\workflows"
    if (Test-Path $workflowDirectory) {
        $candidateFiles += Get-ChildItem -Path $workflowDirectory -File | Where-Object { $_.Extension -in ".yml", ".yaml" } | ForEach-Object { $_.FullName }
    }

    foreach ($candidateFile in $candidateFiles) {
        $match = Select-String -Path $candidateFile -Pattern "sonar\.projectKey=([A-Za-z0-9._:-]+)" | Select-Object -First 1
        if ($null -ne $match) {
            return $match.Matches[0].Groups[1].Value
        }
    }

    throw "Unable to resolve the Sonar project key. Pass -ProjectKey or add sonar.projectKey to local Sonar config."
}

function Invoke-SonarApi {
    param([string]$Url)

    $curlArguments = @("-fsSL")
    if (-not [string]::IsNullOrWhiteSpace($env:SONAR_TOKEN)) {
        $curlArguments += @("-H", "Authorization: Bearer $($env:SONAR_TOKEN)")
    }

    $curlArguments += $Url

    $response = & curl.exe @curlArguments
    if ($LASTEXITCODE -ne 0) {
        throw "curl.exe failed for $Url"
    }

    return $response
}

function Get-SonarIssues {
    param([string]$BaseUrl)

    $pageSize = 500
    $page = 1
    $allIssues = @()

    do {
        $separator = "?"
        if ($BaseUrl.Contains("?")) {
            $separator = "&"
        }

        $pageUrl = "{0}{1}ps={2}&p={3}" -f $BaseUrl, $separator, $pageSize, $page
        $response = Invoke-SonarApi -Url $pageUrl | ConvertFrom-Json
        $issuesPage = @($response.issues)
        $allIssues += $issuesPage
        $page++
    } while ($allIssues.Count -lt $response.paging.total)

    return $allIssues
}

function Get-OptionalValue {
    param($Value)

    if ($null -eq $Value -or [string]::IsNullOrWhiteSpace([string]$Value)) {
        return "(n/a)"
    }

    return [string]$Value
}

$repositoryRoot = Get-RepositoryRoot
$resolvedBranch = $Branch
if ([string]::IsNullOrWhiteSpace($resolvedBranch)) {
    $resolvedBranch = (git -C $repositoryRoot branch --show-current).Trim()
}

if ([string]::IsNullOrWhiteSpace($resolvedBranch)) {
    throw "Unable to resolve the current Git branch. Pass -Branch explicitly."
}

$resolvedOutputPath = $OutputPath
if ([string]::IsNullOrWhiteSpace($resolvedOutputPath)) {
    $resolvedOutputPath = Join-Path $repositoryRoot "sonar-findings.md"
}

$resolvedProjectKey = Resolve-ProjectKey -RepoRoot $repositoryRoot -ProvidedProjectKey $ProjectKey
$escapedProjectKey = [System.Uri]::EscapeDataString($resolvedProjectKey)
$pullRequestListUrl = "$SonarBaseUrl/api/project_pull_requests/list?project=$escapedProjectKey"
$pullRequestList = (Invoke-SonarApi -Url $pullRequestListUrl | ConvertFrom-Json).pullRequests
$matchingPullRequest = $pullRequestList | Where-Object { $_.branch -eq $resolvedBranch } | Select-Object -First 1

if ($null -ne $matchingPullRequest) {
    $analysisTargetLabel = "Pull Request"
    $analysisTargetValue = [string]$matchingPullRequest.key
    $issuesUrl = "$SonarBaseUrl/api/issues/search?componentKeys=$escapedProjectKey&pullRequest=$($matchingPullRequest.key)&resolved=false"
}
else {
    $analysisTargetLabel = "Branch"
    $analysisTargetValue = $resolvedBranch
    $escapedBranch = [System.Uri]::EscapeDataString($resolvedBranch)
    $issuesUrl = "$SonarBaseUrl/api/issues/search?componentKeys=$escapedProjectKey&branch=$escapedBranch&resolved=false"
}

$issues = @(Get-SonarIssues -BaseUrl $issuesUrl)

$markdownLines = @(
    "# SonarCloud Findings",
    "",
    "Project: $resolvedProjectKey",
    "{0}: {1}" -f $analysisTargetLabel, $analysisTargetValue
)

if ($analysisTargetLabel -ne "Branch") {
    $markdownLines += "Branch: $resolvedBranch"
}

$markdownLines += @(
    "Generated: $(Get-Date -Format s)",
    "Total issues: $($issues.Count)",
    ""
)

if ($issues.Count -eq 0) {
    $markdownLines += "No open SonarCloud issues were found for this target."
    $markdownLines += ""
}
else {
    foreach ($issue in $issues) {
        $markdownLines += "## [$($issue.severity)] $($issue.rule)"
        $markdownLines += "- File: $(Get-OptionalValue $issue.component)"
        $markdownLines += "- Line: $(Get-OptionalValue $issue.line)"
        $markdownLines += "- Message: $(Get-OptionalValue $issue.message)"
        $markdownLines += "- Type: $(Get-OptionalValue $issue.type)"
        $markdownLines += "- Status: $(Get-OptionalValue $issue.status)"
        $markdownLines += "- Issue key: $(Get-OptionalValue $issue.key)"
        $markdownLines += ""
    }
}

$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllLines($resolvedOutputPath, $markdownLines, $utf8NoBom)
Write-Output "Wrote $resolvedOutputPath with $($issues.Count) issues for $analysisTargetLabel $analysisTargetValue."
