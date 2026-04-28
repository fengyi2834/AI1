"""
Build FastGPT-importable knowledge base files from PPTX/PDF materials.

Goals:
- Extract only real content (no fabrication)
- Keep auditability: every FAQ row traces back to file + page/slide
- Output a clean FAQ CSV (question,answer) that can be imported directly

Usage (PowerShell):
  .\\.venv\\Scripts\\python.exe tools\\fastgpt_kb\\build_fastgpt_kb.py `
    --input-dir \"C:\\Users\\Administrator\\Desktop\\资料\\1\" `
    --output-dir \"C:\\Users\\Administrator\\Desktop\\AI1\\outputs\\fastgpt_import\"
"""

from __future__ import annotations

import argparse
import csv
import json
import re
import sys
from collections import Counter, defaultdict
from dataclasses import dataclass
from datetime import datetime
from pathlib import Path
from typing import Iterable, Iterator


try:
    import fitz  # PyMuPDF
except Exception as exc:  # pragma: no cover
    raise SystemExit(
        "Missing dependency 'pymupdf'. Install via: "
        ".\\.venv\\Scripts\\python.exe -m pip install pymupdf"
    ) from exc

try:
    from pptx import Presentation  # python-pptx
except Exception as exc:  # pragma: no cover
    raise SystemExit(
        "Missing dependency 'python-pptx'. Install via: "
        ".\\.venv\\Scripts\\python.exe -m pip install python-pptx"
    ) from exc


@dataclass(frozen=True)
class Chunk:
    source_path: str
    source_type: str  # "pptx" | "pdf"
    loc: str  # "slide=3" or "page=10"
    chunk_type: str  # "text" | "table"
    raw_text: str
    clean_text: str


@dataclass(frozen=True)
class FAQRow:
    question: str
    answer: str
    source_path: str
    source_loc: str
    confidence: str  # "high" | "medium"
    needs_review: bool


NOISE_LINE_PATTERNS: list[re.Pattern[str]] = [
    re.compile(r"^\s*\d+\s*/\s*\d+\s*$"),  # "1/20"
    re.compile(r"^\s*第\s*\d+\s*页\s*/\s*共\s*\d+\s*页\s*$"),
    re.compile(r"^\s*page\s*\d+\s*(of\s*\d+)?\s*$", re.I),
    re.compile(r"^\s*(目录|contents)\s*$", re.I),
    re.compile(r"^\s*(谢谢|THANK\s*YOU|致谢)\s*$", re.I),
    re.compile(r"^\s*(保密|confidential)\s*$", re.I),
]


QUESTION_PREFIX = re.compile(r"^\s*(问\s*[:：]|Q\s*[:：]|问题\s*[:：])\s*(.+?)\s*$", re.I)
ANSWER_PREFIX = re.compile(r"^\s*(答\s*[:：]|A\s*[:：]|答案\s*[:：])\s*(.+?)\s*$", re.I)
QA_SAME_LINE = re.compile(
    r"^\s*(?:问\s*[:：]|Q\s*[:：]|问题\s*[:：])\s*(?P<q>.+?)\s*"
    r"(?:答\s*[:：]|A\s*[:：]|答案\s*[:：])\s*(?P<a>.+?)\s*$",
    re.I,
)


def _normalize_spaces(text: str) -> str:
    # Keep newlines for structure, but normalize other whitespace.
    text = text.replace("\r\n", "\n").replace("\r", "\n")
    text = text.replace("\u00a0", " ")  # nbsp
    text = re.sub(r"[ \t]+", " ", text)
    return text


def _split_lines(text: str) -> list[str]:
    lines = [ln.strip() for ln in _normalize_spaces(text).split("\n")]
    return [ln for ln in lines if ln]


def _is_noise_line(line: str) -> bool:
    if not line:
        return True
    if len(line) <= 2 and re.fullmatch(r"[\d\-–—]+", line):
        return True
    for pat in NOISE_LINE_PATTERNS:
        if pat.match(line):
            return True
    return False


