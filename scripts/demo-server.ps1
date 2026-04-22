param(
    [int]$Port = 8099,
    [string]$WebRoot = ".\web-demo",
    [string]$EnvFile = ".\infra\fastgpt\.env.local",
    [string]$KnowledgeDir = ".\data\import_ready",
    [string]$FaqCsv = ""
)

$ErrorActionPreference = "Stop"

function Get-EnvMap {
    param([string]$Path)

    $map = @{}
    if (-not (Test-Path -LiteralPath $Path)) {
        return $map
    }

    foreach ($rawLine in Get-Content -LiteralPath $Path -ErrorAction Stop) {
        $line = $rawLine.Trim()
        if (-not $line -or $line.StartsWith("#")) {
            continue
        }

        $index = $line.IndexOf("=")
        if ($index -le 0) {
            continue
        }

        $key = $line.Substring(0, $index).Trim()
        $value = $line.Substring($index + 1).Trim()
        $map[$key] = $value
    }

    return $map
}

function Test-IsChineseText {
    param([string]$Text)

    return $Text -match "[\u4e00-\u9fff]"
}

function Test-IsLowQualityAnswer {
    param([string]$Text)

    if (-not $Text) {
        return $true
    }

    $trimmed = $Text.Trim()
    if (-not $trimmed) {
        return $true
    }

    $questionMarks = ([regex]::Matches($trimmed, "[\?？]")).Count
    $cjkChars = ([regex]::Matches($trimmed, "[\u4e00-\u9fff]")).Count
    $latinChars = ([regex]::Matches($trimmed, "[A-Za-z]")).Count

    if ($questionMarks -ge 4 -and ($cjkChars + $latinChars) -le 2) {
        return $true
    }

    if ($trimmed -match "^\s*[\?？\|\-:：/\\]+\s*$") {
        return $true
    }

    return $false
}

function Get-FaqEntries {
    param([string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) {
        return @()
    }

    try {
        return @(Import-Csv -LiteralPath $Path)
    } catch {
        return @()
    }
}

function Resolve-FaqCsvPath {
    param([string]$ConfiguredPath)

    if ($ConfiguredPath -and (Test-Path -LiteralPath $ConfiguredPath)) {
        return (Resolve-Path -LiteralPath $ConfiguredPath).Path
    }

    $candidates = Get-ChildItem -LiteralPath "." -File -Filter "*.csv" -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -match "FAQ|faq" } |
        Sort-Object LastWriteTime -Descending

    if ($candidates) {
        return $candidates[0].FullName
    }

    return $null
}

function Get-KnowledgeRecords {
    param([string]$Root)

    $records = New-Object System.Collections.Generic.List[string]
    if (-not (Test-Path -LiteralPath $Root)) {
        return $records
    }

    $files = Get-ChildItem -LiteralPath $Root -Recurse -File -Filter *.json | Sort-Object FullName
    foreach ($file in $files) {
        try {
            $items = Get-Content -LiteralPath $file.FullName -Raw | ConvertFrom-Json
            foreach ($item in $items) {
                if ($null -eq $item.content) {
                    continue
                }

                $content = $item.content.ToString().Trim()
                if (-not $content) {
                    continue
                }

                if (Test-IsLowQualityAnswer -Text $content) {
                    continue
                }

                $records.Add($content)
            }
        } catch {
            continue
        }
    }

    return $records
}

function Get-BestFaqAnswer {
    param(
        [string]$Question,
        [object[]]$FaqEntries
    )

    if (-not $FaqEntries -or $FaqEntries.Count -eq 0) {
        return $null
    }

    $chars = [regex]::Matches($Question, "[\u4e00-\u9fffA-Za-z0-9]")
    if ($chars.Count -eq 0) {
        return $null
    }

    $best = $null
    $bestScore = 0

    foreach ($entry in $FaqEntries) {
        $haystack = (($entry.question | Out-String) + " " + ($entry.answer | Out-String)).ToLowerInvariant()
        $seen = @{}
        $score = 0

        foreach ($char in $chars) {
            $token = $char.Value.ToLowerInvariant()
            if (-not $token -or $seen.ContainsKey($token)) {
                continue
            }
            $seen[$token] = $true

            if ($haystack.Contains($token)) {
                $score += 1
            }
        }

        if ($score -gt $bestScore) {
            $bestScore = $score
            $best = $entry
        }
    }

    if ($bestScore -lt 2) {
        return $null
    }

    return $best.answer
}

