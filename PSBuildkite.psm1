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
    $uri = [Uri]::new([Uri]::new('https://api.buildkite.com/v2/'), $Path)
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
    $query = [Web.HttpUtility]::ParseQueryString($uri.Query)
    $query['page'] = $Page
    $query['per_page'] = $PerPage
    $uri = [Uri]::new($uri, '?' + $query.ToString())
    if ($Method -eq [WebRequestMethod]::Get -or $PSCmdlet.ShouldProcess("Invoke", "Invoke Buildkite API request?", "API request")) {
        Invoke-RestMethod `
            -Method $Method `
            -Uri $uri `
            -Header $header `
            -ContentType 'application/json' `
            -Body $Body
    }
}

function Get-BuildkiteBuild {
    [CmdletBinding()]
    param(
        [string] $Organization,
        [string] $Pipeline,
        [string] $Branch,
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
    $query = @{}
    if ($Branch) {
        $query['branch'] = $Branch
    }
    Invoke-BuildkiteAPIRequest $path -Body $query -Token $Token -Page $Page -PerPage $PerPage
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

# $organizationCompleter = {
#     [CmdletBinding()]
#     param([string]$commandName, [string]$parameterName, [string]$wordToComplete, [CommandAst]$commandAst, [Hashtable]$fakeBoundParameter)
#     $params = @{}
#     $params.Remove('Slug') | Out-Null
#     $params.Remove('Organization') | Out-Null
#     try {
#         Get-BuildkiteOrganization @params |
#             ForEach-Object { $_.Name } |
#             Where-Object { $_ -like "$wordToComplete*" } |
#             ForEach-Object { [CompletionResult]::new($_, $_, [CompletionResultType]::ParameterValue, $_) }
#     } catch {
#         $_ | Write-Verbose
#     }
# }

# $pipelineCompleter = {
#     [CmdletBinding()]
#     param([string]$commandName, [string]$parameterName, [string]$wordToComplete, [CommandAst]$commandAst, [Hashtable]$fakeBoundParameter)

#     if (-not $fakeBoundParameter.ContainsKey('Organization')) {
#         return
#     }

#     Get-BuildkitePipeline -Organization $fakeBoundParameter['Organization'] -Token $fakeBoundParameter['Token'] |
#         ForEach-Object { $_.Name } |
#         Where-Object { $_ -like "$wordToComplete*" } |
#         ForEach-Object { [CompletionResult]::new($_, $_, [CompletionResultType]::ParameterValue, $_) }
# }

# Register-ArgumentCompleter -CommandName Get-BuildkiteOrganization -ParameterName Slug -ScriptBlock $organizationCompleter
# Register-ArgumentCompleter -CommandName Get-BuildkitePipeline -ParameterName Organization -ScriptBlock $organizationCompleter
# Register-ArgumentCompleter -CommandName Get-BuildkitePipeline -ParameterName Pipeline -ScriptBlock $pipelineCompleter
# Register-ArgumentCompleter -CommandName Get-BuildkiteCruiseControlFeedUrl -ParameterName Pipeline -ScriptBlock $pipelineCompleter
# Register-ArgumentCompleter -CommandName Get-BuildkiteCruiseControlFeedUrl -ParameterName Organization -ScriptBlock $organizationCompleter
# Register-ArgumentCompleter -CommandName Get-BuildkiteBuild -ParameterName Organization -ScriptBlock $organizationCompleter
# Register-ArgumentCompleter -CommandName Get-BuildkiteBuild -ParameterName Pipeline -ScriptBlock $pipelineCompleter
