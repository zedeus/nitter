from base import BaseTestCase, Timeline
from parameterized import parameterized

normal = [['mobile_test'], ['mobile_test_2']]

after = [['mobile_test', 'HBaAgJPsqtGNhA0AAA%3D%3D'],
         ['mobile_test_2', 'HBaAgJPsqtGNhA0AAA%3D%3D']]

no_more = [['mobile_test_8?cursor=HBaAwJCsk%2F6%2FtgQAAA%3D%3D']]

empty = [['emptyuser'], ['mobile_test_10']]

protected = [['mobile_test_7'], ['Empty_user']]


class TweetTest(BaseTestCase):
    @parameterized.expand(normal)
    def test_timeline(self, username):
        self.open_nitter(username)
        self.assert_element_present(Timeline.older)
        self.assert_element_absent(Timeline.newest)
        self.assert_element_absent(Timeline.end)
        self.assert_element_absent(Timeline.none)

    @parameterized.expand(after)
    def test_after(self, username, cursor):
        self.open_nitter(f'{username}?cursor={cursor}')
        self.assert_element_present(Timeline.newest)
        self.assert_element_present(Timeline.older)
        self.assert_element_absent(Timeline.end)
        self.assert_element_absent(Timeline.none)

    @parameterized.expand(no_more)
    def test_no_more(self, username):
        self.open_nitter(username)
        self.assert_text('No more items', Timeline.end)
        self.assert_element_present(Timeline.newest)
        self.assert_element_absent(Timeline.older)

    @parameterized.expand(empty)
    def test_empty(self, username):
        self.open_nitter(username)
        self.assert_text('No items found', Timeline.none)
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
