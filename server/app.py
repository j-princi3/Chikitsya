from flask import Flask, request, jsonify
from flask_cors import CORS
# 1. Make sure this import matches your filename
from gemini_service import generate_care_plan, answer_query, generate_chat_title, translate_text_with_gemini 
import tempfile
import os
from process import process_pdf

app = Flask(__name__)
CORS(app)

@app.route("/health", methods=["GET"])
def health():
    return {"status": "Chikitsya backend running"}

@app.route("/generate-care-plan", methods=["POST"])
def generate():
    data = request.get_json(force=True, silent=True)

    if not data or "discharge_text" not in data:
        return jsonify({"error": "discharge_text is required"}), 400

    raw_text = data["discharge_text"]
    language = data.get("language", "English")

    print(f" Received raw text length: {len(raw_text)}, language: {language}")

    try:
        # 1) De-identify text BEFORE Gemini
        from process import analyze_text, filter_entities, anonymize_text

        analyzer_results = analyze_text(raw_text)
        filtered_results = filter_entities(analyzer_results)
        anonymized_text = anonymize_text(raw_text, filtered_results)

        print("De-identified text is :", anonymized_text)

        # 2) Send ONLY anonymized text to Gemini
        care_plan = generate_care_plan(anonymized_text, language)

        return jsonify(care_plan)

    except Exception as e:
        print(f" Error generating plan: {e}")
        return jsonify({"error": str(e)}), 500

@app.route("/voice-query", methods=["POST"])
def voice_query():
    data = request.get_json(force=True, silent=True)

    if not data or "query" not in data or "summary" not in data:
        return jsonify({"error": "query and summary are required"}), 400

    query = data["query"]
    language = data.get("language", "English")
    summary = data["summary"]
    
    print(f"Voice query: {query}, language: {language}")

    try:
        # De-identify the summary text before sending to Gemini
        from process import analyze_text, filter_entities, anonymize_text

        analyzer_results = analyze_text(summary)
        filtered_results = filter_entities(analyzer_results)
        deidentified_summary = anonymize_text(summary, filtered_results)

        # Log the de-identified text for user confirmation
        print("=== DE-IDENTIFIED TEXT FOR GEMINI ===")
        print(deidentified_summary)
        print("=====================================")

        response = answer_query(query, language, deidentified_summary)
        return jsonify({"response": response})
    except Exception as e:
        error_str = str(e)
        if "RESOURCE_EXHAUSTED" in error_str or "429" in error_str:
            return jsonify({"error": "API quota exceeded. Please try again later or upgrade your Gemini API plan."}), 429
        print(f"Error answering query: {e}")
        return jsonify({"response": response})
    except Exception as e:
        error_str = str(e)
        if "RESOURCE_EXHAUSTED" in error_str or "429" in error_str:
            return jsonify({"error": "API quota exceeded. Please try again later or upgrade your Gemini API plan."}), 429
        print(f"Error answering query: {e}")
        return jsonify({"error": str(e)}), 500

@app.route("/generate-chat-title", methods=["POST"])
def generate_chat_title_endpoint():
    data = request.get_json(force=True, silent=True)

    if not data or "discharge_summary" not in data:
        return jsonify({"error": "discharge_summary is required"}), 400

    discharge_summary = data["discharge_summary"]
    language = data.get("language", "English")

    try:
        title = generate_chat_title(discharge_summary, language)
        return jsonify({"title": title})
    except Exception as e:
        print(f"Error generating chat title: {e}")
        return jsonify({"error": str(e)}), 500

@app.route("/translate-text", methods=["POST"])
def translate_text():
    data = request.get_json(force=True, silent=True)

    if not data or "text" not in data or "target_language" not in data:
        return jsonify({"error": "text and target_language are required"}), 400

    text = data["text"]
    target_language = data["target_language"]
    source_language = data.get("source_language", "auto")

    try:
        translated_text = translate_text_with_gemini(text, source_language, target_language)
        return jsonify({"translated_text": translated_text})
    except Exception as e:
        print(f"Error translating text: {e}")
        return jsonify({"error": str(e)}), 500

@app.route("/report-symptoms", methods=["POST"])
def report_symptoms():
    data = request.get_json(force=True)

    symptoms = data.get("symptoms", [])
    other = data.get("other_symptoms", "").lower()

    high_risk = {"fever", "breathing difficulty", "chest pain"}

    is_critical = any(
        s.lower() in high_risk for s in symptoms
    ) or any(
        k in other for k in high_risk
    )

    if is_critical:
        return (
            "Your symptoms may require medical attention. "
            "Please contact your doctor or visit the nearest hospital."
        )

    return (
        "Thank you for reporting. Continue your medications and "
        "monitor symptoms. Contact your doctor if they worsen."
    )

@app.route("/process-discharge-pdf", methods=["POST"])
def process_discharge_pdf():
    if "file" not in request.files:
        return jsonify({"error": "No file uploaded"}), 400

    file = request.files["file"]

    with tempfile.NamedTemporaryFile(delete=False, suffix=".pdf") as tmp:
        file.save(tmp.name)
        tmp_path = tmp.name

    try:
        anonymized_text = process_pdf(tmp_path)

        return jsonify({
            "status": "success",
            "anonymized_text": anonymized_text
        })

    except Exception as e:
        print(f"PDF processing error: {e}")
        return jsonify({"error": str(e)}), 500

    finally:
        os.remove(tmp_path)

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000, debug=True)