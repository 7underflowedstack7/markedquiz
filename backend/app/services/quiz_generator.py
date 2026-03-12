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

        qid = hashlib.md5(f"{title}_{i}_{q_text[:50]}".encode()).hexdigest()[:8]

        # Check if the question has A/B/C/D options
        question_stem, options = _parse_multiple_choice(q_text)

        if not options:
            # Skip non-multiple-choice questions
            continue

        correct_letter = _extract_correct_letter(answer_text)
        questions.append({
            "id": qid,
            "type": "multiple_choice",
            "question": question_stem.strip(),
            "options": options,
            "correct_answer": correct_letter or "",
            "keywords": [],
            "explanation": answer_text.strip(),
            "source_section": "Questions",
        })

    return questions


def _parse_multiple_choice(q_text: str) -> tuple[str, list[dict]]:
    """Parse A/B/C/D options from question text. Returns (stem, options list).
    If no options found, returns (q_text, [])."""
    # Match lines like "A) ...", "B) ...", etc.
    option_pattern = re.compile(r"^\s*([A-D])\)\s+(.+)", re.MULTILINE)
    matches = list(option_pattern.finditer(q_text))

    if not matches:
        return q_text, []

    # Everything before the first option is the question stem
    stem = q_text[:matches[0].start()].strip()
    options = [{"id": m.group(1), "text": m.group(2).strip()} for m in matches]
    return stem, options


def _extract_correct_letter(answer_text: str) -> str | None:
    """Extract the correct answer letter from answer text like '**B** — ...'."""
    match = re.match(r"\*\*([A-D])\*\*", answer_text.strip())
    return match.group(1) if match else None


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
                items.append("\n".join(current))
            current = [num_match.group(2).strip()]
        elif line.strip() and current:
            current.append(line.strip())

    if current:
        items.append("\n".join(current))

    return items