def _clean_block(text: str, common_lines: set[str] | None = None) -> str:
    lines = _split_lines(text)
    out: list[str] = []
    for ln in lines:
        if _is_noise_line(ln):
            continue
        if common_lines and ln in common_lines:
            continue
        out.append(ln)
    # De-dup immediate repeats (often PPT text boxes overlap).
    dedup: list[str] = []
    for ln in out:
        if dedup and dedup[-1] == ln:
            continue
        dedup.append(ln)
    return "\n".join(dedup).strip()


def extract_pdf(path: Path) -> Iterator[tuple[str, str, str]]:
    # yields (loc, chunk_type, raw_text)
    doc = fitz.open(path)
    try:
        for page_index in range(doc.page_count):
            page = doc.load_page(page_index)
            text = page.get_text("text") or ""
            loc = f"page={page_index + 1}"
            yield loc, "text", text
    finally:
        doc.close()


def _table_to_text(tbl) -> str:
    rows: list[str] = []
    for r in range(len(tbl.rows)):
        cells: list[str] = []
        for c in range(len(tbl.columns)):
            cell_text = (tbl.cell(r, c).text or "").strip()
            cell_text = _normalize_spaces(cell_text).strip()
            cells.append(cell_text)
        # Skip fully empty rows.
        if any(cells):
            rows.append(" | ".join(cells))
    return "\n".join(rows).strip()


def extract_pptx(path: Path) -> Iterator[tuple[str, str, str]]:
    # yields (loc, chunk_type, raw_text)
    prs = Presentation(str(path))
    for slide_index, slide in enumerate(prs.slides, start=1):
        loc_prefix = f"slide={slide_index}"
        # Extract text frames and tables as separate chunks (auditability).
        for shape_index, shape in enumerate(slide.shapes, start=1):
            if getattr(shape, "has_text_frame", False) and shape.has_text_frame:
                txt = (shape.text or "").strip()
                if txt:
                    yield f"{loc_prefix};shape={shape_index}", "text", txt
            if getattr(shape, "has_table", False) and shape.has_table:
                ttxt = _table_to_text(shape.table)
                if ttxt:
                    yield f"{loc_prefix};shape={shape_index}", "table", ttxt


def _compute_common_lines(all_blocks: list[str]) -> set[str]:
    # Identify repeated short lines that appear on many pages/slides (likely header/footer).
    counts: Counter[str] = Counter()
    block_count = 0
    for blk in all_blocks:
        lines = _split_lines(blk)
        if not lines:
            continue
        block_count += 1
        # Count only short-ish lines; long lines are usually content.
        for ln in set(lines):
            if 2 <= len(ln) <= 28:
                counts[ln] += 1
    if block_count <= 3:
        return set()
    threshold = max(3, int(block_count * 0.6))
    return {ln for ln, c in counts.items() if c >= threshold and not _is_noise_line(ln)}


def build_chunks(input_dir: Path) -> list[Chunk]:
    chunks: list[Chunk] = []
    for path in sorted(input_dir.glob("**/*")):
        if not path.is_file():
            continue
        ext = path.suffix.lower()
        if ext not in {".pdf", ".pptx"}:
            continue

        source_type = "pdf" if ext == ".pdf" else "pptx"
        extractor = extract_pdf if source_type == "pdf" else extract_pptx

        raw_blocks: list[tuple[str, str, str]] = list(extractor(path))
        common_lines = _compute_common_lines([t for _, _, t in raw_blocks])

        for loc, chunk_type, raw_text in raw_blocks:
            clean_text = _clean_block(raw_text, common_lines=common_lines)
            if not clean_text:
                continue
            chunks.append(
                Chunk(
                    source_path=str(path),
                    source_type=source_type,
                    loc=loc,
                    chunk_type=chunk_type,
                    raw_text=_normalize_spaces(raw_text).strip(),
                    clean_text=clean_text,
                )
            )
    return chunks


