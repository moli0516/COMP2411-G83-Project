"""Deterministic synthetic CorrectiveAction rows for the optional Q03 benchmark."""
import random
from datetime import date, timedelta


REFERENCE_DATE = date(2026, 10, 31)
SCENARIOS = ("seed_like", "selective")


def action_rows(rows, scenario, seed):
    if rows < 1 or scenario not in SCENARIOS:
        raise ValueError("Choose a positive row count and a supported scenario.")

    randomizer = random.Random(seed)
    positions = list(range(rows))
    randomizer.shuffle(positions)

    for action_id, position in enumerate(positions, 1):
        if scenario == "seed_like":
            bucket = position % 42
            overdue = bucket < 30
            unverified = 20 <= bucket < 30
        else:
            overdue = position % 100 == 0
            unverified = position % 300 == 0

        offset = randomizer.randint(1, 180)
        due_date = REFERENCE_DATE + timedelta(days=-offset if overdue else offset)
        created_date = due_date - timedelta(days=30)
        status = "VERIFIED"

        if unverified:
            status = "RESOLVED" if position % 5 else "IN_PROGRESS"
        elif not overdue:
            status = SCENARIOS_STATUS[position % 4]

        resolved = status in ("RESOLVED", "VERIFIED")
        verified = status == "VERIFIED"
        resolved_date = due_date - timedelta(days=2) if resolved else None
        verified_date = due_date - timedelta(days=1) if verified else None

        yield (
            action_id,
            f"Synthetic benchmark action {action_id}: " + "follow-up detail " * 12,
            1 + position % 7,
            created_date,
            due_date,
            status,
            resolved_date,
            "Synthetic resolution reviewed" if resolved else None,
            8 if verified else None,
            verified_date,
        )


SCENARIOS_STATUS = ("OPEN", "IN_PROGRESS", "RESOLVED", "VERIFIED")
