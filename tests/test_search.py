from base import BaseTestCase
from parameterized import parameterized


class SearchTest(BaseTestCase):
    @parameterized.expand([['@mobile_test'], ['@mobile_test_2']])
    def test_username_search(self, username):
        self.search_username(username)
        self.assert_text(f'{username}')