def _question_like(line: str) -> bool:
    line = line.strip()
    if not line or len(line) > 60:
        return False
    if line.endswith(("？", "?")):
        return True
    # Common Chinese question lead-ins.
    starters = ("什么是", "为何", "为什么", "如何", "怎么", "是否", "能否", "有哪些", "区别", "对比")
    return line.startswith(starters)


def _extract_explicit_qa(text: str) -> list[tuple[str, str]]:
    lines = _split_lines(text)
    pairs: list[tuple[str, str]] = []
    if not lines:
        return pairs

    # Same-line pattern first.
    for ln in lines:
        m = QA_SAME_LINE.match(ln)
        if m:
            q = m.group("q").strip()
            a = m.group("a").strip()
            if q and a:
                pairs.append((q, a))

    # Multi-line Q/A blocks.
    i = 0
    while i < len(lines):
        qm = QUESTION_PREFIX.match(lines[i])
        if not qm:
            i += 1
            continue
        q = qm.group(2).strip()
        i += 1

        a_parts: list[str] = []
        # If next line is explicitly an answer line, strip its prefix.
        if i < len(lines):
            am = ANSWER_PREFIX.match(lines[i])
            if am:
                a_parts.append(am.group(2).strip())
                i += 1
        while i < len(lines):
            # Stop when a new question starts.
            if QUESTION_PREFIX.match(lines[i]) or QA_SAME_LINE.match(lines[i]):
                break
            # Avoid swallowing headers like "问：" mistakenly repeated.
            am = ANSWER_PREFIX.match(lines[i])
            if am:
                a_parts.append(am.group(2).strip())
            else:
                a_parts.append(lines[i])
            i += 1

        a = "\n".join([p for p in a_parts if p]).strip()
        if q and a:
            pairs.append((q, a))
    return pairs


LABEL_PAT = re.compile(r"^\s*(?P<label>特点|优势|功能|适用范围|适用场景|应用场景|应用范围|规格|参数|性能|材质|成分|结构|工艺|安装|施工|使用方法|注意事项|售后|保修)\s*[:：]\s*(?P<rest>.+?)\s*$")


def _looks_like_topic(line: str) -> bool:
    line = line.strip()
    if not line:
        return False
    if len(line) > 30:
        return False
    if _is_noise_line(line):
        return False
    if LABEL_PAT.match(line):
        return False
    # Avoid generic section headers.
    if line in {"产品介绍", "公司简介", "简介", "目录", "概述"}:
        return False
    # Heuristic: prefer short noun-ish lines.
    if line.endswith(("。", ".", "，", ",")):
        return False
    return True


def _is_topic_boundary(lines: list[str], index: int) -> bool:
    """
    A short topic-like line followed by a labeled section usually means
    the next product block has started.
    """
    if index < 0 or index >= len(lines):
        return False
    if not _looks_like_topic(lines[index]):
        return False
    if index + 1 >= len(lines):
        return False
    return bool(LABEL_PAT.match(lines[index + 1]))


def _normalize_topic_name(topic: str) -> str:
    topic = re.sub(r"\s+", " ", topic).strip()
    while len(topic) >= 2 and topic[-1] == topic[-2] and topic[-1] in "板材门砖片膜":
        topic = topic[:-1]
    return topic


def _split_trailing_topic_lines(content_lines: list[str]) -> tuple[list[str], list[str]]:
    trimmed = list(content_lines)
    trailing_topics: list[str] = []
    while trimmed and _looks_like_topic(trimmed[-1]):
        trailing_topics.append(trimmed.pop())
    trailing_topics.reverse()
    return trimmed, trailing_topics


def _find_topic(lines: list[str], label_index: int) -> str | None:
    # Search backwards for a likely topic name near the label.
    for j in range(label_index - 1, max(-1, label_index - 6), -1):
        if j < 0:
            break
        candidate = lines[j].strip()
        if _looks_like_topic(candidate):
            return candidate
    return None


