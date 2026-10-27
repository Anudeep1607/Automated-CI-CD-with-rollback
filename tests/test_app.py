import os
import unittest
from app.app import app

class HealthEndpointTests(unittest.TestCase):
    def setUp(self):
        self.client = app.test_client()
        os.environ.pop("SIMULATE_UNHEALTHY", None)

    def tearDown(self):
        os.environ.pop("SIMULATE_UNHEALTHY", None)

    def test_health_returns_200_when_healthy(self):
        response = self.client.get("/health")
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.get_json()["status"], "ok")

    def test_health_returns_503_when_test_flag_enabled(self):
        os.environ["SIMULATE_UNHEALTHY"] = "true"
        response = self.client.get("/health")
        self.assertEqual(response.status_code, 503)
        self.assertEqual(response.get_json()["status"], "unhealthy")

if __name__ == "__main__":
    unittest.main()
