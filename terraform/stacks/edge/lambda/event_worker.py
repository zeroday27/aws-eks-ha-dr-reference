import json
import os
import boto3

events = boto3.client("events")
BUS_NAME = os.environ["EVENT_BUS_NAME"]


def handler(event, context):
    records = event.get("Records", [])
    if not records:
        return {"batchItemFailures": []}

    entries = []
    mapping = []
    failures = []

    for record in records:
        message_id = record.get("messageId")
        try:
            body = json.loads(record.get("body") or "{}")
            entries.append(
                {
                    "Source": body.get("source", "hotel.api"),
                    "DetailType": body.get("detailType", "CommandRequested"),
                    "EventBusName": BUS_NAME,
                    "Detail": json.dumps(body.get("detail", {})),
                }
            )
            mapping.append(message_id)
        except Exception:
            failures.append({"itemIdentifier": message_id})

    if not entries:
        return {"batchItemFailures": failures}

    response = events.put_events(Entries=entries)
    failed_count = response.get("FailedEntryCount", 0)

    if failed_count == 0:
        return {"batchItemFailures": failures}

    for idx, result in enumerate(response.get("Entries", [])):
        if result.get("ErrorCode"):
            failures.append({"itemIdentifier": mapping[idx]})

    return {"batchItemFailures": failures}