def _qa_from_labeled_sections(text: str, fallback_topic: str | None = None) -> list[tuple[str, str, str]]:
    """
    Derive Q/A pairs from labeled sections like:
      硅藻素板
      特点：xxx
      适用范围：yyy

    Returns tuples: (question, answer, confidence)
    """
    lines = _split_lines(text)
    if not lines:
        return []

    pairs: list[tuple[str, str, str]] = []
    i = 0
    while i < len(lines):
        m = LABEL_PAT.match(lines[i])
        if not m:
            i += 1
            continue
        label = m.group("label").strip()
        rest = m.group("rest").strip()
        label_index = i

        # Capture continuation lines until next label-like line.
        content_lines: list[str] = []
        if rest:
            content_lines.append(rest)
            confidence = "high"
        else:
            confidence = "medium"
        i += 1
        while i < len(lines) and not LABEL_PAT.match(lines[i]) and not QUESTION_PREFIX.match(lines[i]) and not QA_SAME_LINE.match(lines[i]):
            # Stop if we hit an obvious new section header.
            if re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9 \-]{2,}$", lines[i]):
                break
            content_lines.append(lines[i])
            i += 1

        answer_lines, trailing_topics = _split_trailing_topic_lines(content_lines)
        topic = (trailing_topics[-1] if trailing_topics else None) or _find_topic(lines, label_index) or fallback_topic
        if topic:
            topic = _normalize_topic_name(topic)
        answer = "\n".join([c for c in answer_lines if c]).strip()
        # Avoid very short/meaningless answers.
        if len(answer) < 15:
            continue
        if not topic:
            continue

        def _with_topic(prefix: str) -> str:
            if topic:
                return prefix.format(topic=topic)
            # As a last resort, keep the question traceable rather than fabricating a topic.
            return prefix.format(topic="该材料")

        if label in {"适用范围", "适用场景", "应用场景", "应用范围"}:
            q = _with_topic("{topic}适用范围是什么？")
        elif label in {"规格", "参数"}:
            q = _with_topic("{topic}规格参数有哪些？")
        elif label in {"安装", "施工", "使用方法", "注意事项"}:
            q = _with_topic("{topic}" + label + "有哪些要点？")
        else:
            # Naturalize common labels
            if label in {"特点", "优势", "功能", "性能"}:
                q = _with_topic("{topic}有哪些" + label + "？")
            else:
                q = _with_topic("{topic}" + label + "是什么？")

        pairs.append((q, answer, confidence))
    return pairs


def _group_key(chunk: Chunk) -> tuple[str, str]:
    # Group by file + slide/page index, ignoring shape.
    if chunk.source_type == "pptx":
        m = re.search(r"slide=(\d+)", chunk.loc)
        idx = m.group(1) if m else "?"
        return chunk.source_path, f"slide={idx}"
    m = re.search(r"page=(\d+)", chunk.loc)
    idx = m.group(1) if m else "?"
    return chunk.source_path, f"page={idx}"


def build_faq(chunks: list[Chunk]) -> list[FAQRow]:
    rows: list[FAQRow] = []

    # 1) Explicit Q/A markers (highest confidence).
    for ch in chunks:
        pairs = _extract_explicit_qa(ch.clean_text)
        for q, a in pairs:
            rows.append(
                FAQRow(
                    question=q,
                    answer=a,
                    source_path=ch.source_path,
                    source_loc=ch.loc,
                    confidence="high",
                    needs_review=False,
                )
            )

    # 2) Labeled sections -> Q/A derived from labels (still real text, but question is derived).
    grouped: dict[tuple[str, str], list[Chunk]] = defaultdict(list)
    for ch in chunks:
        grouped[_group_key(ch)].append(ch)

    for (source_path, loc), group_chunks in grouped.items():
        combined = "\n".join(ch.clean_text for ch in group_chunks if ch.clean_text).strip()
        for q, a, conf in _qa_from_labeled_sections(combined):
            rows.append(
                FAQRow(
                    question=q,
                    answer=a,
                    source_path=source_path,
                    source_loc=loc,
                    confidence=conf,
                    needs_review=True,
                )
            )

    # Deduplicate by normalized (q,a).
    seen: set[tuple[str, str]] = set()
    deduped: list[FAQRow] = []
    for r in rows:
        # Compact to single-line text for import friendliness (still faithful content).
        q = re.sub(r"\s+", " ", r.question).strip()
        a = re.sub(r"\s+", " ", r.answer).strip()
        key = (q, a)
        if key in seen:
            continue
        seen.add(key)
        deduped.append(
            FAQRow(
                question=q,
                answer=a,
                source_path=r.source_path,
                source_loc=r.source_loc,
                confidence=r.confidence,
                needs_review=r.needs_review,
            )
        )
    return deduped


