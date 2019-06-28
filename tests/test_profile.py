from base import BaseTestCase, Profile


class TestProfile(BaseTestCase):
    def test_data(self):
        self.open_nitter('mobile_test')
        self.assert_exact_text('Test account', Profile.fullname)
        self.assert_exact_text('@mobile_test', Profile.username)
        self.assert_exact_text('Test Account. test test Testing username with @mobile_test_2 and a #hashtag',
                               Profile.bio)

        self.open_nitter('mobile_test_2')
        self.assert_exact_text('mobile test 2', Profile.fullname)
        self.assert_exact_text('@mobile_test_2', Profile.username)
        self.assert_element_not_visible(Profile.bio)

    def test_verified(self):
        self.open_nitter('jack')
        self.assert_element_visible(Profile.verified)

        self.open_nitter('elonmusk')
        self.assert_element_visible(Profile.verified)

    def test_protected(self):
        self.open_nitter('mobile_test_7')
        self.assert_element_visible(Profile.protected)
        self.assert_exact_text('mobile test 7', Profile.fullname)
        self.assert_exact_text('@mobile_test_7', Profile.username)
        self.assert_text('Tweets are protected')

        self.open_nitter('poop')
        self.assert_element_visible(Profile.protected)
        self.assert_exact_text('Randy', Profile.fullname)
        self.assert_exact_text('@Poop', Profile.username)
        self.assert_text('Social media fanatic.', Profile.bio)
        self.assert_text('Tweets are protected')

    def test_invalid_username(self):
        for p in ['test', 'thisprofiledoesntexist', '%']:
            self.open_nitter(p)
            self.assert_text(f'User "{p}" not found')

    def test_suspended(self):
        # TODO: detect suspended
        self.open_nitter('test')
        self.assert_text(f'User "test" not found')
