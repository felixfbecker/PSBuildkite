using namespace Microsoft.PowerShell.Commands;
using namespace System.Management.Automation;

$DEFAULT_PER_PAGE = 30

function Invoke-BuildkiteAPIRequest {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [WebRequestMethod] $Method = [WebRequestMethod]::Get,

        [Parameter(Mandatory, Position = 0)]
        [string] $Path,

        $Body,
        [string] $Accept,

        [ValidateRange(1, [int]::MaxValue)]
        [int] $Page,
        [ValidateRange(1, 100)]
        [int] $PerPage,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [Security.SecureString] $Token
    )
    $uri = [Uri]::new([Uri]::new('https://api.buildkite.com/v2/'), $Path).ToString()
    $decodedToken = [PSCredential]::new('dummy', $Token).GetNetworkCredential().Password
    $header = @{
        "Authorization" = "Bearer $decodedToken"
        "User-Agent"    = "PowerShell"
    }
    if ($Accept) {
        $header['Accept'] = $Accept
    }
    if ($Method -ne [WebRequestMethod]::Get) {
        $Body = $Body | ConvertTo-Json
    }
    [string[]]$search = @()
    if ($PSBoundParameters.ContainsKey('Page')) {
        $search += "page=$Page"
    }
    if ($PSBoundParameters.ContainsKey('PerPage')) {
        $search += "per_page$PerPage"
    }
    if ($search) {
        if ($uri.Contains('?')) {
            $uri += '&'
        } else {
            $uri += '?'
        }
        $uri += ($search -join '&')
    }
    if ($Method -eq [WebRequestMethod]::Get -or $PSCmdlet.ShouldProcess("Invoke", "Invoke Buildkite API request?", "API request")) {
        Invoke-RestMethod `
            -Method $Method `
            -Uri $uri `
            -Header $header `
            -ContentType 'application/json' `
            -Body $Body `
            -FollowRelLink
    }
}

function Get-BuildkiteBuild {
    [CmdletBinding()]
    param(
        [string] $Organization,
        [string] $Pipeline,
        [string[]] $Branch,

        [ValidateSet('running', 'scheduled', 'passed', 'failed', 'blocked', 'canceled', 'canceling', 'skipped', 'not_run', 'finished')]
        [string[]] $State,

        [int] $Number,

        [ValidateRange(1, [int]::MaxValue)]
        [int] $Page = 1,
        [ValidateRange(1, 100)]
        [int] $PerPage = $DEFAULT_PER_PAGE,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [Security.SecureString] $Token
    )
    $path = if ($Number) {
        "organizations/$Organization/pipelines/$Pipeline/builds/$Number"
    } elseif ($Pipeline -and $Organization) {
        "organizations/$Organization/pipelines/$Pipeline/builds"
    } elseif ($Organization) {
        "organizations/$Organization/builds"
    } else {
        "builds"
    }
    [string[]]$search = @()
    if ($State) {
        $search += ($State | ForEach-Object { "state[]=$_" })
    }
    if ($Branch) {
        $search += ($Branch | ForEach-Object { "branch[]=$_" })
    }
    if ($search) {
        $path += "?" + ($search -join '&')
    }

    Invoke-BuildkiteAPIRequest $path -Token $Token -Page $Page -PerPage $PerPage | ForEach-Object { $_ } | ForEach-Object {
        $_.PSTypeNames.Insert(0, 'PSBuildkite.Build')
        $_
    }
}

function Stop-BuildkiteBuild {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ValueFromPipelineByPropertyName, ParameterSetName = 'Url')]
        [ValidateNotNullOrEmpty()]
        [string] $Url,

        [Parameter(Mandatory, ParameterSetName = 'Params')]
        [string] $Organization,

        [Parameter(Mandatory, ParameterSetName = 'Params')]
        [string] $Pipeline,

        [Parameter(Mandatory, ParameterSetName = 'Params')]
        [int] $Number,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [Security.SecureString] $Token
    )

    process {
        if (-not $Url) {
            $Url = "organizations/$Organization/pipelines/$Pipeline/builds/$Number"
        }
        $Url += "/cancel"
        Invoke-BuildkiteAPIRequest -Method PUT $Url -Token $Token | ForEach-Object {
            $_.PSTypeNames.Insert(0, 'PSBuildkite.Build')
            $_
        }
    }
}