def build_product_markdown(chunks: list[Chunk]) -> str:
    # A safe, non-fabricated KB doc: just cleaned excerpts with source anchors.
    grouped: dict[tuple[str, str], list[Chunk]] = defaultdict(list)
    for ch in chunks:
        grouped[_group_key(ch)].append(ch)

    parts: list[str] = []
    parts.append("# 产品/材料知识摘录（可审计版）")
    parts.append("")
    parts.append("说明：本文档内容为从 PDF/PPTX 提取并轻度去噪后的原文摘录，不包含推测或补写。")
    parts.append("")

    for (source_path, loc) in sorted(grouped.keys()):
        src_name = Path(source_path).name
        parts.append(f"## {src_name} [{loc}]")
        parts.append("")
        text = "\n".join(ch.clean_text for ch in grouped[(source_path, loc)] if ch.clean_text).strip()
        if not text:
            parts.append("(空)")
            parts.append("")
            continue
        # Keep it readable: convert to bullet-ish lines.
        for ln in _split_lines(text):
            parts.append(f"- {ln}")
        parts.append("")
    return "\n".join(parts).rstrip() + "\n"

def build_doc_chunks(chunks: list[Chunk]) -> list[dict]:
    grouped: dict[tuple[str, str], list[Chunk]] = defaultdict(list)
    for ch in chunks:
        grouped[_group_key(ch)].append(ch)

    rows: list[dict] = []
    for (source_path, loc) in sorted(grouped.keys()):
        src_name = Path(source_path).name
        text = "\n".join(ch.clean_text for ch in grouped[(source_path, loc)] if ch.clean_text).strip()
        if not text:
            continue
        rows.append(
            {
                "title": f"{src_name} {loc}",
                "content": text,
                "source_file": src_name,
                "source_loc": loc,
            }
        )
    return rows


