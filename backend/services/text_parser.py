import re


def _normalize_paragraphs(text: str) -> str:
    cleaned = re.sub(r'\[Illustration\]', '', text, flags=re.IGNORECASE)
    paragraphs = [
        re.sub(r'\s+', ' ', para.strip())
        for para in re.split(r'\n{2,}', cleaned)
        if para.strip()
    ]
    return "\n\n".join(paragraphs)


_NUMBER_WORD_PATTERN = (
    r"(?:One|Two|Three|Four|Five|Six|Seven|Eight|Nine|Ten|"
    r"Eleven|Twelve|Thirteen|Fourteen|Fifteen|Sixteen|Seventeen|Eighteen|Nineteen|"
    r"Twenty(?:[-\s]+(?:One|Two|Three|Four|Five|Six|Seven|Eight|Nine))?|"
    r"Thirty(?:[-\s]+(?:One|Two|Three|Four|Five|Six|Seven|Eight|Nine))?|"
    r"Forty(?:[-\s]+(?:One|Two|Three|Four|Five|Six|Seven|Eight|Nine))?|"
    r"Fifty(?:[-\s]+(?:One|Two|Three|Four|Five|Six|Seven|Eight|Nine))?|"
    r"Sixty(?:[-\s]+(?:One|Two|Three|Four|Five|Six|Seven|Eight|Nine))?|"
    r"Seventy(?:[-\s]+(?:One|Two|Three|Four|Five|Six|Seven|Eight|Nine))?|"
    r"Eighty(?:[-\s]+(?:One|Two|Three|Four|Five|Six|Seven|Eight|Nine))?|"
    r"Ninety(?:[-\s]+(?:One|Two|Three|Four|Five|Six|Seven|Eight|Nine))?|"
    r"(?:The\s+)?(?:First|Second|Third|Fourth|Fifth|Sixth|Seventh|Eighth|Ninth|Tenth|"
    r"Eleventh|Twelfth|Thirteenth|Fourteenth|Fifteenth|Sixteenth|Seventeenth|"
    r"Eighteenth|Nineteenth|Twentieth|Last))"
)

_EXPLICIT_HEADING_PATTERN = (
    rf"(?:^|\n{{2,}})[ \t]*[*_]?"
    rf"((?:CHAPTER|Chapter|STAVE|Stave|LETTER|Letter|BOOK|Book|ACT|Act|PART|Part|CANTO|Canto)"
    rf"[ \t]+(?:[0-9IVXLCDM]+|{_NUMBER_WORD_PATTERN})[^\n]*?)"
    rf"[*_]?[ \t]*(?=\n|$)"
)

_TOC_LINE_PATTERN = re.compile(
    r"^[ \t]*[*_]?(?:CHAPTER|Chapter|STAVE|Stave|LETTER|Letter|BOOK|Book|ACT|Act|PART|Part|CANTO|Canto)\b",
    re.MULTILINE,
)

_TOC_ROMAN_LINE_PATTERN = re.compile(
    r"^[ \t]*[IVXLCDM]{1,7}\.[ \t]+[A-Z]",
    re.MULTILINE,
)

_TOC_BARE_ROMAN_PATTERN = re.compile(
    r"^[ \t]*[IVXLCDM]{1,6}\.?[ \t]*\n(?:[ \t]*\n)*[ \t]*[IVXLCDM]{1,6}\.?[ \t]*$",
    re.MULTILINE,
)


def _is_toc_listing(body: str) -> bool:
    stripped = body.strip()
    if len(stripped) < 50:
        return True
    words = len(stripped.split())
    toc_lines = len(_TOC_LINE_PATTERN.findall(stripped))
    roman_toc_lines = len(_TOC_ROMAN_LINE_PATTERN.findall(stripped))
    head_block = "\n".join(stripped.splitlines()[:20])
    has_adjacent_bare_romans = bool(_TOC_BARE_ROMAN_PATTERN.search(head_block))
    if (toc_lines >= 2 or roman_toc_lines >= 2 or has_adjacent_bare_romans) and words < 450:
        return True
    return False


def _clean_chapter_title(raw_title: str) -> str:
    return re.sub(r"[ \t]+", " ", raw_title.strip().strip("*_").rstrip("]").strip())


def _normalize_heading_key(text: str) -> str:
    normalized = text.replace("’", "'").replace("‘", "'").replace("“", '"').replace("”", '"')
    return re.sub(r"\s+", " ", normalized).strip().casefold()


