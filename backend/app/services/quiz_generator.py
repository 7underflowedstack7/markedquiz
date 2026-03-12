"""
Quiz generator that extracts questions from markdown content.

Expects markdown with:
- ## Questions — numbered list of questions
- ## Answers Hidden — numbered list of corresponding answers

Scoring uses keyword extraction from answers.
"""

import re
import hashlib


def generate_quiz(title: str, content: str, max_questions: int = 25) -> list[dict]:
    """Extract questions and answers from markdown content."""
    questions_text = _extract_section(content, "Questions")
    answers_text = _extract_section(content, "Answers Hidden")

    if not questions_text:
        return []

    raw_questions = _parse_numbered_items(questions_text)
    raw_answers = _parse_numbered_items(answers_text) if answers_text else []

    questions = []
    for i, q_text in enumerate(raw_questions[:max_questions]):
        answer_text = raw_answers[i] if i < len(raw_answers) else ""
        keywords = _extract_keywords(answer_text) if answer_text else []

        qid = hashlib.md5(f"{title}_{i}_{q_text[:50]}".encode()).hexdigest()[:8]

        questions.append({
            "id": qid,
            "type": "free_response",
            "question": q_text.strip(),
            "options": [],
            "correct_answer": answer_text.strip(),
            "keywords": keywords,
            "explanation": answer_text.strip(),
            "source_section": "Questions",
        })

    return questions


def _extract_section(content: str, section_name: str) -> str | None:
    """Extract text under a ## heading until the next ## heading or end of file."""
    pattern = rf"^## {re.escape(section_name)}\s*\n(.*?)(?=^## |\Z)"
    match = re.search(pattern, content, re.MULTILINE | re.DOTALL)
    if match:
        return match.group(1).strip()
    return None


def _parse_numbered_items(text: str) -> list[str]:
    """Parse numbered items (1. ..., 2. ...) from text, handling multi-line items."""
    items = []
    current = []

    for line in text.split("\n"):
        num_match = re.match(r"^\s*(\d+)\.\s+(.*)", line)
        if num_match:
            if current:
                items.append(" ".join(current))
            current = [num_match.group(2).strip()]
        elif line.strip() and current:
            current.append(line.strip())

    if current:
        items.append(" ".join(current))

    return items


def _extract_keywords(answer: str) -> list[str]:
    """Extract key terms from an answer for keyword-based scoring."""
    # Remove markdown formatting
    clean = re.sub(r"\*\*(.+?)\*\*", r"\1", answer)
    clean = re.sub(r"`(.+?)`", r"\1", clean)
    clean = re.sub(r"\[(.+?)\]\(.+?\)", r"\1", clean)

    keywords = []

    # Extract backtick terms (SQL commands, code) from original
    code_terms = re.findall(r"`([^`]+)`", answer)
    keywords.extend(code_terms)

    # Extract bold terms from original
    bold_terms = re.findall(r"\*\*([^*]+)\*\*", answer)
    keywords.extend(bold_terms)

    # Extract ALL_CAPS terms (e.g. SELECT, JOIN, WHERE)
    caps_terms = re.findall(r"\b([A-Z]{2,}(?:\s+[A-Z]{2,})*)\b", clean)
    keywords.extend(caps_terms)

    # Extract key technical phrases — words near "is", "means", "refers to"
    definition_matches = re.findall(
        r"(\b\w+(?:\s+\w+){0,2})\s+(?:is|are|means|refers to)\b",
        clean, re.IGNORECASE
    )
    keywords.extend(definition_matches)

    # Deduplicate, lowercase, filter short terms
    seen = set()
    unique = []
    for kw in keywords:
        kw_lower = kw.strip().lower()
        if len(kw_lower) >= 2 and kw_lower not in seen:
            seen.add(kw_lower)
            unique.append(kw_lower)

    return unique
