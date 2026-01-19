from google import genai
from google.genai import types
from dotenv import load_dotenv
import os
import json
import hashlib
from prompts import CARE_PLAN_PROMPT

load_dotenv()

client = genai.Client(
    api_key=os.getenv("GEMINI_API_KEY")
)

# ---------------------------
# In-memory cache (demo-safe)
# ---------------------------
_CACHE = {}

# ---------------------------
# INTERNAL: Actual Gemini call
# ---------------------------
def _generate_care_plan_uncached(discharge_text: str, language: str = "English") -> dict:
    print("Gemini API call (uncached)")

    # Language handling
    if language == "Hindi":
        language_instruction = (
            "Translate the content (medication names, descriptions, instructions) to Hindi, "
            "but keep section titles and all JSON keys in English."
        )
    elif language == "Telugu":
        language_instruction = (
            "Translate the content (medication names, descriptions, instructions) to Telugu, "
            "but keep section titles and all JSON keys in English."
        )
    else:
        language_instruction = "Generate the care plan in English."

    full_prompt = (
        CARE_PLAN_PROMPT
        + f"\n\n{language_instruction}\n\nDischarge Summary:\n{discharge_text}"
    )

    response = client.models.generate_content(
        model="gemini-3-flash-preview",  #  cheaper & sufficient
        contents=full_prompt,
        config=types.GenerateContentConfig(
            response_mime_type="application/json",
            temperature=0.0,
        )
    )

    if response.candidates and response.candidates[0].content.parts:
        text = response.candidates[0].content.parts[0].text
        return json.loads(text)

    return {"error": "No content in Gemini response"}

# ---------------------------
# PUBLIC: Cached version
# ---------------------------
def generate_care_plan(discharge_text: str, language: str = "English") -> dict:
    """
    Cached Gemini call to prevent quota exhaustion.
    This is the function app.py should call.
    """
    import hashlib
    
    cache_key = hashlib.sha256(
        (discharge_text + language).encode("utf-8")
    ).hexdigest()

    # Try to get from cache first
    try:
        # This would be called from Flutter app via API
        # For now, we'll use a simple in-memory cache as fallback
        if cache_key in _CACHE:
            print("⚡ Gemini cache hit")
            return _CACHE[cache_key]
    except:
        pass

    print("❌ Gemini cache miss")
    result = _generate_care_plan_uncached(discharge_text, language)
    
    # Store in memory cache as fallback
    _CACHE[cache_key] = result
    
    return result

# ---------------------------
# Q&A endpoint (optional cache)
# ---------------------------
def answer_query(query: str, language: str, summary: str) -> str:
    prompt = f"""
You are a medical assistant. Answer the user's query based on the provided discharge summary.
Be helpful, accurate, and concise. Respond in {language}.

Discharge Summary:
{summary}

Query: {query}
"""

    response = client.models.generate_content(
        model="gemini-3-flash-preview",
        contents=prompt,
        config=types.GenerateContentConfig(
            temperature=0.0,
        )
    )

    if response.candidates and response.candidates[0].content.parts:
        return response.candidates[0].content.parts[0].text.strip()

    return "Sorry, I could not answer your query."

# ---------------------------
# Chat Title Generation
# ---------------------------
def generate_chat_title(discharge_summary: str, language: str = "English") -> str:
    """
    Generate a concise, meaningful title for a chat session based on the discharge summary.
    """
    prompt = f"""
Based on the following discharge summary, generate a concise and meaningful title for a medical chat session.
The title should be 3-7 words long, capture the main medical condition or purpose, and be appropriate for a patient care context.
Respond in {language}.

Discharge Summary:
{discharge_summary}

Title:"""

    try:
        response = client.models.generate_content(
            model="gemini-3-flash-preview",
            contents=prompt,
            config=types.GenerateContentConfig(
                temperature=0.3,  # Slightly creative for title generation
                max_output_tokens=50,  # Keep it short
            )
        )

        if response.candidates and response.candidates[0].content.parts:
            title = response.candidates[0].content.parts[0].text.strip()
            # Clean up the title (remove quotes, extra whitespace)
            title = title.strip('"\'').strip()
            # Ensure it's not too long
            if len(title.split()) > 10:
                title = ' '.join(title.split()[:7]) + '...'
            return title

    except Exception as e:
        print(f"Error generating chat title: {e}")

    # Fallback title
    return "Medical Consultation"

# ---------------------------
# Text Translation
# ---------------------------
def translate_text_with_gemini(text: str, source_language: str, target_language: str) -> str:
    """
    Translate text from source language to target language using Gemini.
    """
    if source_language == target_language:
        return text

    prompt = f"""
Translate the following text from {source_language} to {target_language}.
Keep medical terms and proper names unchanged. Maintain the original meaning and tone.

Text to translate:
{text}

Translation:"""

    try:
        response = client.models.generate_content(
            model="gemini-3-flash-preview",
            contents=prompt,
            config=types.GenerateContentConfig(
                temperature=0.1,  # Low temperature for accurate translation
                max_output_tokens=1000,
            )
        )

        if response.candidates and response.candidates[0].content.parts:
            translated_text = response.candidates[0].content.parts[0].text.strip()
            return translated_text

    except Exception as e:
        print(f"Error translating text: {e}")

    # Fallback: return original text
    return text