def _extract_roman_sections(raw_text: str) -> list[dict]:
    """Extracts either titled Roman chapters ('I. Title') or standalone Roman markers ('\\n\\nI\\n\\n')."""
    roman_titled_pattern = (
        r"(?:^|\n{2,})[ \t]*([IVXLCDM]{1,7}\.[ \t]+[^\n]{2,80})[ \t]*(?=\n|$)"
        r"|"
        r"(?:^|\n{2,})[ \t]*([IVXLCDM]{1,7}\.[ \t]*\n[ \t]*[A-Z][^\n]{1,80})[ \t]*(?=\n{2,})"
    )
    roman_titled_splits = re.split(roman_titled_pattern, raw_text)
    if len(roman_titled_splits) > 3:
        extracted: list[dict] = []
        chapter_idx = 1
        for i in range(1, len(roman_titled_splits), 3):
            raw_heading = roman_titled_splits[i] or roman_titled_splits[i + 1] or ""
            ch_body = roman_titled_splits[i + 2].strip() if i + 2 < len(roman_titled_splits) else ""
            ch_title = _clean_chapter_title(raw_heading.replace("\n", " "))
            if ch_title and not _is_toc_listing(ch_body):
                normalized_body = _normalize_paragraphs(ch_body)
                words = len(normalized_body.split())
                if words > 0:
                    extracted.append({
                        "chapter_number": chapter_idx,
                        "title": ch_title,
                        "content": normalized_body,
                        "word_count": words,
                    })
                    chapter_idx += 1
        if len(extracted) >= 2:
            return extracted

    roman_pattern = r'(?:^|\n{2,})[ \t]*([IVXLCDM]{1,7})\.?[ \t]*\n{2,}'
    roman_splits = re.split(roman_pattern, raw_text)
    if len(roman_splits) > 2:
        extracted = []
        chapter_idx = 1
        for i in range(1, len(roman_splits), 2):
            ch_title = f"Chapter {roman_splits[i].strip()}"
            ch_body = roman_splits[i + 1].strip() if i + 1 < len(roman_splits) else ""
            if len(ch_body.strip()) >= 50:
                normalized_body = _normalize_paragraphs(ch_body)
                words = len(normalized_body.split())
                if words > 0:
                    extracted.append({
                        "chapter_number": chapter_idx,
                        "title": ch_title,
                        "content": normalized_body,
                        "word_count": words,
                    })
                    chapter_idx += 1
        if len(extracted) >= 2:
            return extracted

    return []