function Restart-BuildkiteBuild {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ValueFromPipelineByPropertyName, ParameterSetName = 'Url')]
        [ValidateNotNullOrEmpty()]
        [string] $Url,

        [Parameter(Mandatory, ParameterSetName = 'Params')]
        [string] $Organization,

        [Parameter(Mandatory, ParameterSetName = 'Params')]
        [string] $Pipeline,

        [Parameter(Mandatory, ParameterSetName = 'Params')]
        [int] $Number,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [Security.SecureString] $Token
    )

    process {
        if (-not $Url) {
            $Url = "organizations/$Organization/pipelines/$Pipeline/builds/$Number"
        }
        $Url += "/rebuild"
        Invoke-BuildkiteAPIRequest -Method PUT $Url -Token $Token | ForEach-Object {
            $_.PSTypeNames.Insert(0, 'PSBuildkite.Build')
            $_
        }
    }
}

function Get-BuildkiteOrganization {
    [CmdletBinding()]
    param(
        [Parameter()]
        [string] $Slug,

        [ValidateRange(1, [int]::MaxValue)]
        [int] $Page = 1,
        [ValidateRange(1, 100)]
        [int] $PerPage = $DEFAULT_PER_PAGE,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [Security.SecureString] $Token
    )
    $path = "organizations"
    if ($Slug) {
        $path += "/$Slug"
    }
    Invoke-BuildkiteAPIRequest $path -Token $Token -Page $Page -PerPage $PerPage
}

function Get-BuildkitePipeline {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $Organization,

        [Parameter()]
        [string] $Slug,

        [ValidateRange(1, [int]::MaxValue)]
        [int] $Page = 1,
        [ValidateRange(1, 100)]
        [int] $PerPage = $DEFAULT_PER_PAGE,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [Security.SecureString] $Token
    )
    $path = "organizations/$Organization/pipelines"
    if ($Slug) {
        $path += "/$Slug"
    }
    Invoke-BuildkiteAPIRequest $path -Token $Token -Page $Page -PerPage $PerPage | ForEach-Object {
        $_.PSObject.TypeNames.Insert(0, 'Buildkite.Pipeline')
        $_
    }
}

function Get-BuildkiteJobLog {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ParameterSetName = 'Explicit')]
        [string] $Organization,

        [Parameter(Mandatory, ParameterSetName = 'Explicit')]
        [string] $Pipeline,

        [Parameter(Mandatory, ParameterSetName = 'Explicit')]
        [int] $Build,

        [Parameter(Mandatory, ParameterSetName = 'Explicit')]
        [string] $JobId,

        [Parameter(Mandatory, ValueFromPipeline, ParameterSetName = 'Job')]
        $Job,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [Security.SecureString] $Token
    )

    process {
        $LogUrl = if ($Job) {
            if ($Job.type -ne 'script') {
                Write-Warning "$($Job.type) job has no logs"
                return
            }
            $Job.log_url
        } else {
            "$Organization/pipelines/$Pipeline/builds/$Build/jobs/$JobId/log"
        }
        Invoke-BuildkiteAPIRequest $LogUrl -Token $Token -Accept 'text/plain'
    }
}

function Get-BuildkiteCruiseControlFeedUrl {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipelineByPropertyName, ParameterSetName = 'explicit')]
        [string] $Organization,

        [Parameter(Mandatory, Position = 1, ValueFromPipelineByPropertyName, ParameterSetName = 'explicit')]
        [Alias('slug')]
        [string] $Pipeline,

        # An alternative way to provide org and pipeline
        [Parameter(ValueFromPipelineByPropertyName, ParameterSetName = 'url')]
        [string] $Url,

        [Parameter()]
        [string] $Branch,

        [Parameter(Mandatory)]
        [securestring] $Token
    )
    if ($Url) {
        $Url -match '/organizations/([^/]+)/pipelines(?:/([^/]+))?' | Out-Null
        $Organization = $Matches[1]
        $Pipeline = $Matches[2]
    }
    $decodedToken = [PSCredential]::new('dummy', $Token).GetNetworkCredential().Password
    $url = "https://cc.buildkite.com/$Organization/$Pipeline.xml?access_token=$decodedToken"
    if ($Branch) {
        $url += "&branch=$Branch"
    }
    $url
}

