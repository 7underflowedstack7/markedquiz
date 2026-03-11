"""
Rule-based quiz generator that extracts questions from markdown content.

Strategies:
1. Header-based: Turn section headers into "What is..." questions
2. Definition-based: Extract "X is Y" patterns for fill-in-the-blank
3. List-based: Turn bullet lists into multiple choice
4. Bold/emphasis: Key terms become true/false or fill-in-blank
5. Code blocks: Ask about code snippets
"""

import re
import hashlib
import random
from app.schemas.quiz import Question, QuestionOption


def generate_quiz(title: str, content: str, max_questions: int = 10) -> list[dict]:
    """Generate quiz questions from markdown content."""
    questions: list[dict] = []

    sections = _parse_sections(content)

    # Strategy 1: Header-based questions
    questions.extend(_header_questions(sections))

    # Strategy 2: Definition extraction
    questions.extend(_definition_questions(content, sections))

    # Strategy 3: List-based multiple choice
    questions.extend(_list_questions(sections))

    # Strategy 4: Bold term questions
    questions.extend(_bold_term_questions(content, sections))

    # Strategy 5: True/False from statements
    questions.extend(_statement_true_false(sections))

    # Deduplicate and limit
    seen = set()
    unique = []
    for q in questions:
        key = q["question"][:80]
        if key not in seen:
            seen.add(key)
            unique.append(q)

    random.shuffle(unique)
    return unique[:max_questions]


def _make_id(text: str) -> str:
    return hashlib.md5(text.encode()).hexdigest()[:8]


def _parse_sections(content: str) -> list[dict]:
    """Split markdown into sections by headers."""
    lines = content.split("\n")
    sections = []
    current_header = "Introduction"
    current_body: list[str] = []

    for line in lines:
        header_match = re.match(r"^#{1,3}\s+(.+)", line)
        if header_match:
            if current_body:
                sections.append({
                    "header": current_header,
                    "body": "\n".join(current_body).strip(),
                    "lines": current_body,
                })
            current_header = header_match.group(1).strip()
            current_body = []
        else:
            current_body.append(line)

    if current_body:
        sections.append({
            "header": current_header,
            "body": "\n".join(current_body).strip(),
            "lines": current_body,
        })

    return sections


def _clean_text(text: str) -> str:
    """Remove markdown formatting."""
    text = re.sub(r"\*\*(.+?)\*\*", r"\1", text)
    text = re.sub(r"\*(.+?)\*", r"\1", text)
    text = re.sub(r"`(.+?)`", r"\1", text)
    text = re.sub(r"\[(.+?)\]\(.+?\)", r"\1", text)
    return text.strip()


def _extract_sentences(text: str) -> list[str]:
    """Extract clean sentences from text."""
    text = _clean_text(text)
    text = re.sub(r"```[\s\S]*?```", "", text)
    sentences = re.split(r"(?<=[.!?])\s+", text)
    return [s.strip() for s in sentences if len(s.strip()) > 20]


def _header_questions(sections: list[dict]) -> list[dict]:
    """Create questions from section headers."""
    questions = []
    for section in sections:
        header = section["header"]
        body = section["body"]
        if not body or len(body) < 30:
            continue

        sentences = _extract_sentences(body)
        if not sentences:
            continue

        first_sentence = sentences[0]

        # Create a "Which of the following best describes..." question
        qid = _make_id(f"header_{header}")
        correct = first_sentence[:150] if len(first_sentence) > 150 else first_sentence

        distractors = _generate_distractors_from_sections(sections, section, count=3)
        if len(distractors) < 2:
            continue

        options = [{"id": "a", "text": correct}]
        for i, d in enumerate(distractors[:3]):
            options.append({"id": chr(ord("b") + i), "text": d})
        random.shuffle(options)

        correct_id = next(o["id"] for o in options if o["text"] == correct)

        questions.append({
            "id": qid,
            "type": "multiple_choice",
            "question": f"Which of the following best describes '{_clean_text(header)}'?",
            "options": options,
            "correct_answer": correct_id,
            "explanation": f"As described in the '{header}' section: {correct}",
            "source_section": header,
        })

    return questions


