import json
import re

def extract_json(text: str):
    """
    Safely extract JSON from Gemini response
    """
    try:
        return json.loads(text)
    except json.JSONDecodeError:
        match = re.search(r"\{.*\}", text, re.DOTALL)
        if match:
            return json.loads(match.group())
        raise ValueError("Invalid JSON returned by Gemini")

def extract_medications(text: str):
    meds = []

    pattern = re.compile(
        r'''
        \d*\.*\s*                 # optional numbering (1. 2.)
        (Tab|Tablet|Cap|Capsule)\s+
        ([A-Za-z]+)\s+            # Medicine name
        (\d+\s*mg)\s*             # Dosage (handles "500 mg")
        [–\-]?\s*Take\s*
        (once|twice|three times)\s+daily
        (.*?)$                    # notes (after timing)
        ''',
        re.IGNORECASE | re.MULTILINE | re.VERBOSE
    )

    for m in pattern.finditer(text):
        meds.append({
            "name": m.group(2).capitalize(),
            "dosage": m.group(3),
            "timing": m.group(4).lower() + " daily",
            "notes": m.group(5).strip()
        })

    return meds

def extract_list_section(text: str, section_name: str):
    pattern = re.compile(
        rf'{section_name}:\s*(.*?)(?:\n\n|\Z)',
        re.IGNORECASE | re.DOTALL
    )

    match = pattern.search(text)
    if not match:
        return []

    lines = match.group(1).splitlines()
    cleaned = []

    for l in lines:
        l = l.strip()
        if l and not l.lower().startswith(section_name.lower()):
            cleaned.append(l.lstrip("•-1234567890. "))

    return cleaned
