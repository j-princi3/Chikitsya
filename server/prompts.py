CARE_PLAN_PROMPT = """
### ROLE
You are a medical assistant extracting a care plan in FHIR JSON format.

### OUTPUT SCHEMA
Return a FHIR Bundle JSON object with type "document", containing a Composition resource for the discharge summary, and referenced resources for medications, follow_up, warnings, diet, activity.

Use the following structure:

{
  "resourceType": "Bundle",
  "type": "document",
  "entry": [
    {
      "resource": {
        "resourceType": "Composition",
        "status": "final",
        "type": {
          "coding": [
            {
              "system": "http://loinc.org",
              "code": "18842-5",
              "display": "Discharge summary"
            }
          ]
        },
        "subject": {
          "reference": "Patient/1"
        },
        "section": [
          {
            "title": "Medications",
            "code": {
              "coding": [
                {
                  "system": "http://loinc.org",
                  "code": "10160-0",
                  "display": "History of medication use"
                }
              ]
            },
            "entry": [
              {"reference": "MedicationRequest/1"},
              {"reference": "MedicationRequest/2"},
              ...
            ]
          },
          {
            "title": "Follow-up",
            "entry": [
              {"reference": "Appointment/1"},
              ...
            ]
          },
          {
            "title": "Warnings",
            "entry": [
              {"reference": "Observation/1"},
              ...
            ]
          },
          {
            "title": "Diet",
            "entry": [
              {"reference": "NutritionOrder/1"},
              ...
            ]
          },
          {
            "title": "Activity",
            "entry": [
              {"reference": "CarePlan/1"},
              ...
            ]
          }
        ]
      }
    },
    {
      "resource": {
        "resourceType": "MedicationRequest",
        "id": "1",
        "status": "active",
        "medicationCodeableConcept": {
          "text": "Drug Name"
        },
        "dosageInstruction": [
          {
            "text": "Dosage and timing",
            "timing": {
              "repeat": {
                "frequency": 2,
                "period": 1,
                "periodUnit": "d"
              }
            }
          }
        ],
        "exact_time": ["8:00 AM", "5:10 PM"]
      }
    },
    {
      "resource": {
        "resourceType": "Appointment",
        "id": "1",
        "status": "booked",
        "description": "Follow-up instruction"
      }
    },
    {
      "resource": {
        "resourceType": "Observation",
        "id": "1",
        "status": "final",
        "code": {
          "text": "Warning"
        },
        "valueString": "Warning text"
      }
    },
    {
      "resource": {
        "resourceType": "NutritionOrder",
        "id": "1",
        "status": "active",
        "oralDiet": {
          "instruction": "Diet instruction"
        }
      }
    },
    {
      "resource": {
        "resourceType": "CarePlan",
        "id": "1",
        "status": "active",
        "description": {
          "text": "Activity instruction"
        }
      }
    }
  ]
}

Ensure the entry array contains the Composition and all referenced resources. Use sequential IDs.

### INPUT TEXT:
"""