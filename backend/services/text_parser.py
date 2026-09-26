import re

def extract_chapters_from_text(raw_text: str) -> list[dict]:
    """
    Parses raw full-length text from Project Gutenberg or external literary sites,
    stripping boilerplate licenses and splitting on structural chapter boundaries.
    """
    start_match = re.search(r'\*\*\*\s*START OF (THE|THIS) PROJECT GUTENBERG EBOOK[^\*]*\*\*\*', raw_text, re.IGNORECASE)
    end_match = re.search(r'\*\*\*\s*END OF (THE|THIS) PROJECT GUTENBERG EBOOK', raw_text, re.IGNORECASE)

    start_pos = start_match.end() if start_match else 0
    end_pos = end_match.start() if end_match else len(raw_text)
    clean_text = raw_text[start_pos:end_pos].strip()

    # Match standard Chapter markers
    pattern = r'(?:^|(?:\r?\n){2,})(CHAPTER\s+[0-9IVXLCDM]+[^\r\n]*|Chapter\s+[0-9IVXLCDM]+[^\r\n]*|ACT\s+[0-9IVXLCDM]+[^\r\n]*|BOOK\s+[0-9IVXLCDM]+[^\r\n]*)'
    splits = re.split(pattern, clean_text)

    extracted: list[dict] = []
    if len(splits) > 2:
        chapter_idx = 1
        for i in range(1, len(splits), 2):
            ch_title = splits[i].strip()
            ch_body = splits[i+1].strip() if i+1 < len(splits) else ""
            # Filter out table of contents listings
            if len(ch_body.strip()) >= 50 and ch_body.count("CHAPTER ") < 3 and ch_body.count("Chapter ") < 3:
                words = len(ch_body.split())
                extracted.append({
                    "chapter_number": chapter_idx,
                    "title": ch_title,
                    "content": ch_body,
                    "word_count": words
                })
                chapter_idx += 1

    # Fallback to Roman numeral markers (\n\nI\n\n, \n\nII\n\n)
    if not extracted:
        roman_pattern = r'(?:\r?\n){2,}([IVXLCDM]+)\s*(?:\r?\n){2,}'
        roman_splits = re.split(roman_pattern, clean_text)
        if len(roman_splits) > 2:
            chapter_idx = 1
            for i in range(1, len(roman_splits), 2):
                ch_title = f"Chapter {roman_splits[i].strip()}"
                ch_body = roman_splits[i+1].strip() if i+1 < len(roman_splits) else ""
                if len(ch_body.strip()) >= 50:
                    words = len(ch_body.split())
                    extracted.append({
                        "chapter_number": chapter_idx,
                        "title": ch_title,
                        "content": ch_body,
                        "word_count": words
                    })
                    chapter_idx += 1

    # Single-chapter tale fallback
    if not extracted:
        words = len(clean_text.split())
        extracted.append({
            "chapter_number": 1,
            "title": "Chapter I: The Complete Tale",
            "content": clean_text,
            "word_count": words
        })

    return extracted
