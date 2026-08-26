import json
import os
import io
from fastapi import FastAPI, File, UploadFile, Form, HTTPException
from fastapi.middleware.cors import CORSMiddleware
import google.generativeai as genai
from PIL import Image

app = FastAPI(title="Artisan Smart Cataloging Engine")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

api_key = os.environ.get("GEMINI_API_KEY")
if api_key:
    genai.configure(api_key=api_key)

@app.get("/")
def read_root():
    return {"status": "Backend Server Operational"}

@app.post("/api/catalog/auto-generate")
async def generate_catalog(
    image: UploadFile = File(...),
    raw_audio_notes: str = Form(""),
    material_cost: float = Form(...),
    hours_worked: float = Form(...)
):
    if not os.environ.get("GEMINI_API_KEY"):
        raise HTTPException(status_code=500, detail="GEMINI_API_KEY environment variable is not set.")

    try:
        image_bytes = await image.read()
        pil_image = Image.open(io.BytesIO(image_bytes))

        model = genai.GenerativeModel('gemini-1.5-flash')
        
        prompt = f"""
        You are an expert handicraft cataloger and fair-trade evaluator. Analyze this product image along with the artisan's input.

        Artisan Inputs:
        - Voice Notes / Context: "{raw_audio_notes}"
        - Material Cost (INR): {material_cost}
        - Hours Worked: {hours_worked}

        Perform the following:
        1. Identify the craft type, materials used, and traditional origin.
        2. Create a high-converting product title and a compelling story description.
        3. Recommend a Fair Price (INR) using formula: Material Cost + (Hours Worked * Base Rate 200 INR/hr) + 15% Artisan Margin.
        4. Provide relevant search tags.

        Return ONLY a JSON object with this exact schema:
        {{
            "title": "String",
            "category": "String",
            "craft_type": "String",
            "materials": ["String"],
            "description": "String",
            "story": "String",
            "recommended_price_inr": 0.0,
            "tags": ["String"]
        }}
        """

        response = model.generate_content(
            [prompt, pil_image],
            generation_config={"response_mime_type": "application/json"}
        )

        catalog_data = json.loads(response.text)
        return {"status": "success", "data": catalog_data}

    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