def _definition_questions(content: str, sections: list[dict]) -> list[dict]:
    """Extract 'X is Y' definitions for fill-in-the-blank."""
    questions = []
    patterns = [
        r"(?:\*\*(.+?)\*\*)\s+(?:is|are|refers to|means)\s+(.+?)(?:\.|$)",
        r"(?:`(.+?)`)\s+(?:is|are|refers to|means)\s+(.+?)(?:\.|$)",
        r"^([A-Z][a-zA-Z\s]{2,30})\s+(?:is|are)\s+(?:a|an|the)\s+(.+?)(?:\.|$)",
    ]

    for section in sections:
        body = section["body"]
        for pattern in patterns:
            matches = re.finditer(pattern, body, re.MULTILINE)
            for match in matches:
                term = _clean_text(match.group(1))
                definition = _clean_text(match.group(2))

                if len(term) < 2 or len(definition) < 10:
                    continue

                qid = _make_id(f"def_{term}")
                questions.append({
                    "id": qid,
                    "type": "fill_blank",
                    "question": f"Complete the definition: ________ {match.group(0).split(term, 1)[-1][:100].strip()}",
                    "options": [
                        {"id": "a", "text": term},
                    ],
                    "correct_answer": term.lower(),
                    "explanation": f"'{term}' is defined in the '{section['header']}' section.",
                    "source_section": section["header"],
                })

    return questions


def _list_questions(sections: list[dict]) -> list[dict]:
    """Turn bullet lists into multiple choice questions."""
    questions = []

    for section in sections:
        items: list[str] = []
        for line in section["lines"]:
            match = re.match(r"^\s*[-*+]\s+(.+)", line)
            if match:
                items.append(_clean_text(match.group(1)))

        if len(items) < 3:
            continue

        header = section["header"]
        correct_item = random.choice(items)
        qid = _make_id(f"list_{header}_{correct_item[:20]}")

        all_items = items.copy()
        wrong_items = [i for i in all_items if i != correct_item]
        random.shuffle(wrong_items)

        options = [{"id": "a", "text": correct_item}]
        for i, w in enumerate(wrong_items[:2]):
            options.append({"id": chr(ord("b") + i), "text": w})
        options.append({"id": chr(ord("b") + len(wrong_items[:2])), "text": "None of the above"})

        random.shuffle(options)
        correct_id = next(o["id"] for o in options if o["text"] == correct_item)

        questions.append({
            "id": qid,
            "type": "multiple_choice",
            "question": f"Which of the following is listed under '{_clean_text(header)}'?",
            "options": options,
            "correct_answer": correct_id,
            "explanation": f"'{correct_item}' is one of the items listed in the '{header}' section.",
            "source_section": header,
        })

    return questions


def _bold_term_questions(content: str, sections: list[dict]) -> list[dict]:
    """Create questions from bold/emphasized terms."""
    questions = []
    bold_pattern = re.compile(r"\*\*(.+?)\*\*")

    for section in sections:
        body = section["body"]
        bold_terms = bold_pattern.findall(body)

        for term in bold_terms:
            if len(term) < 3 or len(term) > 50:
                continue

            # Find the sentence containing this term
            sentences = _extract_sentences(body)
            context_sentence = None
            for s in sentences:
                if term.lower() in s.lower():
                    context_sentence = s
                    break

            if not context_sentence:
                continue

            qid = _make_id(f"bold_{term}")
            blanked = context_sentence.replace(term, "________")

            questions.append({
                "id": qid,
                "type": "fill_blank",
                "question": f"Fill in the blank: {blanked}",
                "options": [{"id": "a", "text": term}],
                "correct_answer": term.lower(),
                "explanation": f"The answer is '{term}' as stated in the '{section['header']}' section.",
                "source_section": section["header"],
            })

    return questions


def _statement_true_false(sections: list[dict]) -> list[dict]:
    """Create true/false questions from definitive statements."""
    questions = []

    for section in sections:
        sentences = _extract_sentences(section["body"])

        for sentence in sentences:
            # Look for definitive statements
            if not any(kw in sentence.lower() for kw in [
                "always", "never", "must", "should", "important",
                "required", "necessary", "key", "essential", "primary",
                "is a", "is the", "are the", "can be"
            ]):
                continue

            if len(sentence) < 20 or len(sentence) > 200:
                continue

            qid = _make_id(f"tf_{sentence[:30]}")
            questions.append({
                "id": qid,
                "type": "true_false",
                "question": f"True or False: {sentence}",
                "options": [
                    {"id": "true", "text": "True"},
                    {"id": "false", "text": "False"},
                ],
                "correct_answer": "true",
                "explanation": f"This statement is true as described in the '{section['header']}' section.",
                "source_section": section["header"],
            })

    return questions


def _generate_distractors_from_sections(
    all_sections: list[dict], current_section: dict, count: int = 3
) -> list[str]:
    """Generate plausible wrong answers from other sections."""
    distractors = []

    for section in all_sections:
        if section["header"] == current_section["header"]:
            continue
        sentences = _extract_sentences(section["body"])
        for s in sentences:
            if len(s) > 20:
                distractors.append(s[:150] if len(s) > 150 else s)

    random.shuffle(distractors)
    return distractors[:count]
