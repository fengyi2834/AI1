from __future__ import annotations

import argparse
import csv
import re
from pathlib import Path


DEFAULT_SOURCE = Path(
    r"C:\Users\Administrator\Desktop\zi liao\outputs\fastgpt_import\final_for_import\doc_chunks.csv"
)
DEFAULT_SAFE = Path(
    r"C:\Users\Administrator\Desktop\AI1\data\import_ready\doc_chunks_safe.csv"
)
DEFAULT_REVIEW = Path(
    r"C:\Users\Administrator\Desktop\AI1\data\import_ready\doc_chunks_needs_review.csv"
)

RISK_PATTERNS = [
    r"抗菌率",
    r"99\.?9%",
    r"医疗级",
    r"无菌",
    r"净化甲醛",
    r"净醛",
    r"分解.*有害气体",
    r"转化为无毒无害",
    r"不释放任何对人体有害",
    r"甲醛必然超标",
    r"中远红外",
    r"远红外",
    r"加快新陈代谢",
    r"促进血液循环",
    r"减少疲劳",
    r"消除过敏源",
    r"过敏源",
    r"防止交叉感染",
    r"交叉感染",
    r"医院",
    r"实验室",
    r"无醛",
    r"绿色.?环保",
]


def is_risky(text: str) -> bool:
    return any(re.search(pattern, text, flags=re.IGNORECASE | re.DOTALL) for pattern in RISK_PATTERNS)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--source", default=str(DEFAULT_SOURCE))
    parser.add_argument("--safe-output", default=str(DEFAULT_SAFE))
    parser.add_argument("--review-output", default=str(DEFAULT_REVIEW))
    args = parser.parse_args()

    source = Path(args.source)
    safe_output = Path(args.safe_output)
    review_output = Path(args.review_output)

    if not source.exists():
        raise FileNotFoundError(f"Source CSV not found: {source}")

    with source.open("r", encoding="utf-8-sig", newline="") as file:
        rows = list(csv.DictReader(file))

    safe_rows: list[dict[str, str]] = []
    review_rows: list[dict[str, str]] = []

    for row in rows:
        text = "\n".join(
            [
                (row.get("title") or "").strip(),
                (row.get("content") or "").strip(),
                (row.get("source_file") or "").strip(),
            ]
        )
        if is_risky(text):
            review_rows.append(row)
        else:
            safe_rows.append(row)

    safe_output.parent.mkdir(parents=True, exist_ok=True)
    review_output.parent.mkdir(parents=True, exist_ok=True)

    fieldnames = ["title", "content", "source_file", "source_loc"]
    with safe_output.open("w", encoding="utf-8-sig", newline="") as file:
        writer = csv.DictWriter(file, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(safe_rows)

    with review_output.open("w", encoding="utf-8-sig", newline="") as file:
        writer = csv.DictWriter(file, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(review_rows)

    print(f"Safe rows: {len(safe_rows)} -> {safe_output}")
    print(f"Review rows: {len(review_rows)} -> {review_output}")


if __name__ == "__main__":
    main()