function Get-DemoFacts {
    param(
        [string]$Question,
        [System.Collections.Generic.List[string]]$KnowledgeRecords
    )

    $facts = New-Object System.Collections.Generic.List[string]
    $knowledgeText = ($KnowledgeRecords | Select-Object -First 24) -join "`n"

    if ($Question -match "odor|smell" -or $knowledgeText -match "odor absorption|assist odor absorption") {
        $facts.Add("This material may help with odor absorption in suitable conditions.")
    }
    if ($Question -match "new house|house|home" -or $knowledgeText -match "home and commercial spaces") {
        $facts.Add("It is described as suitable for both home and commercial spaces.")
    }
    if ($Question -match "ventilation|inspection|new house" -or $knowledgeText -match "ventilation and inspection") {
        $facts.Add("For a new house scenario, ventilation and inspection are still recommended.")
    }
    if ($facts.Count -eq 0) {
        $facts.Add("The current demo knowledge is best for product overview, usage scenarios, and lead capture flow.")
    }

    return $facts
}

function Get-FallbackAnswer {
    param(
        [string]$Question,
        [object[]]$FaqEntries,
        [System.Collections.Generic.List[string]]$KnowledgeRecords
    )

    $faqAnswer = Get-BestFaqAnswer -Question $Question -FaqEntries $FaqEntries
    if ($faqAnswer) {
        return $faqAnswer
    }

    $facts = Get-DemoFacts -Question $Question -KnowledgeRecords $KnowledgeRecords
    return "Local demo fallback answer:`n- " + (($facts | Select-Object -First 3) -join "`n- ")
}

function Get-ChatAnswer {
    param(
        [string]$Question,
        [string]$EnvFilePath,
        [object[]]$FaqEntries,
        [System.Collections.Generic.List[string]]$KnowledgeRecords
    )

    $mode = "fallback"
    $answer = $null
    $envMap = Get-EnvMap -Path $EnvFilePath
    $baseUrl = $envMap["OPENAI_BASE_URL"]
    $apiKey = $envMap["CHAT_API_KEY"]
    $knowledge = ($KnowledgeRecords | Select-Object -First 12) -join "`n"

    if ($apiKey -and $baseUrl -and $apiKey -notmatch "__REPLACE_WITH_REAL") {
        try {
            $chatUrl = $baseUrl.TrimEnd("/") + "/chat/completions"
            $payload = @{
                model = "glm-4-flash-250414"
                stream = $false
                temperature = 0.3
                messages = @(
                    @{
                        role = "system"
                        content = "You are a local customer-service demo assistant. Reply in the user's language, stay concise, and use the provided knowledge first. If the knowledge is insufficient, say so clearly and give a safe next step.`nKnowledge:`n$knowledge"
                    },
                    @{
                        role = "user"
                        content = $Question
                    }
                )
            } | ConvertTo-Json -Depth 8

            $response = Invoke-RestMethod -Uri $chatUrl -Method Post -Headers @{
                Authorization = "Bearer $apiKey"
            } -ContentType "application/json" -Body $payload -TimeoutSec 60

            $candidate = $response.choices[0].message.content
            if ($candidate -and $candidate.Trim() -and -not (Test-IsLowQualityAnswer -Text $candidate)) {
                $answer = $candidate
                $mode = "live_model"
            }
        } catch {
            $answer = $null
        }
    }

    if (-not $answer) {
        $answer = Get-FallbackAnswer -Question $Question -FaqEntries $FaqEntries -KnowledgeRecords $KnowledgeRecords
    }

    return @{
        answer = $answer
        mode = $mode
    }
}

