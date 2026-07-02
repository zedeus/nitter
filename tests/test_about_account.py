from base import BaseTestCase, Profile
from parameterized import parameterized


class AboutAccount(object):
    header = '.about-account-header'
    name = '.about-account-name'
    body = '.about-account-body'
    row = '.about-account-row'
    label = '.about-account-label'
    value = '.about-account-value'


# (username, expected_labels)
# Each label is checked for presence in the page text
about_data = [
    ['jack', ['Date joined', 'Account based in', 'Connected via']],
    ['NASA', ['Date joined']],
    ['elonmusk', ['Date joined']],
]

about_verified = [
    ['jack', 'Verified', 'Since '],
]

about_affiliate = [
    ['jack', 'An affiliate of', 'Square'],
    ['elonmusk', 'An affiliate of', 'X'],
]


class AboutAccountTest(BaseTestCase):
    @parameterized.expand(about_data)
    def test_about_page_has_labels(self, username, expected_labels):
        """About page shows expected info labels"""
        self.open_nitter(f'{username}/about')
        self.assert_element_visible(AboutAccount.header)
        self.assert_element_visible(AboutAccount.body)
        for label in expected_labels:
            self.assert_text(label, AboutAccount.body)

    @parameterized.expand(about_verified)
    def test_about_verified(self, username, label, value_prefix):
        """About page shows verification info for verified accounts"""
        self.open_nitter(f'{username}/about')
        self.assert_text(label, AboutAccount.body)
        self.assert_text(value_prefix, AboutAccount.body)

    @parameterized.expand(about_affiliate)
    def test_about_affiliate(self, username, label, affiliate):
        """About page shows affiliate info"""
        self.open_nitter(f'{username}/about')
        self.assert_text(label, AboutAccount.body)
        self.assert_text(f'@{affiliate}', AboutAccount.body)

    def test_about_page_title(self):
        """Title contains account name"""
        self.open_nitter('jack/about')
        self.assert_text('jack', AboutAccount.name)

    def test_about_join_date(self):
        """About page always shows join date"""
        self.open_nitter('jack/about')
        self.assert_text('Date joined', AboutAccount.body)
        self.assert_text('March 2006', AboutAccount.body)

    def test_about_invalid_user(self):
        """About page for non-existent user shows error"""
        self.open_nitter('thisprofiledoesntexist/about')
        self.assert_text('User "thisprofiledoesntexist" not found')

    def test_joindate_links_to_about(self):
        """Join date on profile page links to about page"""
        self.open_nitter('jack')
        link = self.find_element(Profile.joinDate + ' a')
        self.assertIn('/jack/about', link.get_attribute('href'))
