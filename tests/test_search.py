from base import BaseTestCase


class TestSearch(BaseTestCase):
    def test_username_search(self):
        self.search_username('mobile_test')
        self.assert_text('@mobile_test')

        self.search_username('mobile_test_2')
        self.assert_text('@mobile_test_2')
