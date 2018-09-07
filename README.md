# Buildkite for PowerShell <img src="https://buildkite.com/_next/static/assets/assets/images/brand-assets/buildkite-logo-portrait-on-light-715fd219.svg" height="90" align="left">

[![powershellgallery](https://img.shields.io/powershellgallery/v/PSBuildkite.svg)](https://www.powershellgallery.com/packages/PSBuildkite)
[![downloads](https://img.shields.io/powershellgallery/dt/PSBuildkite.svg)](https://www.powershellgallery.com/packages/PSBuildkite)

Module to interact with the [Buildkite API](https://buildkite.com/docs/apis/rest-api) from PowerShell.

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
- `Get-BuildkiteJobLogs`
- `Get-BuildkiteCruiseControlFeedUrl`

Missing something? PRs welcome!

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
