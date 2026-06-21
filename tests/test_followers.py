# SPDX-License-Identifier: AGPL-3.0-only
from base import BaseTestCase, Timeline


class FollowersTest(BaseTestCase):
    """Tests for followers and following pages"""

    def test_followers_page_loads(self):
        """Test that followers page loads and shows users"""
        self.open_nitter('jack/followers')
        self.assert_title_contains('following @jack')
        # Check for user list
        self.assert_element('.timeline-item')

    def test_following_page_loads(self):
        """Test that following page loads and shows users"""
        self.open_nitter('jack/following')
        self.assert_title_contains('followed by @jack')
        # Check for user list
        self.assert_element('.timeline-item')

    def test_followers_has_navigation_tabs(self):
        """Test that followers page has following/followers tabs"""
        self.open_nitter('jack/followers')
        self.assert_element('.profile-statlist')
        # Check for Following and Followers links
        self.assert_element('a[href="/jack/following"]')
        self.assert_element('a[href="/jack/followers"]')

    def test_following_pagination(self):
        """Test that following page has load more button or scroll-to-top"""
        self.open_nitter('jack/following')
        # Should have either more button or top-ref (scroll to top arrow)
        try:
            self.assert_element('.show-more')
        except:
            self.assert_element('.top-ref')

    def test_nonexistent_user_followers(self):
        """Test 404 for non-existent user"""
        self.open_nitter('this_user_definitely_does_not_exist_12345/followers')
        self.assert_element('.error-panel')
        self.assert_text_visible('not found')
