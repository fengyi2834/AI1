param(
    [int]$Port = 8099,
    [string]$WebRoot = ".\web-demo",
    [string]$EnvFile = ".\infra\fastgpt\.env.local",
    [string]$KnowledgeDir = ".\data\import_ready",
    [string]$FaqCsv = ".\data\faq\gx_yiku_fastgpt_faq_curated.csv",
    [string]$PromptTemplate = ".\config\fastgpt\prompts\demo_live_system_prompt.md"
)

$ErrorActionPreference = "Stop"
$script:FastGptAnswerCache = @{}

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

function Get-TextFileContent {
    param([string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) {
        return ""
    }

    return Get-Content -LiteralPath $Path -Raw -Encoding UTF8
}

function Get-FastGptCacheKey {
    param([string]$Question)

    if (-not $Question) {
        return ""
    }

    $normalized = (($Question | Out-String).Trim()).ToLowerInvariant() -replace "[\s\p{P}\p{S}]+", ""
    return $normalized
}

function Get-CachedFastGptAnswer {
    param([string]$Question)

    $key = Get-FastGptCacheKey -Question $Question
    if (-not $key) {
        return $null
    }

    if ($script:FastGptAnswerCache.ContainsKey($key)) {
        return $script:FastGptAnswerCache[$key]
    }

    return $null
}

function Set-CachedFastGptAnswer {
    param(
        [string]$Question,
        [string]$Answer
    )

    $key = Get-FastGptCacheKey -Question $Question
    if (-not $key -or -not $Answer) {
        return
    }

    $script:FastGptAnswerCache[$key] = $Answer.Trim()
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

    $questionMarks = ([regex]::Matches($trimmed, "[\?\uFF1F]")).Count
    $cjkChars = ([regex]::Matches($trimmed, "[\u4e00-\u9fff]")).Count
    $latinChars = ([regex]::Matches($trimmed, "[A-Za-z]")).Count

    if ($questionMarks -ge 4 -and ($cjkChars + $latinChars) -le 2) {
        return $true
    }

    if ($trimmed -match "^\s*[\?\uFF1F\|\-:;,.\\/]+\s*$") {
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
        $csvText = Get-Content -LiteralPath $Path -Raw -Encoding UTF8
        return @($csvText | ConvertFrom-Csv)
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

    $files = Get-ChildItem -LiteralPath $Root -Recurse -File |
        Where-Object {
            $_.Extension -in ".json", ".md" -and
            $_.FullName -notmatch "\\smoke(2)?\\"
        } |
        Sort-Object FullName

    foreach ($file in $files) {
        try {
            if ($file.Extension -eq ".json") {
                $items = Get-Content -LiteralPath $file.FullName -Raw -Encoding UTF8 | ConvertFrom-Json
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
                continue
            }

            foreach ($rawLine in Get-Content -LiteralPath $file.FullName -Encoding UTF8) {
                $content = $rawLine.Trim()
                if (-not $content -or $content.StartsWith("#")) {
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

function Get-QuestionTokens {
    param([string]$Text)

    $tokens = New-Object System.Collections.Generic.List[string]
    $seen = @{}
    if (-not $Text) {
        return $tokens
    }

    foreach ($match in [regex]::Matches($Text, "[A-Za-z0-9]{2,}")) {
        $token = $match.Value.ToLowerInvariant()
        if (-not $seen.ContainsKey($token)) {
            $seen[$token] = $true
            $tokens.Add($token)
        }
    }

    foreach ($match in [regex]::Matches($Text, "[\u4e00-\u9fff]+")) {
        $segment = $match.Value
        if ($segment.Length -ge 2) {
            for ($i = 0; $i -le $segment.Length - 2; $i++) {
                $token = $segment.Substring($i, 2)
                if (-not $seen.ContainsKey($token)) {
                    $seen[$token] = $true
                    $tokens.Add($token)
                }
            }
        } elseif (-not $seen.ContainsKey($segment)) {
            $seen[$segment] = $true
            $tokens.Add($segment)
        }
    }

    if ($tokens.Count -gt 0) {
        return $tokens
    }

    foreach ($match in [regex]::Matches($Text, "[\u4e00-\u9fffA-Za-z0-9]")) {
        $token = $match.Value.ToLowerInvariant()
        if (-not $seen.ContainsKey($token)) {
            $seen[$token] = $true
            $tokens.Add($token)
        }
    }

    return $tokens
}

function Get-TextMatchScore {
    param(
        [string]$Question,
        [string]$Candidate
    )

    if (-not $Question -or -not $Candidate) {
        return 0
    }

    $tokens = Get-QuestionTokens -Text $Question
    if ($tokens.Count -eq 0) {
        return 0
    }

    $haystack = $Candidate.ToLowerInvariant()
    $score = 0
    foreach ($token in $tokens) {
        if (-not $haystack.Contains($token)) {
            continue
        }

        if ($token.Length -ge 4 -or $token -match "^[\u4e00-\u9fff]{2,}$") {
            $score += 2
        } else {
            $score += 1
        }
    }

    return $score
}

function Get-BestFaqAnswer {
    param(
        [string]$Question,
        [object[]]$FaqEntries
    )

    if (-not $FaqEntries -or $FaqEntries.Count -eq 0) {
        return $null
    }

    $normalizedQuestion = (($Question | Out-String).Trim()) -replace "[\s\p{P}\p{S}]+", ""
    if ($normalizedQuestion) {
        foreach ($entry in $FaqEntries) {
            $entryQuestion = (($entry.question | Out-String).Trim()) -replace "[\s\p{P}\p{S}]+", ""
            if ($entryQuestion -and $entryQuestion -eq $normalizedQuestion) {
                return $entry.answer
            }
        }
    }

    $best = $null
    $bestScore = 0

    foreach ($entry in $FaqEntries) {
        $questionText = (($entry.question | Out-String).Trim())
        $answerText = (($entry.answer | Out-String).Trim())
        $score = (Get-TextMatchScore -Question $Question -Candidate $questionText) * 3
        $score += Get-TextMatchScore -Question $Question -Candidate $answerText

        if ($score -gt $bestScore) {
            $bestScore = $score
            $best = $entry
        }
    }

    if ($bestScore -lt 3) {
        return $null
    }

    return $best.answer
}

function Test-IsGreetingOrLowIntent {
    param([string]$Question)

    if (-not $Question) {
        return $true
    }

    $trimmed = $Question.Trim()
    if (-not $trimmed) {
        return $true
    }

    if ($trimmed -match "^(你好|您好|哈喽|嗨|在吗|有人吗|hello|hi|你好呀|你好啊|可以聊聊吗|聊聊吗|可以跟你聊聊吗|方便聊聊吗|想了解一下)[!！。,.，\s]*$") {
        return $true
    }

    $domainHint = $trimmed -match "公司|产品|板材|硅藻|新房|装修|入住|除味|异味|甲醛|空气|价格|报价|合作|代理|施工|方案|地址|在哪|哪里|质量|效果"
    $hasQuestion = $trimmed -match "[\?？吗么呢]"
    $isVeryShort = $trimmed.Length -le 6

    if ($isVeryShort -and -not $domainHint -and -not $hasQuestion) {
        return $true
    }

    return $false
}

function Get-ClarifyingAnswer {
    param([string]$Question)

    if (Test-IsGreetingOrLowIntent -Question $Question) {
        return "可以，您直接说您现在最想确认的点就行。比如更关心适不适合新房、会不会有味道、适合哪些空间，还是想了解报价和合作方式？"
    }

    return "我先不乱给您堆资料。您可以直接告诉我现在最想确认的一点，比如新房能不能用、除味表现怎么样、适合什么空间，或者公司和产品情况，我再按这个点给您说清楚。"
}

function Get-ConcernLead {
    param(
        [string]$Question,
        [string]$Answer
    )

    if (-not $Question -or -not $Answer) {
        return $null
    }

    if ($Question -match "新房|装修|入住|家装" -and $Answer -notmatch "顾虑很正常|如果您主要担心") {
        return "如果您主要担心新房入住前的环保和味道，这个顾虑很正常。"
    }

    if ($Question -match "除味|除醛|甲醛|异味|空气" -and $Answer -notmatch "这个问题问得很关键|比较在意异味") {
        return "如果您比较在意异味和空气感受，这个问题问得很关键。"
    }

    if ($Question -match "专利|检测|报告|资质|证书" -and $Answer -notmatch "先看这类依据是对的|靠谱") {
        return "如果您是在确认产品靠不靠谱，先看专利和检测这类依据是对的。"
    }

    if ($Question -match "适合|场景|哪里用|用在哪" -and $Answer -notmatch "先看使用场景会更稳|适不适合自己这个空间") {
        return "如果您是在看适不适合自己这个空间，先确认使用场景会更稳。"
    }

    return $null
}

function Format-CustomerServiceAnswer {
    param(
        [string]$Question,
        [string]$Answer,
        [string]$Mode = ""
    )

    if (-not $Answer) {
        return $Answer
    }

    $trimmed = $Answer.Trim()
    if (-not $trimmed) {
        return $trimmed
    }

    $trimmed = $trimmed -replace "^根据现有资料显示", "就目前资料来看"
    $trimmed = $trimmed -replace "^现有资料显示", "就目前资料来看"
    $trimmed = $trimmed -replace "^资料显示", "就目前资料来看"
    $trimmed = $trimmed -replace "根据现有资料", "就目前资料来看"
    $trimmed = $trimmed -replace "现有资料显示", "就目前资料来看"
    $trimmed = $trimmed -replace "资料显示", "就目前资料来看"
    $trimmed = $trimmed -replace "根据资料", "就目前资料来看"
    $trimmed = $trimmed -replace "因为就目前资料来看产品", "就目前资料来看，这款产品"
    $trimmed = $trimmed -replace "因为就目前资料来看", "因为就目前资料来看，"
    $trimmed = $trimmed -replace "^您好[，,。!！]?\s*", ""
    $trimmed = $trimmed -replace "如果需要具体的证书编号或检测报告原件，建议您转人工咨询，我可以帮您对接。", "如果您需要具体的证书编号或检测报告原件，我可以帮您对接人工继续确认。"
    $trimmed = $trimmed -replace "建议您转人工服务，我们会为您详细提供。", "如果您需要具体的证书编号或检测报告原件，我可以帮您对接人工继续确认。"
    $trimmed = $trimmed -replace "建议您转人工服务", "如果您需要更细的原件或参数，我可以帮您对接人工继续确认"
    $trimmed = $trimmed -replace "如果您需要具体的证书编号或检测报告原件，如果您需要更细的原件或参数，我可以帮您对接人工继续确认获取更详细的信息。", "如果您需要具体的证书编号或检测报告原件，我可以帮您对接人工继续确认。"
    $trimmed = $trimmed -replace "如果您需要具体的证书编号或检测报告原件，如果您需要更细的原件或参数，我可以帮您对接人工继续确认。", "如果您需要具体的证书编号或检测报告原件，我可以帮您对接人工继续确认。"
    $trimmed = $trimmed -replace "^建议转人工提供", "如果您需要更细的原件或参数，我们这边再安排人工继续跟进"
    $trimmed = $trimmed -replace "建议转人工提供", "如果您需要更细的原件或参数，我们这边再安排人工继续跟进"
    $trimmed = $trimmed -replace "建议您转人工咨询", "如果您需要更细的原件或参数，我可以帮您对接人工继续确认"
    $trimmed = $trimmed -replace "建议转人工咨询", "如果您需要更细的原件或参数，我可以帮您对接人工继续确认"
    $trimmed = $trimmed -replace "建议转人工报价", "具体报价这边建议让顾问结合实际需求继续跟进"
    $trimmed = $trimmed -replace "建议转人工", "这类细节更适合让顾问继续跟进"
    $trimmed = $trimmed -replace "我建议您", "您这边可以"

    $lead = Get-ConcernLead -Question $Question -Answer $trimmed
    if ($lead) {
        $trimmed = "$lead$trimmed"
    }

    return $trimmed
}

function New-ChatAnswerResult {
    param(
        [string]$Question,
        [string]$Answer,
        [string]$Mode
    )

    return @{
        answer = Format-CustomerServiceAnswer -Question $Question -Answer $Answer -Mode $Mode
        mode = $Mode
    }
}

function Get-RelevantFacts {
    param(
        [string]$Question,
        [object[]]$FaqEntries,
        [System.Collections.Generic.List[string]]$KnowledgeRecords,
        [int]$MaxFacts = 6
    )

    $ranked = New-Object System.Collections.Generic.List[object]
    $intentPatterns = New-Object System.Collections.Generic.List[string]

    if ($Question -match "介绍|产品|做什么|是什么|核心") {
        $intentPatterns.Add("核心产品|核心功能|适用场景|企业定位|做什么|净化空气|防霉|调湿")
    }
    if ($Question -match "公司|企业|地址|在哪|哪里|成立|注册资金") {
        $intentPatterns.Add("广西亿库光养硅藻环保科技有限公司|位于|北海|海洋产业科技园区|成立于|注册资金|企业定位|主营")
    }
    if ($Question -match "新房|装修|入住|家装") {
        $intentPatterns.Add("新房|入住|适合|通风|检测|无甲醛|无胶水|无油漆|环保性|家装")
    }
    if ($Question -match "除味|除醛|甲醛|异味|空气") {
        $intentPatterns.Add("净化空气|甲醛|除醛|异味|除味|吸附|有害物质|无甲醛|味道大吗")
    }

    foreach ($pattern in $intentPatterns) {
        foreach ($entry in $FaqEntries) {
            $questionText = ($entry.question | Out-String).Trim()
            $answerText = ($entry.answer | Out-String).Trim()
            $fact = "问题：$questionText`n回答：$answerText"
            if ($fact -match $pattern) {
                $ranked.Add([pscustomobject]@{
                    score = 20
                    text = $fact
                })
            }
        }
    }

    foreach ($entry in $FaqEntries) {
        $questionText = ($entry.question | Out-String).Trim()
        $answerText = ($entry.answer | Out-String).Trim()
        if (-not $questionText -or -not $answerText) {
            continue
        }

        $fact = "问题：$questionText`n回答：$answerText"
        $score = Get-TextMatchScore -Question $Question -Candidate $fact
        if ($score -ge 2) {
            $ranked.Add([pscustomobject]@{
                score = $score
                text = $fact
            })
        }
    }

    foreach ($record in $KnowledgeRecords) {
        $score = Get-TextMatchScore -Question $Question -Candidate $record
        if ($score -ge 2) {
            $ranked.Add([pscustomobject]@{
                score = $score
                text = $record
            })
        }
    }

    $facts = New-Object System.Collections.Generic.List[string]
    $seen = @{}
    foreach ($item in $ranked | Sort-Object score -Descending) {
        if ($facts.Count -ge $MaxFacts) {
            break
        }

        if ($seen.ContainsKey($item.text)) {
            continue
        }

        $seen[$item.text] = $true
        $facts.Add($item.text)
    }

    return $facts
}

function Get-BusinessGuardAnswer {
    param([string]$Question)

    if (-not $Question) {
        return $null
    }

    if ($Question -match "代理|经销|加盟|合作") {
        return "合作这类问题可以聊，不过具体政策、报价和推进流程，一般都要结合城市、合作方式和预估规模来确认。您如果方便，可以告诉我们所在城市、想做的合作方向和大概体量，我们再安排顾问按实际情况跟您对接，这样会更准确。"
    }

    if ($Question -match "报价|多少钱|价格|怎么卖") {
        return "价格这块一般不是一个固定口径，要结合产品型号、使用面积、项目场景和所在城市一起看，当前资料里也没有统一公开价。您如果愿意，可以直接告诉我们大概面积、使用场景和所在城市，我们再让顾问按实际需求给您报价。"
    }

    if ($Question -match "合同|施工|工期|勘测|设计方案|定制方案|现场") {
        return "这类问题通常要结合项目现场和具体需求来确认，当前资料里没有固定合同条款或统一施工工期可以直接套用。您可以先说一下项目城市、空间类型和大概需求，我们再安排顾问继续跟进会更稳妥。"
    }

    return $null
}

function Get-CompanyProfileAnswer {
    param([string]$Question)

    if (-not $Question) {
        return $null
    }

    $asksCompany = $Question -match "公司|企业|厂家"
    $asksProduct = $Question -match "产品|板材|做什么|主营"
    $asksEffect = $Question -match "效果|作用|功能"
    $asksQuality = $Question -match "质量|靠不靠谱|行不行|怎么样"
    $asksLocation = $Question -match "在哪|哪里|地址"

    if ($asksCompany -and (($asksProduct -and $asksLocation) -or ($asksEffect -and $asksQuality) -or ($asksProduct -and $asksEffect))) {
        return "您如果是想先整体判断这家公司和产品靠不靠谱，可以先看这几个关键信息。广西亿库光养硅藻环保科技有限公司是一家做环保功能性板材相关业务的企业，主营的是功能性硅藻板，主要面向室内建筑装饰应用。就产品卖点来看，这款板材主打环保、调湿、防霉、净化空气、吸音和隔热，适合家装、办公、学校、病房、宾馆等室内空间。就目前资料来看，它强调无胶水、无油漆、无甲醛，同时具备抗菌防霉、保温隔热和吸音等特点。公司地址资料里显示在广西北海海洋产业科技园区。"
    }

    return $null
}

function Get-GuidedAnswer {
    param(
        [string]$Question,
        [object[]]$FaqEntries
    )

    if ($Question -match "新房|装修|入住|家装") {
        return "这款板材是适合新房和家装场景的。就目前资料来看，它无胶水、无油漆，不含甲醛等挥发性有害物质，安装后基本无明显异味，同时还有净化空气、调湿和防霉这些功能。更稳妥一点的话，新房入住前还是建议配合正常通风和检测一起看。"
    }

    if ($Question -match "除味|除醛|甲醛|异味|空气") {
        return "它可以在一定程度上帮助减轻异味、改善空气环境。就目前资料来看，这款硅藻板可吸附并净化甲醛、苯、甲苯、二甲苯和氨等有害物质，也能帮助减轻烟味、宠物味和厨房异味残留。更稳妥的做法还是配合日常通风一起使用。"
    }

    if ($Question -match "介绍|产品|做什么|是什么") {
        return "这款产品是亿库光养的功能性硅藻板，核心卖点是环保、调湿、防霉、净化空气、隔热和更舒适的室内体验。就目前资料来看，它还具备防水阻燃、降噪吸音、抗菌防霉、保温隔热等特点，适用于家庭装修、办公、学校、病房、宾馆和会所等室内空间。"
    }

    return $null
}

function Test-AnswerNeedsGuidance {
    param(
        [string]$Question,
        [string]$Answer
    )

    if (-not $Answer) {
        return $true
    }

    $trimmed = $Answer.Trim()
    if (-not $trimmed) {
        return $true
    }

    if ($trimmed -match "硅酸钙板|硅藻泥板|广西安吉") {
        return $true
    }

    if ($trimmed -match "您好.*(请问|想了解).*" -or $trimmed -match "请具体说明|我会尽快为您提供帮助") {
        return $true
    }

    if ($Question -match "介绍|产品|做什么|是什么|材料" -and $trimmed -notmatch "硅藻板|功能性|调湿|防霉|净化空气") {
        return $true
    }

    if ($Question -match "新房|装修|入住|家装" -and $trimmed -notmatch "新房|入住|通风|检测|无胶水|无油漆|甲醛|异味") {
        return $true
    }

    if ($Question -match "除味|除醛|甲醛|异味|空气" -and $trimmed -notmatch "甲醛|异味|净化空气|吸附|有害物质|通风") {
        return $true
    }

    return $false
}

function Get-DemoFacts {
    param(
        [string]$Question,
        [System.Collections.Generic.List[string]]$KnowledgeRecords
    )

    $facts = New-Object System.Collections.Generic.List[string]
    $knowledgeText = ($KnowledgeRecords | Select-Object -First 24) -join "`n"

    if ($Question -match "odor|smell" -or $knowledgeText -match "odor absorption|assist odor absorption") {
        $facts.Add("这款材料在合适场景下可以辅助吸附异味。")
    }
    if ($Question -match "new house|house|home" -or $knowledgeText -match "home and commercial spaces") {
        $facts.Add("资料里提到它适用于家庭和商业室内空间。")
    }
    if ($Question -match "ventilation|inspection|new house" -or $knowledgeText -match "ventilation and inspection") {
        $facts.Add("如果是新房场景，仍建议结合正常通风和检测一起判断。")
    }
    if ($facts.Count -eq 0) {
        $facts.Add("当前演示知识更适合回答产品介绍、使用场景和咨询跟进类问题。")
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
    return "我先按当前能确认到的资料给您说几点：`n- " + (($facts | Select-Object -First 3) -join "`n- ")
}

function Get-DemoChatMode {
    param([hashtable]$EnvMap)

    $rawMode = ""
    if ($EnvMap.ContainsKey("DEMO_CHAT_MODE")) {
        $rawMode = (($EnvMap["DEMO_CHAT_MODE"] | Out-String).Trim()).ToLowerInvariant()
    }

    switch ($rawMode) {
        "live_only" { return "live_only" }
        "fallback_only" { return "fallback_only" }
        default { return "auto" }
    }
}

function Get-ChatBackendMode {
    param([hashtable]$EnvMap)

    $rawMode = ""
    if ($EnvMap.ContainsKey("CHAT_BACKEND")) {
        $rawMode = (($EnvMap["CHAT_BACKEND"] | Out-String).Trim()).ToLowerInvariant()
    }

    switch ($rawMode) {
        "fastgpt" { return "fastgpt" }
        "fastgpt_prefer" { return "fastgpt_prefer" }
        "direct" { return "direct" }
        default { return "direct" }
    }
}

function Test-GuidedAnswerEnabled {
    param([hashtable]$EnvMap)

    $rawValue = ""
    if ($EnvMap.ContainsKey("DEMO_GUIDED_ANSWER")) {
        $rawValue = (($EnvMap["DEMO_GUIDED_ANSWER"] | Out-String).Trim()).ToLowerInvariant()
    }

    switch ($rawValue) {
        "off" { return $false }
        "false" { return $false }
        "0" { return $false }
        default { return $true }
    }
}

function Test-IsWeakFastGPTAnswer {
    param(
        [string]$Question,
        [string]$Answer
    )

    if (-not $Answer) {
        return $true
    }

    $trimmed = $Answer.Trim()
    if (-not $trimmed) {
        return $true
    }

    if ($trimmed -match "How can I help you today|Feel free to ask anything|I can help") {
        return $true
    }

    if ($trimmed -match "抱歉.*没有检索到" -or
        $trimmed -match "目前没有检索到" -or
        $trimmed -match "暂无相关信息" -or
        $trimmed -match "无法为您确认" -or
        $trimmed -match "^您好.*暂无" -or
        $trimmed -match "请问您是想了解" -or
        $trimmed -match "请问您是用于" -or
        $trimmed -match "请问您指的是哪种产品" -or
        $trimmed -match "请问您需要了解的是哪个") {
        return $true
    }

    if ($trimmed -match "未找到明确依据" -or $trimmed -match "当前知识库没有足够依据") {
        return $false
    }

    if ($Question -and (Test-AnswerNeedsGuidance -Question $Question -Answer $trimmed) -and $trimmed -match "请问") {
        return $true
    }

    return $false
}

function Invoke-FastGPTAppChat {
    param(
        [string]$Question,
        [hashtable]$EnvMap
    )

    $apiUrl = ""
    if ($EnvMap.ContainsKey("FASTGPT_APP_API_URL")) {
        $apiUrl = (($EnvMap["FASTGPT_APP_API_URL"] | Out-String).Trim())
    }
    if (-not $apiUrl) {
        $apiUrl = "http://127.0.0.1:3100/api/v1/chat/completions"
    }

    $apiKey = ""
    if ($EnvMap.ContainsKey("FASTGPT_APP_API_KEY")) {
        $apiKey = (($EnvMap["FASTGPT_APP_API_KEY"] | Out-String).Trim())
    }
    if (-not $apiKey) {
        return $null
    }

    $payload = @{
        chatId = "demo-" + [guid]::NewGuid().ToString("N").Substring(0, 12)
        stream = $false
        variables = @{}
        messages = @(
            @{
                role = "user"
                content = $Question
            }
        )
    } | ConvertTo-Json -Depth 6

    try {
        $response = Invoke-RestMethod -Uri $apiUrl -Method Post -Headers @{
            Authorization = "Bearer $apiKey"
        } -ContentType "application/json; charset=utf-8" -Body ([System.Text.Encoding]::UTF8.GetBytes($payload)) -TimeoutSec 25

        $answer = $response.choices[0].message.content
        if (Test-IsWeakFastGPTAnswer -Question $Question -Answer $answer) {
            return $null
        }

        return @{
            answer = $answer
            mode = "fastgpt_app"
        }
    } catch {
        return $null
    }
}

function Get-ChatAnswer {
    param(
        [string]$Question,
        [string]$EnvFilePath,
        [object[]]$FaqEntries,
        [System.Collections.Generic.List[string]]$KnowledgeRecords,
        [string]$PromptTemplateText
    )

    $mode = "fallback"
    $answer = $null
    $envMap = Get-EnvMap -Path $EnvFilePath
    $chatBackendMode = Get-ChatBackendMode -EnvMap $envMap
    $fastgptAttempted = $false
    $baseUrl = $envMap["OPENAI_BASE_URL"]
    $apiKey = $envMap["CHAT_API_KEY"]
    $relevantFacts = Get-RelevantFacts -Question $Question -FaqEntries $FaqEntries -KnowledgeRecords $KnowledgeRecords -MaxFacts 6
    $knowledge = if ($relevantFacts.Count -gt 0) {
        ($relevantFacts | ForEach-Object { "- $_" }) -join "`n"
    } else {
        ""
    }
    $systemPrompt = if ($PromptTemplateText) {
        $PromptTemplateText.Replace("{KNOWLEDGE_SNIPPETS}", $(if ($knowledge) { $knowledge } else { "- 当前未检索到足够相关的知识事实，优先追问澄清，不要直接大段介绍产品。" }))
    } else {
        "你是广西亿库光养硅藻环保科技有限公司的官网销售客服顾问。请优先回答用户实际问题，逐项覆盖并保持自然专业，只根据已知资料回答。`n已知事实：`n$knowledge"
    }
    $businessGuardAnswer = Get-BusinessGuardAnswer -Question $Question
    $companyProfileAnswer = Get-CompanyProfileAnswer -Question $Question
    $clarifyingAnswer = if ((Test-IsGreetingOrLowIntent -Question $Question) -or $relevantFacts.Count -eq 0) {
        Get-ClarifyingAnswer -Question $Question
    } else {
        $null
    }
    $guidedAnswerEnabled = Test-GuidedAnswerEnabled -EnvMap $envMap
    $guidedAnswer = if ($guidedAnswerEnabled) {
        Get-GuidedAnswer -Question $Question -FaqEntries $FaqEntries
    } else {
        $null
    }
    $bestFaqAnswer = Get-BestFaqAnswer -Question $Question -FaqEntries $FaqEntries
    $chatMode = Get-DemoChatMode -EnvMap $envMap

    if ($businessGuardAnswer) {
        return New-ChatAnswerResult -Question $Question -Answer $businessGuardAnswer -Mode "business_guard"
    }

    if ($companyProfileAnswer) {
        return New-ChatAnswerResult -Question $Question -Answer $companyProfileAnswer -Mode "company_profile"
    }

    if ($clarifyingAnswer -and -not $guidedAnswer) {
        return New-ChatAnswerResult -Question $Question -Answer $clarifyingAnswer -Mode "clarify"
    }

    if ($guidedAnswer) {
        return New-ChatAnswerResult -Question $Question -Answer $guidedAnswer -Mode "guided_answer"
    }

    if ($chatBackendMode -in @("fastgpt", "fastgpt_prefer")) {
        $cachedFastGptAnswer = Get-CachedFastGptAnswer -Question $Question
        if ($cachedFastGptAnswer) {
            return New-ChatAnswerResult -Question $Question -Answer $cachedFastGptAnswer -Mode "fastgpt_cache"
        }

        $fastgptAttempted = $true
        $fastgptAnswer = Invoke-FastGPTAppChat -Question $Question -EnvMap $envMap
        if ($fastgptAnswer) {
            $formattedFastGptAnswer = Format-CustomerServiceAnswer -Question $Question -Answer $fastgptAnswer.answer -Mode $fastgptAnswer.mode
            Set-CachedFastGptAnswer -Question $Question -Answer $formattedFastGptAnswer
            if ($bestFaqAnswer -and $fastgptAnswer.answer -match "请问您") {
                return New-ChatAnswerResult -Question $Question -Answer $bestFaqAnswer -Mode "faq_override"
            }
            return @{
                answer = $formattedFastGptAnswer
                mode = $fastgptAnswer.mode
            }
        }

        if ($bestFaqAnswer) {
            return New-ChatAnswerResult -Question $Question -Answer $bestFaqAnswer -Mode "faq_override"
        }

        if ($chatBackendMode -eq "fastgpt") {
            return New-ChatAnswerResult -Question $Question -Answer "我这边刚刚没从知识库应用里拿到稳定结果。您可以换一种更具体的问法，比如适不适合新房、会不会有味道、公司在哪里，我再继续帮您确认。" -Mode "fastgpt_unavailable"
        }
    }

    $allowLiveCall = $chatMode -ne "fallback_only"
    $allowFallback = $chatMode -ne "live_only"

    if ($allowLiveCall -and $apiKey -and $baseUrl -and $apiKey -notmatch "__REPLACE_WITH_REAL") {
        try {
            $chatUrl = $baseUrl.TrimEnd("/") + "/chat/completions"
            $payload = @{
                model = "glm-4-flash-250414"
                stream = $false
                temperature = 0.1
                messages = @(
                    @{
                        role = "system"
                        content = $systemPrompt
                    },
                    @{
                        role = "user"
                        content = "客户原话：$Question`n请直接回答，不要空泛寒暄。若用户一句话里问了多个点，请逐项覆盖。只能根据已知事实回答，不要用行业常识补全缺失细节。若资料不足，请明确说目前资料能确认到哪里。`n已知事实：`n$knowledge"
                    }
                )
            } | ConvertTo-Json -Depth 8
            $payloadBytes = [System.Text.Encoding]::UTF8.GetBytes($payload)

            $response = Invoke-RestMethod -Uri $chatUrl -Method Post -Headers @{
                Authorization = "Bearer $apiKey"
            } -ContentType "application/json; charset=utf-8" -Body $payloadBytes -TimeoutSec 60

            $candidate = $response.choices[0].message.content
            if ($candidate -and $candidate.Trim() -and -not (Test-IsLowQualityAnswer -Text $candidate)) {
                $answer = $candidate
                $mode = if ($fastgptAttempted) { "live_model_fallback" } else { "live_model" }
                if ($guidedAnswer -and (Test-AnswerNeedsGuidance -Question $Question -Answer $answer)) {
                    $answer = $guidedAnswer
                    $mode = "guided_answer"
                }
            }
        } catch {
            $answer = $null
        }
    }

    if (-not $answer) {
        if ($allowFallback) {
            $answer = Get-FallbackAnswer -Question $Question -FaqEntries $FaqEntries -KnowledgeRecords $KnowledgeRecords
            $mode = "fallback"
        } else {
            $answer = "当前咨询通道稍忙，您可以稍后再试，或先留下联系方式，我们会尽快与您联系。"
            $mode = "live_unavailable"
        }
    }

    return New-ChatAnswerResult -Question $Question -Answer $answer -Mode $mode
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
$resolvedPromptTemplate = Resolve-Path -LiteralPath $PromptTemplate -ErrorAction SilentlyContinue
$promptTemplateText = if ($resolvedPromptTemplate) {
    Get-TextFileContent -Path $resolvedPromptTemplate.Path
} else {
    ""
}
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
            $chat = Get-ChatAnswer -Question $question -EnvFilePath $resolvedEnvFile -FaqEntries $faqEntries -KnowledgeRecords $knowledgeRecords -PromptTemplateText $promptTemplateText
            $json = $chat | ConvertTo-Json -Depth 5
            Write-TextResponse -Stream $stream -StatusCode 200 -ContentType "application/json; charset=utf-8" -Text $json
            $client.Close()
            continue
        }

        if ($method -eq "POST" -and $path -eq "/api/ai/lead") {
            Write-TextResponse -Stream $stream -StatusCode 200 -ContentType "application/json; charset=utf-8" -Text '{"status":"queued","message":"Lead request has been queued."}'
            $client.Close()
            continue
        }

        if ($method -eq "POST" -and $path -eq "/api/ai/handoff") {
            Write-TextResponse -Stream $stream -StatusCode 200 -ContentType "application/json; charset=utf-8" -Text '{"status":"queued","message":"Handoff request has been queued."}'
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
