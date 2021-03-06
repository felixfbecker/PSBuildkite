# Buildkite for PowerShell <img src="./buildkite-logo.svg" height="90" align="left">

[![powershellgallery](https://img.shields.io/powershellgallery/v/PSBuildkite.svg)](https://www.powershellgallery.com/packages/PSBuildkite)
[![downloads](https://img.shields.io/powershellgallery/dt/PSBuildkite.svg)](https://www.powershellgallery.com/packages/PSBuildkite)

Module to interact with the [Buildkite API](https://buildkite.com/docs/apis/rest-api) from PowerShell.

## Example

```powershell
# Show logs of all jobs of the latest build
(Get-BuildkiteBuild -PerPage 1).jobs | Get-BuildkiteJobLog
```

## Installation

```powershell
Install-Module PSBuildkite
```

## Included

- `Get-BuildkiteOrganization`
- `Get-BuildkitePipeline`
- `Get-BuildkiteBuild`
- `Get-BuildkiteJobLog`
- `Get-BuildkiteCruiseControlFeedUrl`

Missing something? PRs welcome!

## Pagination

Pagination will always happen automatically, i.e. `Get-` cmdlet will follow `next` relation links and stream objects till the end of the list is reached.
In the case of builds, this can be virtually forever - you can stop after n objects were found by using `Select-Object -First $n`, or manually with <kbd>CTRL</kbd>+<kbd>C</kbd>.
Pagination can also be controlled manually with the `-Page` and `-PerPage` parameters.
`-Page` can be used to skip entries, while `-PerPage` can be used to fine-tune performance.

## Authentication

To access private repositories, make changes and have a higher rate limit, [create a Buildkite API token](https://buildkite.com/user/api-access-tokens).
This token can be provided to all PSGitHub functions as a `SecureString` through the `-Token` parameter.
You can set a default token to be used by changing `$PSDefaultParameterValues` in your `profile.ps1`:

### On Windows

```powershell
$PSDefaultParameterValues['*Buildkite*:Token'] = 'YOUR_ENCRYPTED_TOKEN' | ConvertTo-SecureString
```

To get the value for `YOUR_ENCRYPTED_TOKEN`, run `Read-Host -AsSecureString | ConvertFrom-SecureString` once and paste in your token.

### On macOS/Linux

macOS and Linux do not have access to the Windows Data Protection API, so they cannot use `ConvertFrom-SecureString`
to generate an encrypted plaintext version of the token without a custom encryption key.

If you are not concerned about storing the token in plain text in the `profile.ps1`, you can set it like this:

```powershell
$PSDefaultParameterValues['*Buildkite*:Token'] = 'YOUR_PLAINTEXT_TOKEN' | ConvertTo-SecureString -AsPlainText -Force
```

Alternatively, you could store the token in a password manager or the Keychain, then retrieve it in your profile and set it the same way.
