"""Contract checks without writing to the shared production databases."""

import asyncio
import io
import os
import sys
import unittest
from pathlib import Path
from unittest.mock import patch
from uuid import uuid4

import httpx
from fastapi import FastAPI
from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from API import review_feedback, search_events


class FakeCollection:
    def __init__(self):
        self.documents = []

    async def update_one(self, query, update, upsert=False):
        self.documents.append(update["$setOnInsert"])


class FakeDatabase:
    def __init__(self):
        self.collections = {}

    def get_collection(self, name):
        return self.collections.setdefault(name, FakeCollection())


class AdminBridgeTests(unittest.IsolatedAsyncioTestCase):
    async def asyncSetUp(self):
        os.environ["REVIEW_TOKEN_SECRET"] = "test-secret-with-at-least-thirty-two-characters"
        self.mongo = FakeDatabase()
        self.app = FastAPI()
        self.app.include_router(review_feedback.router)
        self.app.include_router(search_events.router)
        self.mongo_patch = patch.object(review_feedback, "get_shared_database", return_value=self.mongo)
        self.search_mongo_patch = patch.object(search_events, "get_shared_database", return_value=self.mongo)
        self.mongo_patch.start()
        self.search_mongo_patch.start()
        self.client = httpx.AsyncClient(
            transport=httpx.ASGITransport(app=self.app), base_url="http://test"
        )

    async def asyncTearDown(self):
        await self.client.aclose()
        self.mongo_patch.stop()
        self.search_mongo_patch.stop()

    async def test_consent_and_revocation_match_admin_inbox(self):
        buffer = io.BytesIO()
        Image.new("RGB", (32, 32), "green").save(buffer, format="JPEG")
        image = buffer.getvalue()
        prediction_id, token = review_feedback.prediction_tokens(
            image, [{"plant_id": 1, "confidence": 0.8}], "sha256-test"
        )
        params = {"feedback_token": token, "source": "user_feedback"}
        file = {"file": ("plant.jpg", image, "image/jpeg")}
        denied = await self.client.post(
            "/api/v1/prediction-feedback", data={**params, "consent_granted": "false"}, files=file
        )
        self.assertEqual(denied.status_code, 422)
        self.assertNotIn("plant_review_submissions", self.mongo.collections)

        accepted = await self.client.post(
            "/api/v1/prediction-feedback", data={**params, "consent_granted": "true"}, files=file
        )
        self.assertEqual(accepted.status_code, 202)
        document = self.mongo.get_collection("plant_review_submissions").documents[0]
        self.assertEqual(document["prediction_id"], prediction_id)
        self.assertEqual(document["predicted_top3"][0]["plant_id"], 1)
        self.assertEqual(bytes(document["image_bytes"]), image)
        self.assertNotIn("user_id", document)
        self.assertNotIn("gps", document)

        revoked = await self.client.post(
            "/api/v1/prediction-feedback/revoke",
            json={"revocation_token": accepted.json()["revocation_token"]},
        )
        self.assertEqual(revoked.status_code, 202)
        self.assertEqual(
            self.mongo.get_collection("plant_review_revocations").documents[0]["prediction_id"],
            prediction_id,
        )

    async def test_changed_image_is_rejected(self):
        _, token = review_feedback.prediction_tokens(
            b"original", [{"plant_id": 1, "confidence": 0.8}], "test"
        )
        result = await self.client.post(
            "/api/v1/prediction-feedback",
            data={"feedback_token": token, "consent_granted": "true"},
            files={"file": ("plant.jpg", b"changed", "image/jpeg")},
        )
        self.assertEqual(result.status_code, 400)
        self.assertNotIn("plant_review_submissions", self.mongo.collections)

    async def test_search_event_requires_real_zero_result(self):
        payload = {"query": "bac ha", "search_session_id": str(uuid4())}
        with patch.object(search_events.catalog, "search_plants", return_value=[{"ID": 1}]):
            denied = await self.client.post("/api/v1/search-events/zero-result", json=payload)
        self.assertEqual(denied.status_code, 409)
        self.assertNotIn("plant_search_events", self.mongo.collections)

        with patch.object(search_events.catalog, "search_plants", return_value=[]):
            accepted = await self.client.post("/api/v1/search-events/zero-result", json=payload)
        self.assertEqual(accepted.status_code, 202)
        event = self.mongo.get_collection("plant_search_events").documents[0]
        self.assertTrue(event["is_final"])
        self.assertEqual(event["result_count"], 0)
        self.assertNotIn("user_id", event)


if __name__ == "__main__":
    unittest.main()
