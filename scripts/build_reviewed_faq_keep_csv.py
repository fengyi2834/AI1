from __future__ import annotations

import argparse
import csv
from pathlib import Path


DEFAULT_SOURCE = Path(
    r"C:\Users\Administrator\Desktop\zi liao\outputs\fastgpt_import\final_for_import\faq_with_sources.csv"
)
DEFAULT_OUTPUT = Path(
    r"C:\Users\Administrator\Desktop\AI1\data\faq\customer_top_10_50_docx_keep.csv"
)


def normalize_text(value: str) -> str:
    return " ".join((value or "").strip().split())


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--source", default=str(DEFAULT_SOURCE))
    parser.add_argument("--output", default=str(DEFAULT_OUTPUT))
    args = parser.parse_args()

    source = Path(args.source)
    output = Path(args.output)

    if not source.exists():
        raise FileNotFoundError(f"Source CSV not found: {source}")

    with source.open("r", encoding="utf-8-sig", newline="") as file:
        rows = list(csv.DictReader(file))

    keep_rows: list[dict[str, str]] = []
    seen_questions: set[str] = set()

    for row in rows:
        disposition = normalize_text(row.get("disposition", "")).lower()
        if disposition != "keep":
            continue

        question = normalize_text(row.get("question", ""))
        answer = normalize_text(row.get("answer", ""))
        if not question or not answer or question in seen_questions:
            continue

        seen_questions.add(question)
        keep_rows.append({"question": question, "answer": answer})

    output.parent.mkdir(parents=True, exist_ok=True)
    with output.open("w", encoding="utf-8-sig", newline="") as file:
        writer = csv.DictWriter(file, fieldnames=["question", "answer"])
        writer.writeheader()
        writer.writerows(keep_rows)

    print(f"Wrote {len(keep_rows)} keep FAQ rows to {output}")


if __name__ == "__main__":
    main()
