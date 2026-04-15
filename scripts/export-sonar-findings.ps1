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
    param(
        [string]$Url,
        [switch]$AllowNotFound
    )

    $responsePath = [System.IO.Path]::GetTempFileName()
    try {
        $curlArguments = @("-sSL", "-o", $responsePath, "-w", "%{http_code}")
        if (-not [string]::IsNullOrWhiteSpace($env:SONAR_TOKEN)) {
            $curlArguments += @("-H", "Authorization: Bearer $($env:SONAR_TOKEN)")
        }

        $curlArguments += $Url

        $statusCode = (& curl.exe @curlArguments).Trim()
        if ($LASTEXITCODE -ne 0) {
            throw "curl.exe failed for $Url"
        }

        $response = Get-Content -LiteralPath $responsePath -Raw
        if ($statusCode -eq "404" -and $AllowNotFound) {
            return $null
        }

        if ($statusCode -notmatch "^2\d\d$") {
            throw "Sonar API request returned HTTP $statusCode for $Url"
        }

        return $response
    }
    finally {
        if (Test-Path -LiteralPath $responsePath) {
            Remove-Item -LiteralPath $responsePath -Force
        }
    }
}

function Get-AnalysisTarget {
    param(
        [string]$SonarBaseUrl,
        [string]$ProjectKey,
        [string]$BranchName
    )

    $escapedProjectKey = [System.Uri]::EscapeDataString($ProjectKey)
    $pullRequestListUrl = "$SonarBaseUrl/api/project_pull_requests/list?project=$escapedProjectKey"
    $pullRequestList = (Invoke-SonarApi -Url $pullRequestListUrl | ConvertFrom-Json).pullRequests
    $matchingPullRequest = $pullRequestList | Where-Object { $_.branch -eq $BranchName } | Select-Object -First 1

    if ($null -ne $matchingPullRequest) {
        return @{
            Label = "Pull Request"
            Value = [string]$matchingPullRequest.key
            Branch = $BranchName
            QueryParameters = "pullRequest=$([System.Uri]::EscapeDataString([string]$matchingPullRequest.key))"
        }
    }

    return @{
        Label = "Branch"
        Value = $BranchName
        Branch = $BranchName
        QueryParameters = "branch=$([System.Uri]::EscapeDataString($BranchName))"
    }
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
        $responseJson = Invoke-SonarApi -Url $pageUrl -AllowNotFound
        if ($null -eq $responseJson) {
            return @()
        }

        $response = $responseJson | ConvertFrom-Json
        $issuesPage = @($response.issues)
        $allIssues += $issuesPage
        $page++
    } while ($allIssues.Count -lt $response.paging.total)

    return $allIssues
}

function Get-PropertyValue {
    param(
        $Object,
        [string]$PropertyName
    )

    if ($null -eq $Object) {
        return $null
    }

    $property = $Object.PSObject.Properties[$PropertyName]
    if ($null -eq $property) {
        return $null
    }

    return $property.Value
}

function Get-SonarMeasureValue {
    param($Measure)

    if ($null -eq $Measure) {
        return $null
    }

    $directValue = Get-PropertyValue -Object $Measure -PropertyName "value"
    if ($null -ne $directValue -and -not [string]::IsNullOrWhiteSpace([string]$directValue)) {
        return [string]$directValue
    }

    $period = Get-PropertyValue -Object $Measure -PropertyName "period"
    $periodValue = Get-PropertyValue -Object $period -PropertyName "value"
    if ($null -ne $periodValue -and -not [string]::IsNullOrWhiteSpace([string]$periodValue)) {
        return [string]$periodValue
    }

    return $null
}

function Get-SonarMeasures {
    param(
        [string]$SonarBaseUrl,
        [string]$ProjectKey,
        [hashtable]$AnalysisTarget
    )

    $metricKeys = @(
        "alert_status",
        "coverage",
        "new_coverage",
        "bugs",
        "vulnerabilities",
        "code_smells",
        "security_hotspots"
    )

    $measuresUrl = "{0}/api/measures/component?component={1}&metricKeys={2}&{3}" -f `
        $SonarBaseUrl,
        [System.Uri]::EscapeDataString($ProjectKey),
        [System.Uri]::EscapeDataString(($metricKeys -join ",")),
        $AnalysisTarget.QueryParameters

    $responseJson = Invoke-SonarApi -Url $measuresUrl -AllowNotFound
    if ($null -eq $responseJson) {
        return @{}
    }

    $response = $responseJson | ConvertFrom-Json
    $measureLookup = @{}

    foreach ($measure in @($response.component.measures)) {
        $measureLookup[$measure.metric] = Get-SonarMeasureValue -Measure $measure
    }

    return $measureLookup
}

function Get-SonarQualityGate {
    param(
        [string]$SonarBaseUrl,
        [string]$ProjectKey,
        [hashtable]$AnalysisTarget
    )

    $qualityGateUrl = "{0}/api/qualitygates/project_status?projectKey={1}&{2}" -f `
        $SonarBaseUrl,
        [System.Uri]::EscapeDataString($ProjectKey),
        $AnalysisTarget.QueryParameters

    $responseJson = Invoke-SonarApi -Url $qualityGateUrl -AllowNotFound
    if ($null -eq $responseJson) {
        return $null
    }

    return ($responseJson | ConvertFrom-Json).projectStatus
}

function Format-MeasureValue {
    param(
        [hashtable]$Measures,
        [string]$MetricKey
    )

    if (-not $Measures.ContainsKey($MetricKey)) {
        return "(n/a)"
    }

    $value = $Measures[$MetricKey]
    if ([string]::IsNullOrWhiteSpace([string]$value)) {
        return "(n/a)"
    }

    if ($MetricKey -like "*coverage*" -or $MetricKey -eq "duplicated_lines_density") {
        return "$value`%"
    }

    return $value
}

