#!/usr/bin/env bash
cd "$(dirname "$0")"
conda run -n k8s-deploy --no-banner uvicorn main:app --reload --host 0.0.0.0 --port 8000
