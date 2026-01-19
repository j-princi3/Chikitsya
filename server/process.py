import pdfplumber
import requests

ANALYZER_URL = "http://192.168.1.4:5002/analyze"
ANONYMIZER_URL = "http://192.168.1.4:5001/anonymize"

ALLOWED_ENTITIES = {
    "PERSON",
    "PHONE_NUMBER",
    "EMAIL_ADDRESS",
    "LOCATION"
}

# ---------------------------
# 1. Extract text from PDF
# ---------------------------
def extract_text_from_pdf(file_path: str) -> str:
    text = ""
    with pdfplumber.open(file_path) as pdf:
        for page in pdf.pages:
            page_text = page.extract_text()
            if page_text:
                text += page_text + "\n"
    return text.strip()

# ---------------------------
# 2. Analyze with Presidio
# ---------------------------
def analyze_text(text: str):
    res = requests.post(
        ANALYZER_URL,
        json={"text": text, "language": "en"}
    )
    res.raise_for_status()
    return res.json()

# ---------------------------
# 3. Filter healthcare-safe entities
# ---------------------------
def filter_entities(results):
    return [
        r for r in results
        if r.get("entity_type") in ALLOWED_ENTITIES and r.get("score", 0) > 0.6
    ]

# ---------------------------
# 4. Anonymize text
# ---------------------------
def anonymize_text(text: str, analyzer_results):
    if not analyzer_results:
        return text  # nothing to anonymize

    res = requests.post(
        ANONYMIZER_URL,
        json={
            "text": text,
            "analyzer_results": analyzer_results,
            "anonymizers": {
                "DEFAULT": {
                    "type": "replace",
                    "new_value": "<REDACTED>"
                }
            }
        }
    )
    res.raise_for_status()
    return res.json()["text"]

# ---------------------------
# 5. Full pipeline helper
# ---------------------------
def process_pdf(file_path: str) -> str:
    raw_text = extract_text_from_pdf(file_path)
    analyzer_results = analyze_text(raw_text)
    filtered_results = filter_entities(analyzer_results)
    anonymized_text = anonymize_text(raw_text, filtered_results)
    return anonymized_text