# Workaround for https://github.com/PowerShell/PowerShell/issues/7735
function Add-DefaultParamterValues([string] $Command, [hashtable] $Parameters) {
    foreach ($entry in $global:PSDefaultParameterValues.GetEnumerator()) {
        $commandPattern, $parameter = $entry.Key.Split(':')
        if ($Command -like $commandPattern) {
            $Parameters.Add($parameter, $entry.Value)
        }
    }
}

$organizationCompleter = {
    [CmdletBinding()]
    param([string]$command, [string]$parameter, [string]$wordToComplete, [CommandAst]$commandAst, [Hashtable]$params)
    Add-DefaultParamterValues -Command $command -Parameters $params
    if (-not $params.ContainsKey('Token')) {
        return
    }
    Get-BuildkiteOrganization -Token $params['Token'] |
        ForEach-Object { $_.Slug } |
        Where-Object { $_ -like "$wordToComplete*" } |
        ForEach-Object { [CompletionResult]::new($_, $_, [CompletionResultType]::ParameterValue, $_) }
}

$pipelineCompleter = {
    [CmdletBinding()]
    param([string]$command, [string]$parameter, [string]$wordToComplete, [CommandAst]$commandAst, [Hashtable]$params)
    Add-DefaultParamterValues -Command $command -Parameters $params
    if (-not $params.ContainsKey('Organization') -or -not $params.ContainsKey('Token')) {
        return
    }

    Get-BuildkitePipeline -Organization $params['Organization'] -Token $params['Token'] |
        ForEach-Object { $_.Slug } |
        Where-Object { $_ -like "$wordToComplete*" } |
        ForEach-Object { [CompletionResult]::new($_, $_, [CompletionResultType]::ParameterValue, $_) }
}

Register-ArgumentCompleter -CommandName Get-BuildkiteOrganization -ParameterName Slug -ScriptBlock $organizationCompleter
Register-ArgumentCompleter -CommandName Get-BuildkitePipeline -ParameterName Organization -ScriptBlock $organizationCompleter
Register-ArgumentCompleter -CommandName Get-BuildkitePipeline -ParameterName Pipeline -ScriptBlock $pipelineCompleter
Register-ArgumentCompleter -CommandName Get-BuildkiteCruiseControlFeedUrl -ParameterName Pipeline -ScriptBlock $pipelineCompleter
Register-ArgumentCompleter -CommandName Get-BuildkiteCruiseControlFeedUrl -ParameterName Organization -ScriptBlock $organizationCompleter
Register-ArgumentCompleter -CommandName Get-BuildkiteBuild -ParameterName Organization -ScriptBlock $organizationCompleter
Register-ArgumentCompleter -CommandName Get-BuildkiteBuild -ParameterName Pipeline -ScriptBlock $pipelineCompleter
Register-ArgumentCompleter -CommandName Get-BuildkiteCruiseControlFeedUrl -ParameterName Organization -ScriptBlock $organizationCompleter
Register-ArgumentCompleter -CommandName Get-BuildkiteCruiseControlFeedUrl -ParameterName Pipeline -ScriptBlock $pipelineCompleter
Register-ArgumentCompleter -CommandName Get-BuildkiteCruiseControlFeedUrl -ParameterName Branch -ScriptBlock {
    [CmdletBinding()]
    param([string]$command, [string]$parameter, [string]$wordToComplete, [CommandAst]$commandAst, [Hashtable]$params)
    Add-DefaultParamterValues -Command $command -Parameters $params
    if (-not $params.ContainsKey('Organization') -or -not $params.ContainsKey('Token')) {
        return
    }

    Get-BuildkitePipeline -Organization $params['Organization'] -Slug $params['Pipeline'] -Token $params['Token'] |
        ForEach-Object { $_.default_branch } |
        Where-Object { $_ -like "$wordToComplete*" } |
        ForEach-Object { [CompletionResult]::new($_, $_, [CompletionResultType]::ParameterValue, $_) }
}
