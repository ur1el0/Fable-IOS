import re


def _normalize_paragraphs(text: str) -> str:
    cleaned = re.sub(r'\[Illustration\]', '', text, flags=re.IGNORECASE)
    paragraphs = [
        re.sub(r'\s+', ' ', para.strip())
        for para in re.split(r'\n{2,}', cleaned)
        if para.strip()
    ]
    return "\n\n".join(paragraphs)


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

    # Match standard Chapter markers or Roman numeral story headers
    pattern = r'(?:^|\n{2,})(CHAPTER\s+[0-9IVXLCDM]+[^\n]*|Chapter\s+[0-9IVXLCDM]+[^\n]*|ACT\s+[0-9IVXLCDM]+[^\n]*|BOOK\s+[0-9IVXLCDM]+[^\n]*|[IVXLCDM]+\.\s+[A-Z][^\n]{2,80})'
    splits = re.split(pattern, clean_text)

    extracted: list[dict] = []
    if len(splits) > 2:
        chapter_idx = 1
        for i in range(1, len(splits), 2):
            ch_title = splits[i].strip().rstrip("]").strip()
            ch_body = splits[i+1].strip() if i+1 < len(splits) else ""
            # Filter out table of contents listings
            if len(ch_body.strip()) >= 50 and ch_body.count("CHAPTER ") < 3 and ch_body.count("Chapter ") < 3:
                normalized_body = _normalize_paragraphs(ch_body)
                words = len(normalized_body.split())
                if words > 0:
                    extracted.append({
                        "chapter_number": chapter_idx,
                        "title": ch_title,
                        "content": normalized_body,
                        "word_count": words
                    })
                    chapter_idx += 1

    # Fallback to Roman numeral markers (\n\nI\n\n, \n\nII\n\n)
    if not extracted:
        roman_pattern = r'\n{2,}([IVXLCDM]+)\s*\n{2,}'
        roman_splits = re.split(roman_pattern, clean_text)
        if len(roman_splits) > 2:
            chapter_idx = 1
            for i in range(1, len(roman_splits), 2):
                ch_title = f"Chapter {roman_splits[i].strip()}"
                ch_body = roman_splits[i+1].strip() if i+1 < len(roman_splits) else ""
                if len(ch_body.strip()) >= 50:
                    normalized_body = _normalize_paragraphs(ch_body)
                    words = len(normalized_body.split())
                    if words > 0:
                        extracted.append({
                            "chapter_number": chapter_idx,
                            "title": ch_title,
                            "content": normalized_body,
                            "word_count": words
                        })
                        chapter_idx += 1

    # Single-chapter tale fallback
    if not extracted:
        normalized_body = _normalize_paragraphs(clean_text)
        words = len(normalized_body.split())
        extracted.append({
            "chapter_number": 1,
            "title": "Chapter I: The Complete Tale",
            "content": normalized_body,
            "word_count": words
        })

    return extracted
