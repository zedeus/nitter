# SPDX-License-Identifier: AGPL-3.0-only
"""Integration tests for Twitter Spaces support."""
import pytest
from seleniumbase import BaseCase


class TestSpacePage(BaseCase):
    """Tests for /i/spaces/@id route."""

    SPACE_ID = "1mxPaaRAwYjKN"
    SPACE_URL = f"http://localhost:8080/i/spaces/{SPACE_ID}"

    def test_space_page_loads(self):
        """Space page should load with title."""
        self.open(self.SPACE_URL)
        self.assert_element(".space-page")
        self.assert_element(".space-panel")
        self.assert_text_visible("INTEL WILL MOON NEXT WEEK", ".space-title")

    def test_space_host_info(self):
        """Space should display host in participants."""
        self.open(self.SPACE_URL)
        self.assert_element(".space-participants")
        self.assert_text_visible("bubble boi")
        self.assert_element(".host-badge")

    def test_space_metadata(self):
        """Space should display listener count and state."""
        self.open(self.SPACE_URL)
        self.assert_element(".space-meta")
        # Should show listener count (number format)
        meta_text = self.get_text(".space-meta")
        assert any(c.isdigit() for c in meta_text), "Should show listener count"
        # Should show ended state
        assert "Ended" in meta_text or "Jun" in meta_text, "Should show ended state"

    def test_space_participants(self):
        """Space should display host and speakers."""
        self.open(self.SPACE_URL)
        self.assert_element(".space-participants")
        # Host should have badge
        self.assert_element(".host-badge")
        self.assert_text_visible("Host", ".host-badge")
        # Should show speakers
        self.assert_text_visible("CANTELOPEPEEL")
        self.assert_text_visible("Based Burner Account")
        self.assert_text_visible("anon invests")

    def test_space_participant_avatars(self):
        """Participant avatars should load correctly."""
        self.open(self.SPACE_URL)
        # Check avatars in participants section
        avatars = self.find_elements(".space-participant img")
        assert len(avatars) >= 4, "Should have at least 4 participant avatars"
        for avatar in avatars:
            src = avatar.get_attribute("src")
            # Should NOT be double-encoded
            assert "%2Fpic%2F" not in src, f"Avatar URL double-encoded: {src}"
            # Should have valid path
            assert "/pic/" in src, f"Avatar URL missing /pic/: {src}"

    def test_space_player_hls_disabled(self):
        """Without HLS, should show enable button with video-overlay style."""
        self.open(self.SPACE_URL)
        self.assert_element(".space-player")
        self.assert_element(".video-overlay")
        # Should show duration in overlay-duration
        self.assert_element(".overlay-duration")
        # Should have enable button
        source = self.get_page_source()
        assert "Enable hls playback" in source

    def test_space_player_hls_enabled(self):
        """With HLS enabled, should have audio element in DOM."""
        self.open(self.SPACE_URL)
        # Set HLS preference via cookie
        self.add_cookie({"name": "hlsPlayback", "value": "on"})
        self.refresh()
        # Check page source for audio element (hidden until play clicked)
        source = self.get_page_source()
        assert '<audio data-url="' in source, "Should have audio element"
        assert "playAudio(this)" in source, "Should have play handler"
        # Overlay should be visible (uses video-overlay class)
        self.assert_element(".video-overlay")

    def test_space_stream_endpoint(self):
        """Stream endpoint should return HLS manifest."""
        import requests
        resp = requests.get(f"{self.SPACE_URL}/stream")
        assert resp.status_code == 200
        assert "#EXTM3U" in resp.text
        assert "#EXT-X-TARGETDURATION" in resp.text


class TestSpaceCard(BaseCase):
    """Tests for Space cards in tweets."""

    def test_space_card_in_tweet(self):
        """Tweet with Space should show card linking to Space page."""
        self.open("http://localhost:8080/bubbleboi/status/2065299704808960482")
        self.assert_element(".card")
        # Card should link to Space
        card_link = self.find_element(".card-container")
        href = card_link.get_attribute("href")
        assert "/i/spaces/" in href

    def test_space_card_title(self):
        """Space card should have title."""
        self.open("http://localhost:8080/bubbleboi/status/2065299704808960482")
        self.assert_text_visible("Twitter Space", ".card-title")


class TestSpaceNotFound(BaseCase):
    """Tests for error handling."""

    def test_invalid_space_id(self):
        """Invalid Space ID should show error."""
        self.open("http://localhost:8080/i/spaces/invalid123")
        self.assert_text_visible("Space not found")
