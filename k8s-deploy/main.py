"""
FastAPI service exposing a lightweight YOLOv8n model for object detection.
"""

import datetime
import io
from contextlib import asynccontextmanager

from fastapi import FastAPI, File, HTTPException, UploadFile
from PIL import Image
from ultralytics import YOLO
import os

# Get paths from environment variables (set in deployment.yml)
weights_path = os.getenv("WEIGHTS_PATH", "yolov8n.pt")
log_path = os.getenv("LOG_FILE_PATH", "/data/predictions.log")

_model = None


def load_model():
    global _model
    if _model is None:
        _model = YOLO("yolov8n.pt")
    return _model


@asynccontextmanager
async def lifespan(app: FastAPI):
    load_model()
    yield


app = FastAPI(
    title="YOLOv8n Object Detector",
    description="Detect objects in images using a lightweight YOLOv8n model (COCO).",
    lifespan=lifespan,
)


@app.get("/")
async def root():
    return {
        "message": "YOLOv8n Object Detector",
        "docs": "/docs",
        "predict": "POST /predict with an image file",
    }


@app.get("/health")
async def health():
    return {"status": "ok", "model": "YOLOv8n"}


@app.post("/predict")
async def predict(
    file: UploadFile = File(..., description="Image file to run detection on (e.g. JPEG, PNG)"),
    confidence: float = 0.25,
):
    """
    Detect objects in an image using YOLOv8n (COCO, 80 classes).
    Returns detected objects with bounding boxes, class names, and confidence scores.
    """
    if not 0.0 < confidence <= 1.0:
        raise HTTPException(status_code=400, detail="confidence must be between 0 and 1")

    content_type = file.content_type or ""
    if "image" not in content_type and not file.filename:
        raise HTTPException(
            status_code=400,
            detail="Upload a valid image file (e.g. image/jpeg, image/png).",
        )

    try:
        image_bytes = await file.read()
    except Exception as e:
        raise HTTPException(status_code=400, detail=f"Failed to read file: {e}")

    if not image_bytes:
        raise HTTPException(status_code=400, detail="Empty file.")

    try:
        img = Image.open(io.BytesIO(image_bytes))
        if img.mode != "RGB":
            img = img.convert("RGB")
    except Exception as e:
        raise HTTPException(
            status_code=400, detail=f"Invalid or unsupported image: {e}"
        )

    model = load_model()
    results = model.predict(img, conf=confidence, verbose=False)
    result = results[0]

    detections = []
    for box in result.boxes:
        detections.append(
            {
                "class_name": result.names[int(box.cls)],
                "confidence": round(float(box.conf), 4),
                "bbox": [round(float(c), 1) for c in box.xyxy[0]],
            }
        )
    
    # Record the data for the sidecar
    with open(log_path, "a") as f:
        for detection in detections:
            # Save: timestamp, filename, confidence, label, bounding box
            f.write(f"{datetime.now()}, {file.filename}, {detection.confidence}, {detection.class_name}, {detection.bbox}\n")
            
    return {
        "num_detections": len(detections),
        "detections": detections,
    }