def _extract_chapters_from_contents(clean_text: str) -> list[dict]:
    """
    Fallback for books whose chapters are unnumbered named sections declared under a Contents block
    (e.g., Dr. Jekyll and Mr. Hyde: 'STORY OF THE DOOR', 'SEARCH FOR MR. HYDE', ...).
    """
    if len(clean_text.split()) < 3000:
        return []

    search_limit = min(len(clean_text), max(12000, len(clean_text) // 4))
    toc_header = re.search(
        r"(?:^|\n)[ \t]*(?:TABLE OF )?CONTENTS[.:]?[ \t]*\n",
        clean_text[:search_limit],
        re.IGNORECASE,
    )
    if not toc_header:
        return []

    lines_with_offsets: list[tuple[int, str]] = []
    pos = toc_header.end()
    for line in clean_text[pos:].splitlines(keepends=True):
        lines_with_offsets.append((pos, line.rstrip("\r\n")))
        pos += len(line)
        if pos - toc_header.end() > 8000:
            break

    candidates: list[str] = []
    seen_keys: set[str] = set()
    first_key = ""
    toc_end_offset = toc_header.end()
    blank_streak = 0

    for offset, raw_line in lines_with_offsets:
        stripped = re.sub(r"\s+", " ", raw_line).strip()
        if not stripped:
            blank_streak += 1
            if blank_streak >= 3 and len(candidates) >= 3:
                toc_end_offset = offset
                break
            continue
        blank_streak = 0
        key = _normalize_heading_key(stripped)
        # Body repeats the first TOC entry -> TOC ended right before this heading
        if first_key and key == first_key:
            toc_end_offset = offset
            break
        if len(stripped) > 90 or len(stripped) < 3 or len(candidates) >= 60:
            toc_end_offset = offset
            break
        if key not in seen_keys:
            seen_keys.add(key)
            candidates.append(stripped)
            if not first_key:
                first_key = key
        toc_end_offset = offset + len(raw_line) + 1

    if len(candidates) < 3:
        return []

    candidate_by_key = {_normalize_heading_key(title): title for title in candidates}
    body_text = clean_text[toc_end_offset:]

    matched_positions: list[tuple[int, int, str]] = []
    cursor = 0
    for line in body_text.splitlines(keepends=True):
        line_len = len(line)
        stripped = re.sub(r"\s+", " ", line).strip()
        key = _normalize_heading_key(stripped)
        if key in candidate_by_key and key not in {m[2] for m in matched_positions}:
            matched_positions.append((cursor, cursor + line_len, stripped))
        cursor += line_len

    if len(matched_positions) < 3 or len(matched_positions) < max(3, int(len(candidates) * 0.6)):
        return []

    extracted: list[dict] = []
    chapter_idx = 1
    for idx, (start_off, header_end, heading_title) in enumerate(matched_positions):
        next_start = matched_positions[idx + 1][0] if idx + 1 < len(matched_positions) else len(body_text)
        ch_body = body_text[header_end:next_start].strip()
        if len(ch_body) >= 50:
            normalized_body = _normalize_paragraphs(ch_body)
            words = len(normalized_body.split())
            if words > 0:
                extracted.append({
                    "chapter_number": chapter_idx,
                    "title": heading_title.title() if heading_title.isupper() else heading_title,
                    "content": normalized_body,
                    "word_count": words,
                })
                chapter_idx += 1

    return extracted if len(extracted) >= 3 else []


def extract_chapters_from_text(raw_text: str) -> list[dict]:
    """
    Parses raw full-length text from Project Gutenberg or external literary sites,
    stripping boilerplate licenses and splitting on structural chapter boundaries.
    """
    normalized_raw = raw_text.replace("\r\n", "\n").replace("\r", "\n")
    start_match = re.search(r'\*\*\*\s*START OF (THE|THIS) PROJECT GUTENBERG EBOOK[^\*]*\*\*\*', normalized_raw, re.IGNORECASE)
    end_match = re.search(r'\*\*\*\s*END OF (THE|THIS) PROJECT GUTENBERG EBOOK', normalized_raw, re.IGNORECASE)

    start_pos = start_match.end() if start_match else 0
    end_pos = end_match.start() if end_match else len(normalized_raw)
    clean_text = normalized_raw[start_pos:end_pos].strip()

    extracted: list[dict] = []

    # 1. Explicit structural headings (CHAPTER I, _Chapter One_, STAVE I, PART I, BOOK II, etc.)
    splits = re.split(_EXPLICIT_HEADING_PATTERN, clean_text, flags=re.IGNORECASE)
    if len(splits) > 2:
        raw_parts: list[tuple[str, str]] = []
        for i in range(1, len(splits), 2):
            ch_title = _clean_chapter_title(splits[i])
            ch_body = splits[i + 1].strip() if i + 1 < len(splits) else ""
            if not _is_toc_listing(ch_body):
                raw_parts.append((ch_title, ch_body))

        chapter_idx = 1
        for ch_title, ch_body in raw_parts:
            # Subdivide coarse PART/BOOK containers if they contain Roman-numeral subchapters
            sub_chapters = (
                _extract_roman_sections(ch_body)
                if len(raw_parts) <= 10 and ch_title.upper().startswith(("PART ", "BOOK ", "VOLUME "))
                else []
            )
            if len(sub_chapters) >= 2:
                for sub in sub_chapters:
                    extracted.append({
                        "chapter_number": chapter_idx,
                        "title": f"{ch_title} — {sub['title']}",
                        "content": sub["content"],
                        "word_count": sub["word_count"],
                    })
                    chapter_idx += 1
            else:
                normalized_body = _normalize_paragraphs(ch_body)
                words = len(normalized_body.split())
                if words > 0:
                    extracted.append({
                        "chapter_number": chapter_idx,
                        "title": ch_title,
                        "content": normalized_body,
                        "word_count": words,
                    })
                    chapter_idx += 1

    # 2 & 3. Roman numeral headings ("I. Title") or standalone Roman markers ("\n\nI\n\n")
    if len(extracted) < 2:
        extracted = _extract_roman_sections(clean_text)

    # 4. Contents-guided unnumbered chapter headings (e.g., Dr. Jekyll and Mr. Hyde)
    if len(extracted) < 2:
        extracted = _extract_chapters_from_contents(clean_text)

    # 5. Single-chapter tale fallback
    if not extracted:
        normalized_body = _normalize_paragraphs(clean_text)
        words = len(normalized_body.split())
        extracted.append({
            "chapter_number": 1,
            "title": "Chapter I: The Complete Tale",
            "content": normalized_body,
            "word_count": words,
        })

    return extracted
