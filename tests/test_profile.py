from base import BaseTestCase, Profile
from parameterized import parameterized

profiles = [
        ['Test account', 'mobile_test',
         'Test Account. test test Testing username with @mobile_test_2 and a #hashtag'],
        ['mobile test 2', 'mobile_test_2', '']
]

verified = [['jack'], ['elonmusk']]

protected = [
    ['mobile test 7', 'mobile_test_7', ''],
    ['Randy', 'Poop', 'Social media fanatic.']
]

invalid = [['thisprofiledoesntexist'], ['%']]


class TestProfile(BaseTestCase):
    @parameterized.expand(profiles)
    def test_data(self, fullname, username, bio):
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
    def test_protected(self, fullname, username, bio):
        self.open_nitter(username)
        self.assert_element_visible(Profile.protected)
        self.assert_exact_text(fullname, Profile.fullname)
        self.assert_exact_text(f'@{username}', Profile.username)
        self.assert_text('Tweets are protected')

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
