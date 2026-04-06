param(
    [string]$DocRoot = ".\doc",
    [string]$OutputFile
)

Add-Type -AssemblyName System.Web

function Normalize-Whitespace {
    param(
        [string]$Text
    )

    if ($null -eq $Text) {
        $Text = ""
    }

    return ([regex]::Replace($Text, "\s+", " ")).Trim()
}

function Get-RegexGroupValue {
    param(
        [string]$InputText,
        [string]$Pattern
    )

    $match = [regex]::Match(
        $InputText,
        $Pattern,
        [System.Text.RegularExpressions.RegexOptions]::IgnoreCase -bor [System.Text.RegularExpressions.RegexOptions]::Singleline)

    if (-not $match.Success) {
        return ""
    }

    $decodedValue = [System.Web.HttpUtility]::HtmlDecode($match.Groups[1].Value)
    $withoutTags = [regex]::Replace($decodedValue, "<[^>]+>", " ")
    return Normalize-Whitespace $withoutTags
}

function Convert-HtmlToText {
    param(
        [string]$Html
    )

    $text = $Html
    $text = [regex]::Replace($text, "(?is)<!--.*?-->", " ")
    $text = [regex]::Replace($text, "(?is)<script\b.*?</script>", " ")
    $text = [regex]::Replace($text, "(?is)<style\b.*?</style>", " ")
    $text = [regex]::Replace($text, "(?i)<br\s*/?>", " ")
    $text = [regex]::Replace($text, "(?i)</(p|div|h1|h2|h3|h4|h5|h6|li|tr|table|ul|ol|pre|blockquote)>", " ")
    $text = [regex]::Replace($text, "<[^>]+>", " ")
    $text = [System.Web.HttpUtility]::HtmlDecode($text)
    return Normalize-Whitespace $text
}

function Get-DocumentContentHtml {
    param(
        [string]$Html
    )

    $match = [regex]::Match(
        $Html,
        '<div id="content">(.*?)</div>\s*<!-- id="content" -->',
        [System.Text.RegularExpressions.RegexOptions]::IgnoreCase -bor [System.Text.RegularExpressions.RegexOptions]::Singleline)

    if ($match.Success) {
        return $match.Groups[1].Value
    }

    return $Html
}

$resolvedDocRoot = (Resolve-Path $DocRoot).Path

if (-not $OutputFile) {
    $OutputFile = Join-Path $resolvedDocRoot "search-index.js"
}

$entries = Get-ChildItem -Path $resolvedDocRoot -Filter *.html -Recurse |
    Sort-Object FullName |
    ForEach-Object {
        $rawHtml = Get-Content -LiteralPath $_.FullName -Raw
        $contentHtml = Get-DocumentContentHtml -Html $rawHtml
        $relativePath = $_.FullName.Substring($resolvedDocRoot.Length).TrimStart('\') -replace '\\', '/'
        $section = Split-Path $relativePath -Parent

        if ([string]::IsNullOrWhiteSpace($section)) {
            $section = "Overview"
        }

        $pageTitle = Get-RegexGroupValue -InputText $rawHtml -Pattern "<title[^>]*>(.*?)</title>"
        $heading = Get-RegexGroupValue -InputText $contentHtml -Pattern "<h1[^>]*>(.*?)</h1>"
        if ([string]::IsNullOrWhiteSpace($heading)) {
            $heading = Get-RegexGroupValue -InputText $contentHtml -Pattern "<h2[^>]*>(.*?)</h2>"
        }

        $documentText = Convert-HtmlToText -Html $contentHtml

        if ([string]::IsNullOrWhiteSpace($heading)) {
            $heading = [System.IO.Path]::GetFileNameWithoutExtension($_.Name)
        }

        [ordered]@{
            path = $relativePath
            section = $section
            title = $heading
            pageTitle = $pageTitle
            text = $documentText
        }
    }

$json = $entries | ConvertTo-Json -Depth 4 -Compress
$output = "window.TENSearchIndex = $json;"
Set-Content -LiteralPath $OutputFile -Value $output -Encoding UTF8

Write-Host "Search index saved to: $OutputFile"