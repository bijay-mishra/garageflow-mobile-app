<#
.SYNOPSIS
Builds a release GarageFlow bundle with the API address compiled in.

.DESCRIPTION
`AppConfig.apiBaseUrl` is a compile-time constant that defaults to
http://localhost:5100 — right for a phone on a USB tunnel, useless once the app
leaves this desk. On a tester's handset `localhost` means the handset, so every
request fails and the app looks broken.

A plain `flutter build appbundle` picks up that default silently. That is how
the first upload to Play went out pointing at localhost. This script exists so
the address cannot be forgotten: -ApiBaseUrl is mandatory, and the build will
not start without it.

.PARAMETER ApiBaseUrl
Public origin of the API, no trailing slash. E.g. https://api.example.com

.PARAMETER GoogleClientId
Google *Web* OAuth client ID. Leave empty to keep the Google button hidden.

.PARAMETER AllowCleartext
Permit an http:// address. Off by default, because a release build that sends
passwords and bearer tokens in the clear is a decision rather than a typo, and
one worth having to write down.

The host must also appear in android/app/src/main/res/xml/network_security_config.xml
or Android blocks the request whatever this script does.

.PARAMETER Apk
Build an APK for sideloading instead of an App Bundle for Play.

.EXAMPLE
.\tool\build-release.ps1 -ApiBaseUrl https://api.example.com

.EXAMPLE
.\tool\build-release.ps1 -ApiBaseUrl http://202.51.3.68:8013 -AllowCleartext -Apk
#>
param(
    [Parameter(Mandatory = $true)]
    [string]$ApiBaseUrl,

    [string]$GoogleClientId = '',

    [switch]$AllowCleartext,

    [switch]$Apk
)

$ErrorActionPreference = 'Stop'

if ($ApiBaseUrl.EndsWith('/')) {
    $ApiBaseUrl = $ApiBaseUrl.TrimEnd('/')
    Write-Host "Trailing slash removed -> $ApiBaseUrl" -ForegroundColor DarkGray
}

if ($ApiBaseUrl -match 'localhost|127\.0\.0\.1|10\.0\.2\.2|192\.168\.') {
    throw "ApiBaseUrl '$ApiBaseUrl' is a local address. A published build must point at a host the phone can reach."
}

if (-not $ApiBaseUrl.StartsWith('https://')) {
    if (-not $AllowCleartext) {
        # Android blocks cleartext for any host not named in
        # network_security_config.xml, so an http:// address usually fails on
        # the device with what looks like a dead server rather than a refused
        # one. Where it is allowed, it works — and sends every password and
        # bearer token across the network in the clear.
        throw "ApiBaseUrl must be https://, or pass -AllowCleartext to accept an http:// server. Cleartext means credentials and tokens travel unencrypted, and the host must also be listed in android/app/src/main/res/xml/network_security_config.xml."
    }

    $host_ = ([Uri]$ApiBaseUrl).Host
    $nsc = Join-Path $PSScriptRoot '..\android\app\src\main\res\xml\network_security_config.xml'
    if ((Test-Path $nsc) -and -not (Select-String -Path $nsc -SimpleMatch ">$host_<" -Quiet)) {
        # Catches the half-done change: -AllowCleartext given, manifest not
        # updated. The build would succeed and every request would fail.
        throw "'$host_' is not listed in network_security_config.xml, so Android will block the connection. Add it there first."
    }

    Write-Host "CLEARTEXT: $ApiBaseUrl is http. Passwords and tokens will be sent unencrypted." -ForegroundColor Yellow
    Write-Host "Fine for testing. Not fine for a public release - see store/data-safety.md.`n" -ForegroundColor Yellow
}

$defines = @("--dart-define=API_BASE_URL=$ApiBaseUrl")
if ($GoogleClientId) {
    $defines += "--dart-define=GOOGLE_SERVER_CLIENT_ID=$GoogleClientId"
} else {
    Write-Host "No -GoogleClientId: the Google sign-in button stays hidden." -ForegroundColor DarkGray
}

$target = if ($Apk) { 'apk' } else { 'appbundle' }

Write-Host "`nBuilding $target against $ApiBaseUrl`n" -ForegroundColor Cyan
& flutter build $target --release @defines
if ($LASTEXITCODE -ne 0) { throw "flutter build $target failed with exit code $LASTEXITCODE" }

$out = if ($Apk) {
    'build\app\outputs\flutter-apk\app-release.apk'
} else {
    'build\app\outputs\bundle\release\app-release.aab'
}

Write-Host "`nBuilt $out" -ForegroundColor Green
Write-Host "API baked in: $ApiBaseUrl" -ForegroundColor Green
