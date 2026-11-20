"""Offline generator checks; these do not replace MySQL integration testing."""
import unittest
from collections import Counter

from q03_data import REFERENCE_DATE, action_rows


class GeneratorTests(unittest.TestCase):
    def test_reproducible(self):
        self.assertEqual(list(action_rows(84, "seed_like", 2411)), list(action_rows(84, "seed_like", 2411)))

    def test_seed_like_distribution(self):
        rows = list(action_rows(4200, "seed_like", 2411))
        self.assertEqual(sum(row[4] < REFERENCE_DATE for row in rows), 3000)
        self.assertEqual(sum(row[4] < REFERENCE_DATE and row[5] != "VERIFIED" for row in rows), 1000)
        self.assertEqual(Counter(row[5] for row in rows if row[4] < REFERENCE_DATE and row[5] != "VERIFIED"), {"RESOLVED": 800, "IN_PROGRESS": 200})

    def test_selective_distribution(self):
        rows = list(action_rows(3000, "selective", 2411))
        self.assertEqual(sum(row[4] < REFERENCE_DATE for row in rows), 30)
        self.assertEqual(sum(row[4] < REFERENCE_DATE and row[5] != "VERIFIED" for row in rows), 10)

    def test_state_fields(self):
        for scenario in ("seed_like", "selective"):
            rows = list(action_rows(601, scenario, 2411))
            self.assertEqual(len({row[0] for row in rows}), 601)
            for row in rows:
                self.assertLessEqual(row[3], row[4])
                self.assertIn(row[2], range(1, 8))
                if row[5] in ("OPEN", "IN_PROGRESS"):
                    self.assertEqual(row[6:], (None, None, None, None))
                else:
                    self.assertIsNotNone(row[6])
                    self.assertTrue(row[7])
                if row[5] == "VERIFIED":
                    self.assertEqual(row[8], 8)
                    self.assertLessEqual(row[6], row[9])

    def test_invalid_arguments(self):
        for count, scenario in ((0, "seed_like"), (1, "unknown")):
            with self.assertRaises(ValueError):
                list(action_rows(count, scenario, 2411))


if __name__ == "__main__":
    unittest.main()
