from base import BaseTestCase, Profile
from parameterized import parameterized

profiles = [
        ['mobile_test', 'Test account',
         'Test Account. test test Testing username with @mobile_test_2 and a #hashtag'],
        ['mobile_test_2', 'mobile test 2', '']
]

verified = [['jack'], ['elonmusk']]

protected = [
    ['mobile_test_7', 'mobile test 7🔒', ''],
    ['Poop', 'Randy🔒', 'Social media fanatic.']
]

invalid = [['thisprofiledoesntexist'], ['%']]

banner_color = [
    ['TheTwoffice', '29, 161, 242'],
    ['profiletest', '80, 176, 58']
]

banner_image = [
    ['mobile_test', 'profile_banners%2F82135242%2F1384108037%2F1500x500']
]


class ProfileTest(BaseTestCase):
    @parameterized.expand(profiles)
    def test_data(self, username, fullname, bio):
        self.open_nitter(username)
        self.assert_exact_text(fullname, Profile.fullname)
        self.assert_exact_text(f'@{username}', Profile.username)

        if len(bio) > 0:
            self.assert_exact_text(bio, Profile.bio)
        else:
            self.assert_element_absent(Profile.bio)

    @parameterized.expand(verified)
    def test_verified(self, username):
        self.open_nitter(username)
        self.assert_element_visible(Profile.verified)

    @parameterized.expand(protected)
    def test_protected(self, username, fullname, bio):
        self.open_nitter(username)
        self.assert_element_visible(Profile.protected)
        self.assert_exact_text(fullname, Profile.fullname)
        self.assert_exact_text(f'@{username}', Profile.username)

        if len(bio) > 0:
            self.assert_text(bio, Profile.bio)
        else:
            self.assert_element_absent(Profile.bio)

    @parameterized.expand(invalid)
    def test_invalid_username(self, username):
        self.open_nitter(username)
        self.assert_text(f'User "{username}" not found')

    def test_suspended(self):
        # TODO: detect suspended
        self.open_nitter('test')
        self.assert_text(f'User "test" not found')

    @parameterized.expand(banner_color)
    def test_banner_color(self, username, color):
        self.open_nitter(username)
        banner = self.find_element(Profile.banner + '-color')
        self.assertIn(color, banner.value_of_css_property('background-color'))

    @parameterized.expand(banner_image)
    def test_banner_image(self, username, url):
        self.open_nitter(username)
        banner = self.find_element(Profile.banner + ' img')
        self.assertIn(url, banner.get_attribute('src'))
