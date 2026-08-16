from base import BaseTestCase, Profile
from parameterized import parameterized

profiles = [
        ['mobile_test', 'Test account',
         'Test Account. test test Testing username with @mobile_test_2 and a #hashtag',
         'San Francisco, CA', 'example.com/foobar', 'Joined October 2009', '97'],
        ['mobile_test_2', 'mobile test 2', '', '', '', 'Joined January 2011', '13']
]

verified = [['jack'], ['elonmusk']]

protected = [
    ['mobile_test_7', 'mobile test 7', ''],
    ['Poop', 'Randy', 'Social media fanatic.']
]

invalid = [['thisprofiledoesntexist']]

malformed = [
    ['${userId}'],
    ['$%7BuserId%7D'],  # URL encoded version
    ['%'],  # Percent sign is invalid
    ['user@name'],
    ['user.name'],
    ['user-name'],
    ['user$name'],
    ['user{name}'],
    ['user name'],  # space
]

banner_image = [
    ['mobile_test', 'profile_banners%2F82135242%2F1384108037%2F1500x500']
]

# (user_id, expected_username) — resolving a numeric id to a profile (issue #1433)
id_redirects = [
    ['12', 'jack'],
    ['44196397', 'elonmusk']
]


class ProfileTest(BaseTestCase):
    @parameterized.expand(profiles)
    def test_data(self, username, fullname, bio, location, website, joinDate, mediaCount):
        self.open_nitter(username)
        self.assert_exact_text(fullname, Profile.fullname)
        self.assert_exact_text(f'@{username}', Profile.username)

        tests = [
            (bio, Profile.bio),
            (location, Profile.location),
            (website, Profile.website),
            (joinDate, Profile.joinDate),
            (mediaCount + " Photos and videos", Profile.mediaCount)
        ]

        for text, selector in tests:
            if len(text) > 0:
                self.assert_exact_text(text, selector)
            else:
                self.assert_element_absent(selector)

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

    @parameterized.expand(malformed)
    def test_malformed_username(self, username):
        """Test that malformed usernames (with invalid characters) return 404"""
        self.open_nitter(username)
        # Malformed usernames should return 404 page not found, not try to fetch from Twitter
        self.assert_text('Page not found')

    def test_suspended(self):
        self.open_nitter('suspendme')
        self.assert_text('User "suspendme" has been suspended')

    @parameterized.expand(banner_image)
    def test_banner_image(self, username, url):
        self.open_nitter(username)
        banner = self.find_element(Profile.banner + ' img')
        self.assertIn(url, banner.get_attribute('src'))


class UserIdRedirectTest(BaseTestCase):
    @parameterized.expand(id_redirects)
    def test_i_user_redirect(self, user_id, username):
        """/i/user/<id> resolves the numeric id and redirects to the profile (issue #1433)"""
        self.open_nitter(f'i/user/{user_id}')
        self.assert_true(self.get_current_url().rstrip('/').endswith(f'/{username}'))
        self.assert_exact_text(f'@{username}', Profile.username)

    @parameterized.expand(id_redirects)
    def test_intent_user_redirect(self, user_id, username):
        """/intent/user?user_id=<id> redirects to the profile (issue #1433)"""
        self.open_nitter(f'intent/user?user_id={user_id}')
        self.assert_true(self.get_current_url().rstrip('/').endswith(f'/{username}'))
        self.assert_exact_text(f'@{username}', Profile.username)
