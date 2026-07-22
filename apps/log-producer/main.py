import json
import random
import time
from datetime import datetime, timezone

SERVICES = ["auth-service", "billing-service", "api-gateway"]
MESSAGES = [
    "Request processed successfully",
    "Cache miss on user profile",
    "Downstream timeout",
    "Database connection pool exhausted",
    "User login succeeded",
]
LEVELS = ["INFO", "WARN", "ERROR"]

while True:
    log = {
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "service_name": random.choice(SERVICES),
        "level": random.choice(LEVELS),
        "message": random.choice(MESSAGES),
    }
    print(json.dumps(log), flush=True)
    time.sleep(0.5)
