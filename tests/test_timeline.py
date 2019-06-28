from base import BaseTestCase, Timeline
from parameterized import parameterized

normal = [['mobile_test'], ['mobile_test_2']]

after = [['mobile_test', '627635134573862912'],
         ['mobile_test_2', '377196342281388032']]

short = [['mobile_test_6'], ['mobile_test_8'], ['picman']]

no_more = [['mobile_test_8?after=159455542543257601']]

none_found = [['mobile_test_8?after=159455542543257600']]

empty = [['maybethis'], ['mobile_test_10']]

protected = [['mobile_test_7'], ['Poop']]


class TweetTest(BaseTestCase):
    @parameterized.expand(normal)
    def test_timeline(self, username):
        self.open_nitter(username)
        self.assert_element_present(Timeline.older)
        self.assert_element_absent(Timeline.newest)
        self.assert_element_absent(Timeline.end)
        self.assert_element_absent(Timeline.none)

    @parameterized.expand(after)
    def test_after(self, username, index):
        self.open_nitter(f'{username}?after={index}')
        self.assert_element_present(Timeline.newest)
        self.assert_element_present(Timeline.older)
        self.assert_element_absent(Timeline.end)
        self.assert_element_absent(Timeline.none)

    @parameterized.expand(short)
    def test_short(self, username):
        self.open_nitter(username)
        self.assert_text('No more tweets.', Timeline.end)
        self.assert_element_absent(Timeline.newest)
        self.assert_element_absent(Timeline.older)

    @parameterized.expand(no_more)
    def test_no_more(self, username):
        self.open_nitter(username)
        self.assert_text('No more tweets.', Timeline.end)
        self.assert_element_present(Timeline.newest)
        self.assert_element_absent(Timeline.older)

    @parameterized.expand(none_found)
    def test_none_found(self, username):
        self.open_nitter(username)
        self.assert_text('No tweets found.', Timeline.none)
        self.assert_element_present(Timeline.newest)
        self.assert_element_absent(Timeline.older)
        self.assert_element_absent(Timeline.end)

    @parameterized.expand(empty)
    def test_empty(self, username):
        self.open_nitter(username)
        self.assert_text('No tweets found.', Timeline.none)
        self.assert_element_absent(Timeline.newest)
        self.assert_element_absent(Timeline.older)
        self.assert_element_absent(Timeline.end)

    @parameterized.expand(protected)
    def test_protected(self, username):
        self.open_nitter(username)
        self.assert_text('This account\'s tweets are protected.', Timeline.protected)
        self.assert_element_absent(Timeline.newest)
        self.assert_element_absent(Timeline.older)
        self.assert_element_absent(Timeline.end)