function Get-ContentType {
    param([string]$Path)

    switch ([System.IO.Path]::GetExtension($Path).ToLowerInvariant()) {
        ".html" { "text/html; charset=utf-8" }
        ".css" { "text/css; charset=utf-8" }
        ".js" { "application/javascript; charset=utf-8" }
        ".json" { "application/json; charset=utf-8" }
        ".png" { "image/png" }
        ".jpg" { "image/jpeg" }
        ".jpeg" { "image/jpeg" }
        ".svg" { "image/svg+xml" }
        default { "text/plain; charset=utf-8" }
    }
}

function Get-StaticFilePath {
    param(
        [string]$Root,
        [string]$RequestPath
    )

    $relativePath = if ([string]::IsNullOrWhiteSpace($RequestPath) -or $RequestPath -eq "/") {
        "index.html"
    } else {
        $RequestPath.TrimStart("/").Replace("/", "\")
    }

    $fullPath = [System.IO.Path]::GetFullPath((Join-Path $Root $relativePath))
    if (-not $fullPath.StartsWith($Root, [System.StringComparison]::OrdinalIgnoreCase)) {
        return $null
    }
    if (-not (Test-Path -LiteralPath $fullPath -PathType Leaf)) {
        return $null
    }

    return $fullPath
}

function Read-HttpRequest {
    param([System.IO.Stream]$Stream)

    $headerBytes = New-Object System.Collections.Generic.List[byte]
    $matched = 0
    $delimiter = [byte[]](13, 10, 13, 10)

    while ($true) {
        $value = $Stream.ReadByte()
        if ($value -lt 0) {
            break
        }

        $byteValue = [byte]$value
        $headerBytes.Add($byteValue)

        if ($byteValue -eq $delimiter[$matched]) {
            $matched += 1
            if ($matched -eq 4) {
                break
            }
        } else {
            $matched = if ($byteValue -eq $delimiter[0]) { 1 } else { 0 }
        }
    }

    $headerText = [System.Text.Encoding]::ASCII.GetString($headerBytes.ToArray())
    $headerLines = $headerText -split "`r`n"
    $requestLine = $headerLines[0]
    $headers = @{}

    foreach ($line in $headerLines[1..($headerLines.Length - 1)]) {
        if ([string]::IsNullOrWhiteSpace($line)) {
            continue
        }

        $idx = $line.IndexOf(":")
        if ($idx -gt 0) {
            $name = $line.Substring(0, $idx).Trim()
            $value = $line.Substring($idx + 1).Trim()
            $headers[$name] = $value
        }
    }

    $body = ""
    if ($headers.ContainsKey("Content-Length")) {
        $contentLength = [int]$headers["Content-Length"]
        if ($contentLength -gt 0) {
            $buffer = New-Object byte[] $contentLength
            $offset = 0
            while ($offset -lt $contentLength) {
                $read = $Stream.Read($buffer, $offset, $contentLength - $offset)
                if ($read -le 0) {
                    break
                }
                $offset += $read
            }
            $body = [System.Text.Encoding]::UTF8.GetString($buffer, 0, $offset)
        }
    }

    return @{
        RequestLine = $requestLine
        Headers = $headers
        Body = $body
    }
}

function Write-BytesResponse {
    param(
        [System.IO.Stream]$Stream,
        [int]$StatusCode,
        [string]$ContentType,
        [byte[]]$BodyBytes
    )

    $statusText = switch ($StatusCode) {
        200 { "OK" }
        404 { "Not Found" }
        500 { "Internal Server Error" }
        default { "OK" }
    }

    $header = "HTTP/1.1 $StatusCode $statusText`r`n" +
        "Content-Type: $ContentType`r`n" +
        "Content-Length: $($BodyBytes.Length)`r`n" +
        "Connection: close`r`n`r`n"
    $headerBytes = [System.Text.Encoding]::ASCII.GetBytes($header)
    $Stream.Write($headerBytes, 0, $headerBytes.Length)
    $Stream.Write($BodyBytes, 0, $BodyBytes.Length)
    $Stream.Flush()
}

function Write-TextResponse {
    param(
        [System.IO.Stream]$Stream,
        [int]$StatusCode,
        [string]$ContentType,
        [string]$Text
    )

    $bytes = [System.Text.Encoding]::UTF8.GetBytes($Text)
    Write-BytesResponse -Stream $Stream -StatusCode $StatusCode -ContentType $ContentType -BodyBytes $bytes
}

$resolvedWebRoot = (Resolve-Path -LiteralPath $WebRoot).Path
$resolvedEnvFile = (Resolve-Path -LiteralPath $EnvFile).Path
$resolvedKnowledgeDir = Resolve-Path -LiteralPath $KnowledgeDir -ErrorAction SilentlyContinue
$knowledgePath = if ($resolvedKnowledgeDir) { $resolvedKnowledgeDir.Path } else { $KnowledgeDir }
$faqCsvPath = Resolve-FaqCsvPath -ConfiguredPath $FaqCsv
$faqEntries = Get-FaqEntries -Path $faqCsvPath
$knowledgeRecords = Get-KnowledgeRecords -Root $knowledgePath

$listener = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Parse("127.0.0.1"), $Port)
$listener.Start()
Write-Output "Demo server listening at http://127.0.0.1:$Port/"

