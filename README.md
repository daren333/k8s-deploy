# YOLOv8n FastAPI Service

A small FastAPI service that serves a **YOLOv8n** model for object detection (COCO weights, 80 classes).

## Setup

```bash
conda env create -f environment.yml
conda activate k8s-deploy
```

## Run

```bash
conda activate k8s-deploy
uvicorn main:app --reload --host 0.0.0.0 --port 8000
```

Or without activating:

```bash
./run.sh
```

- API docs: http://localhost:8000/docs
- Health: http://localhost:8000/health

## Endpoints

| Method | Path       | Description                            |
|--------|------------|----------------------------------------|
| GET    | `/`        | Service info and links                 |
| GET    | `/health`  | Health check                           |
| POST   | `/predict` | Detect objects in an image (80 COCO classes) |

### POST /predict

- **Body**: `multipart/form-data` with an image file (e.g. JPEG, PNG).
- **Query** (optional): `confidence` (default `0.25`) — minimum confidence threshold (0–1).

**Example with curl:**

```bash
curl -X POST "http://localhost:8000/predict?confidence=0.5" \
  -F "file=@/path/to/your/image.jpg"
```

**Example response:**

```json
{
  "num_detections": 3,
  "detections": [
    { "class_name": "person", "confidence": 0.9234, "bbox": [120.5, 45.2, 380.1, 520.8] },
    { "class_name": "dog", "confidence": 0.8712, "bbox": [400.0, 300.5, 600.3, 510.2] },
    { "class_name": "chair", "confidence": 0.6521, "bbox": [10.0, 200.0, 150.5, 450.3] }
  ]
}
```

Bounding boxes are in `[x_min, y_min, x_max, y_max]` pixel coordinates. The model uses **COCO** (80 classes). Weights are downloaded automatically on first run (~6 MB).

## Deploying to GCP (via K8s)

set billing id as env variable
```bash
export BILLING_ID=<GCP-billing-id>
```
run setup script from terraform directory:
```bash
cd terraform && ./setup.sh
```

To tear down:
```bash
./cleanup.sh
```