function Get-OptionalValue {
    param($Value)

    if ($null -eq $Value -or [string]::IsNullOrWhiteSpace([string]$Value)) {
        return "(n/a)"
    }

    return [string]$Value
}

function Add-IssueBreakdownLines {
    param(
        [string[]]$MarkdownLines,
        [string]$Heading,
        $Groups
    )

    $sortedGroups = @($Groups | Sort-Object Name)
    if ($sortedGroups.Count -eq 0) {
        return $MarkdownLines
    }

    $MarkdownLines += $Heading
    foreach ($group in $sortedGroups) {
        $MarkdownLines += "- {0}: {1}" -f $group.Name, $group.Count
    }
    $MarkdownLines += ""

    return $MarkdownLines
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
$analysisTarget = Get-AnalysisTarget -SonarBaseUrl $SonarBaseUrl -ProjectKey $resolvedProjectKey -BranchName $resolvedBranch
$analysisTargetLabel = [string]$analysisTarget.Label
$analysisTargetValue = [string]$analysisTarget.Value
$issuesUrl = "{0}/api/issues/search?componentKeys={1}&{2}&resolved=false" -f `
    $SonarBaseUrl,
    [System.Uri]::EscapeDataString($resolvedProjectKey),
    $analysisTarget.QueryParameters

$measures = Get-SonarMeasures -SonarBaseUrl $SonarBaseUrl -ProjectKey $resolvedProjectKey -AnalysisTarget $analysisTarget
$qualityGate = Get-SonarQualityGate -SonarBaseUrl $SonarBaseUrl -ProjectKey $resolvedProjectKey -AnalysisTarget $analysisTarget
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
    "Quality gate: $(Get-OptionalValue (Get-PropertyValue -Object $qualityGate -PropertyName 'status'))",
    "Coverage: $(Format-MeasureValue -Measures $measures -MetricKey 'coverage')",
    "New coverage: $(Format-MeasureValue -Measures $measures -MetricKey 'new_coverage')",
    "Bugs: $(Format-MeasureValue -Measures $measures -MetricKey 'bugs')",
    "Vulnerabilities: $(Format-MeasureValue -Measures $measures -MetricKey 'vulnerabilities')",
    "Code smells: $(Format-MeasureValue -Measures $measures -MetricKey 'code_smells')",
    "Security hotspots: $(Format-MeasureValue -Measures $measures -MetricKey 'security_hotspots')",
    "Total issues: $($issues.Count)",
    ""
)

if ($null -eq $qualityGate -and $measures.Count -eq 0) {
    $markdownLines += "Analysis summary: not available for this target. SonarCloud has not published branch or pull request measures for it yet."
    $markdownLines += ""
}

if ($null -ne $qualityGate -and @($qualityGate.conditions).Count -gt 0) {
    $markdownLines += "## Quality Gate Conditions"
    foreach ($condition in @($qualityGate.conditions) | Sort-Object metricKey) {
        $metricKey = Get-OptionalValue (Get-PropertyValue -Object $condition -PropertyName "metricKey")
        $conditionStatus = Get-OptionalValue (Get-PropertyValue -Object $condition -PropertyName "status")
        $metricValue = Get-OptionalValue (Get-PropertyValue -Object $condition -PropertyName "actualValue")
        $thresholdValue = Get-OptionalValue (Get-PropertyValue -Object $condition -PropertyName "errorThreshold")
        $markdownLines += "- ${metricKey}: ${conditionStatus} (actual: $metricValue, threshold: $thresholdValue)"
    }
    $markdownLines += ""
}

if ($issues.Count -gt 0) {
    $markdownLines = Add-IssueBreakdownLines -MarkdownLines $markdownLines -Heading "## Issue Types" -Groups ($issues | Group-Object type)
    $markdownLines = Add-IssueBreakdownLines -MarkdownLines $markdownLines -Heading "## Issue Severities" -Groups ($issues | Group-Object severity)
}

if ($issues.Count -eq 0) {
    $markdownLines += "No open SonarCloud issues were found for this target."
    $markdownLines += ""
}
else {
    foreach ($issue in $issues) {
        $markdownLines += "## [$(Get-OptionalValue (Get-PropertyValue -Object $issue -PropertyName 'severity'))] $(Get-OptionalValue (Get-PropertyValue -Object $issue -PropertyName 'rule'))"
        $markdownLines += "- File: $(Get-OptionalValue (Get-PropertyValue -Object $issue -PropertyName 'component'))"
        $markdownLines += "- Line: $(Get-OptionalValue (Get-PropertyValue -Object $issue -PropertyName 'line'))"
        $markdownLines += "- Message: $(Get-OptionalValue (Get-PropertyValue -Object $issue -PropertyName 'message'))"
        $markdownLines += "- Type: $(Get-OptionalValue (Get-PropertyValue -Object $issue -PropertyName 'type'))"
        $markdownLines += "- Status: $(Get-OptionalValue (Get-PropertyValue -Object $issue -PropertyName 'status'))"
        $markdownLines += "- Issue key: $(Get-OptionalValue (Get-PropertyValue -Object $issue -PropertyName 'key'))"
        $markdownLines += ""
    }
}

$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllLines($resolvedOutputPath, $markdownLines, $utf8NoBom)
Write-Output "Wrote $resolvedOutputPath with $($issues.Count) issues for $analysisTargetLabel $analysisTargetValue."