while ($true) {
    $client = $listener.AcceptTcpClient()

    try {
        $stream = $client.GetStream()
        $request = Read-HttpRequest -Stream $stream
        $requestLine = $request.RequestLine
        if (-not $requestLine) {
            $client.Close()
            continue
        }

        $parts = $requestLine.Split(" ")
        $method = $parts[0]
        $path = $parts[1]

        if ($method -eq "POST" -and $path -eq "/api/ai/chat") {
            $payload = if ($request.Body) { $request.Body | ConvertFrom-Json } else { $null }
            $question = if ($payload -and $payload.question) { [string]$payload.question } else { "" }
            $chat = Get-ChatAnswer -Question $question -EnvFilePath $resolvedEnvFile -FaqEntries $faqEntries -KnowledgeRecords $knowledgeRecords
            $json = $chat | ConvertTo-Json -Depth 5
            Write-TextResponse -Stream $stream -StatusCode 200 -ContentType "application/json; charset=utf-8" -Text $json
            $client.Close()
            continue
        }

        if ($method -eq "POST" -and $path -eq "/api/ai/lead") {
            Write-TextResponse -Stream $stream -StatusCode 200 -ContentType "application/json; charset=utf-8" -Text '{"status":"queued","message":"Lead request queued in local demo mode."}'
            $client.Close()
            continue
        }

        if ($method -eq "POST" -and $path -eq "/api/ai/handoff") {
            Write-TextResponse -Stream $stream -StatusCode 200 -ContentType "application/json; charset=utf-8" -Text '{"status":"queued","message":"Handoff request queued in local demo mode."}'
            $client.Close()
            continue
        }

        $staticFile = Get-StaticFilePath -Root $resolvedWebRoot -RequestPath $path
        if ($null -eq $staticFile) {
            Write-TextResponse -Stream $stream -StatusCode 404 -ContentType "text/plain; charset=utf-8" -Text "Not Found"
            $client.Close()
            continue
        }

        $bytes = [System.IO.File]::ReadAllBytes($staticFile)
        Write-BytesResponse -Stream $stream -StatusCode 200 -ContentType (Get-ContentType -Path $staticFile) -BodyBytes $bytes
        $client.Close()
    } catch {
        try {
            if ($client.Connected) {
                Write-TextResponse -Stream $client.GetStream() -StatusCode 500 -ContentType "text/plain; charset=utf-8" -Text $_.Exception.Message
            }
        } catch {
        }
        $client.Close()
    }
}
