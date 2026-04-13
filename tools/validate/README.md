# Validation Tools

These scripts validate raw source documents, import outputs, and config completeness.

## Quick Run

```powershell
.\tools\validate\run_all.ps1 -RawDocsPath .\data\raw_docs -ImportPath .\data\import_ready -ConfigPath .\.env
```

## Check Raw Docs

```powershell
.\tools\validate\check_raw_docs.ps1 -Path .\data\raw_docs -Extensions .xlsx,.docx -MinFiles 1
```

## Check Import Outputs

```powershell
.\tools\validate\check_import_outputs.ps1 -Path .\data\import_ready -ExpectedExtensions .md,.txt,.csv,.json,.jsonl -MinFiles 1
```

If you require specific files:

```powershell
.\tools\validate\check_import_outputs.ps1 -Path .\data\import_ready -RequiredFiles faq.csv,knowledge.jsonl
```

## Check Config

```powershell
.\tools\validate\check_config.ps1 -ConfigPath .\.env
```

Default required keys come from `tools/validate/required_keys.txt`.
