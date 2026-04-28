from __future__ import annotations

import argparse
import re
from pathlib import Path
from zipfile import ZipFile

import fitz


def clean_text(text: str) -> str:
    text = text.replace("\u3000", " ")
    text = text.replace("\r\n", "\n").replace("\r", "\n")
    text = re.sub(r"[ \t]+", " ", text)
    text = re.sub(r"\n{3,}", "\n\n", text)
    return text.strip()


def extract_pptx_text(path: Path) -> list[tuple[str, str]]:
    items: list[tuple[str, str]] = []
    with ZipFile(path) as zf:
        slide_names = sorted(
            [
                name
                for name in zf.namelist()
                if name.startswith("ppt/slides/slide") and name.endswith(".xml")
            ],
            key=lambda x: int(re.search(r"slide(\d+)\.xml$", x).group(1)),
        )
        for index, name in enumerate(slide_names, start=1):
            xml = zf.read(name).decode("utf-8", errors="ignore")
            parts = re.findall(r"<a:t>(.*?)</a:t>", xml)
            text = clean_text("\n".join(part.strip() for part in parts if part.strip()))
            items.append((f"Slide {index}", text))
    return items


def extract_pdf_text(path: Path) -> list[tuple[str, str]]:
    items: list[tuple[str, str]] = []
    pdf = fitz.open(path)
    try:
        for index in range(pdf.page_count):
            text = clean_text(pdf.load_page(index).get_text("text"))
            items.append((f"Page {index + 1}", text))
    finally:
        pdf.close()
    return items


def write_markdown(source_path: Path, items: list[tuple[str, str]], output_path: Path) -> None:
    lines = [f"# Extracted Content: {source_path.name}", ""]
    for title, text in items:
        lines.append(f"## {title}")
        lines.append("")
        lines.append(text if text else "(empty)")
        lines.append("")
    output_path.write_text("\n".join(lines), encoding="utf-8")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--source-dir", required=True)
    parser.add_argument("--output-dir", required=True)
    args = parser.parse_args()

    source_dir = Path(args.source_dir)
    output_dir = Path(args.output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)

    for path in sorted(source_dir.iterdir()):
        if not path.is_file():
            continue
        if path.suffix.lower() == ".pptx":
            items = extract_pptx_text(path)
        elif path.suffix.lower() == ".pdf":
            items = extract_pdf_text(path)
        else:
            continue

        output_path = output_dir / f"{path.stem}.extracted.md"
        write_markdown(path, items, output_path)
        print(output_path)


if __name__ == "__main__":
    main()
