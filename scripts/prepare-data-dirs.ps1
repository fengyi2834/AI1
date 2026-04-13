$directories = @(
    ".\data\raw_docs",
    ".\data\clean_text",
    ".\data\faq",
    ".\data\import_ready",
    ".\data\uploads",
    ".\data\logs",
    ".\infra\fastgpt\runtime\pg",
    ".\infra\fastgpt\runtime\mongo",
    ".\infra\fastgpt\runtime\redis",
    ".\infra\fastgpt\runtime\minio",
    ".\infra\fastgpt\runtime\aiproxy_pg"
)

foreach ($dir in $directories) {
    if (-not (Test-Path -LiteralPath $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
        Write-Output "Created: $dir"
    } else {
        Write-Output "Exists: $dir"
    }
}