def write_jsonl(path: Path, rows: Iterable[dict]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8") as f:
        for row in rows:
            f.write(json.dumps(row, ensure_ascii=False) + "\n")


def write_csv_utf8_sig(path: Path, headers: list[str], rows: Iterable[dict]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8-sig", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=headers, quoting=csv.QUOTE_MINIMAL)
        writer.writeheader()
        for r in rows:
            writer.writerow({h: r.get(h, "") for h in headers})


def main(argv: list[str]) -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--input-dir", required=True, help="Folder containing PPTX/PDF materials")
    ap.add_argument("--output-dir", required=True, help="Output folder for FastGPT import files")
    ap.add_argument(
        "--run-id",
        default=datetime.now().strftime("%Y%m%d_%H%M%S"),
        help="Run identifier (default: timestamp)",
    )
    args = ap.parse_args(argv)

    input_dir = Path(args.input_dir)
    output_root = Path(args.output_dir) / f"run_{args.run_id}"
    output_root.mkdir(parents=True, exist_ok=True)

    if not input_dir.exists():
        raise SystemExit(f"Input dir does not exist: {input_dir}")

    chunks = build_chunks(input_dir)
    write_jsonl(
        output_root / "extracted_chunks.jsonl",
        (
            {
                "source_path": c.source_path,
                "source_type": c.source_type,
                "loc": c.loc,
                "chunk_type": c.chunk_type,
                "raw_text": c.raw_text,
            }
            for c in chunks
        ),
    )
    write_jsonl(
        output_root / "cleaned_chunks.jsonl",
        (
            {
                "source_path": c.source_path,
                "source_type": c.source_type,
                "loc": c.loc,
                "chunk_type": c.chunk_type,
                "clean_text": c.clean_text,
            }
            for c in chunks
        ),
    )

    faqs = build_faq(chunks)
    write_csv_utf8_sig(
        output_root / "faq.csv",
        headers=["question", "answer"],
        rows=(
            {
                "question": r.question,
                "answer": r.answer,
            }
            for r in faqs
        ),
    )
    write_csv_utf8_sig(
        output_root / "faq_with_sources.csv",
        headers=["question", "answer", "source_file", "source_loc", "confidence", "needs_review"],
        rows=(
            {
                "question": r.question,
                "answer": r.answer,
                "source_file": Path(r.source_path).name,
                "source_loc": r.source_loc,
                "confidence": r.confidence,
                "needs_review": "YES" if r.needs_review else "",
            }
            for r in faqs
        ),
    )

    md = build_product_markdown(chunks)
    (output_root / "product_knowledge.md").write_text(md, encoding="utf-8")

    doc_rows = build_doc_chunks(chunks)
    write_csv_utf8_sig(
        output_root / "doc_chunks.csv",
        headers=["title", "content", "source_file", "source_loc"],
        rows=doc_rows,
    )

    review_items = [r for r in faqs if r.needs_review]
    review_md_lines = [
        "# 需要人工复核的 FAQ 条目",
        "",
        "这些条目来自“标题像问题 + 同页内容像答案”的启发式规则，内容仍然来自原文，但更容易出现误配。",
        "建议逐条对照 `faq_with_sources.csv` 的 `source_loc` 复核后再导入或在 FastGPT 后台编辑。",
        "",
    ]
    if not review_items:
        review_md_lines.append("(无)")
        review_md_lines.append("")
    else:
        for r in review_items:
            review_md_lines.append(f"- Q: {r.question} ({Path(r.source_path).name} {r.source_loc})")
    (output_root / "review_todo.md").write_text("\n".join(review_md_lines).rstrip() + "\n", encoding="utf-8")

    import_md = "\n".join(
        [
            "# FastGPT 知识库导入说明（本次产物）",
            "",
            "## 产物文件",
            "",
            "- `faq.csv`：干净 FAQ（两列：question,answer），建议直接用于 FastGPT FAQ 导入。",
            "- `faq_with_sources.csv`：带来源定位与置信度，便于复核与追溯。",
            "- `product_knowledge.md`：结构化摘录文档（非 FAQ 内容也可作为知识库文档导入）。",
            "- `review_todo.md`：标记需要人工复核的 FAQ（来自启发式标题问答匹配）。",
            "- `cleaned_chunks.jsonl` / `extracted_chunks.jsonl`：审计用中间文件。",
            "",
            "## 建议导入顺序",
            "",
            "1. 先导入 `faq.csv`。",
            "2. 如需要补充产品知识，再导入 `product_knowledge.md` 为文档类知识（或拆分后导入）。",
            "3. 复核 `review_todo.md` 中的条目，必要时在 FastGPT 后台修正问答对。",
            "",
            "## 编码与兼容性",
            "",
            "- CSV 使用 `UTF-8 with BOM (utf-8-sig)`，避免 Windows/Excel/某些导入器出现中文乱码。",
            "",
        ]
    )
    (output_root / "IMPORT_README.md").write_text(import_md.rstrip() + "\n", encoding="utf-8")

    summary = {
        "input_dir": str(input_dir),
        "output_dir": str(output_root),
        "chunk_count": len(chunks),
        "faq_count": len(faqs),
        "faq_needs_review": len(review_items),
        "doc_chunk_count": len(doc_rows),
        "files": sorted({Path(c.source_path).name for c in chunks}),
    }
    (output_root / "run_summary.json").write_text(json.dumps(summary, ensure_ascii=False, indent=2), encoding="utf-8")

    print(json.dumps(summary, ensure_ascii=False, indent=2))
    return 0


if __name__ == "__main__":  # pragma: no cover
    raise SystemExit(main(sys.argv[1:]))
