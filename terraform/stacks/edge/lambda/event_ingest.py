import json
import os
import uuid
import boto3

sqs = boto3.client("sqs")
QUEUE_URL = os.environ["QUEUE_URL"]
REGION = os.environ["AWS_REGION"]


def _response(code, body):
    return {
        "statusCode": code,
        "headers": {
            "Content-Type": "application/json",
            "X-Served-Region": REGION,
            "X-Correlation-Id": body.get("correlationId", str(uuid.uuid4())),
        },
        "body": json.dumps(body),
    }


def handler(event, context):
    headers = {k.lower(): v for k, v in (event.get("headers") or {}).items()}
    idempotency_key = headers.get("idempotency-key")
    if not idempotency_key:
        return _response(
            400,
            {
                "error": {
                    "code": "MISSING_IDEMPOTENCY_KEY",
                    "message": "Idempotency-Key header is required for mutation endpoints",
                    "retriable": False,
                }
            },
        )

    try:
        payload = json.loads(event.get("body") or "{}")
    except json.JSONDecodeError:
        return _response(
            400,
            {
                "error": {
                    "code": "INVALID_JSON",
                    "message": "Request body must be valid JSON",
                    "retriable": False,
                }
            },
        )

    correlation_id = headers.get("x-correlation-id", str(uuid.uuid4()))
    envelope = {
        "source": "hotel.api",
        "detailType": payload.get("eventType", "CommandRequested"),
        "detail": {
            "eventVersion": payload.get("eventVersion", "1.0"),
            "correlationId": correlation_id,
            "idempotencyKey": idempotency_key,
            "payload": payload.get("payload", payload),
        },
    }

    try:
        send_kwargs = {
            "QueueUrl": QUEUE_URL,
            "MessageBody": json.dumps(envelope),
        }
        if QUEUE_URL.endswith(".fifo"):
            send_kwargs["MessageGroupId"] = "hotel-commands"
            send_kwargs["MessageDeduplicationId"] = idempotency_key

        sqs.send_message(**send_kwargs)
    except Exception:
        return _response(
            502,
            {
                "error": {
                    "code": "QUEUE_ENQUEUE_FAILED",
                    "message": "Unable to enqueue command event",
                    "retriable": True,
                },
                "correlationId": correlation_id,
            },
        )

    return _response(
        202,
        {
            "status": "queued",
            "correlationId": correlation_id,
            "region": REGION,
        },
    )
