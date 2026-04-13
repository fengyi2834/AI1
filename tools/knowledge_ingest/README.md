# Knowledge Ingest Tool

Extract text from `.xlsx` and `.docx` files, clean it, and export Markdown/JSON/CSV
for later import into FastGPT.

## Quick start

```bash
python ingest.py --input ./raw_docs --output ./out --format md,json,csv
```

## CLI usage

```bash
python ingest.py \
  --input ./raw_docs \
  --output ./out \
  --format md,json,csv \
  --max-chars 1500
```

### Arguments

- `--input` (required): file or directory containing `.xlsx`/`.docx`.
- `--output`: output directory, default `./out`.
- `--format`: `md,json,csv` or `all` (default).
- `--recursive` / `--no-recursive`: scan directories recursively (default: recursive).
- `--docx-tables` / `--no-docx-tables`: include tables in docx (default: include).
- `--normalize-spaces` / `--no-normalize-spaces`: normalize whitespace (default: on).
- `--max-chars`: split long content into chunks by max characters (default: 0 = no chunking).
- `--config`: path to JSON config file.

## Config example

Save as `config.json`:

```json
{
  "input": "./raw_docs",
  "output": "./out",
  "format": "md,json,csv",
  "recursive": true,
  "docx_tables": true,
  "normalize_spaces": true,
  "max_chars": 1500
}
```

Run:

```bash
python ingest.py --config config.json
```

## Output format

Each input file produces `basename.md`, `basename.json`, and `basename.csv` (depending on `--format`).

`JSON/CSV` fields:

- `source_file`: relative path from the input root
- `source_type`: `docx` or `xlsx`
- `block_type`: `paragraph`, `table_row`, or `row`
- `section`: sheet name for xlsx, empty for docx
- `index`: block index in the source
- `chunk`: chunk index when `--max-chars` is enabled
- `content`: cleaned text

## Minimal dependencies

Python 3.9+ and these packages:

- `openpyxl`
- `python-docx`

Install:

```bash
pip install -r requirements.txt
```

## Notes and limits

- `.doc` and `.xls` (legacy formats) are not supported.
- For `.xlsx`, rows that are entirely empty are skipped.
- Markdown output is plain text with section headers for sheets.
