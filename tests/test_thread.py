from base import BaseTestCase, Conversation
from parameterized import parameterized

thread = [
    ['octonion/status/975253897697611777', [], 'Based', ['Crystal', 'Julia'], [
        ['For', 'Then', 'Okay,', 'Python', 'Speed', 'Java', 'Coding', 'I', 'You'],
        ['yeah,']
    ]],

    ['octonion/status/975254452625002496', ['Based'], 'Crystal', ['Julia'], []],

    ['octonion/status/975256058384887808', ['Based', 'Crystal'], 'Julia', [], []],

    ['gauravssnl/status/975364889039417344',
     ['Based', 'For', 'Then', 'Okay,', 'Python'], 'Speed', [], [
         ['Java', 'Coding', 'I', 'You'], ['JAVA!']
     ]],

    ['d0m96/status/1141811379407425537', [], 'I\'m',
     ['The', 'The', 'Today', 'Some', 'If', 'There', 'Above'],
     [['Thank', 'Also,']]],

    ['gmpreussner/status/999766552546299904', [], 'A', [],
     [['I', 'Especially'], ['I']]]
]


class ThreadTest(BaseTestCase):
    def find_tweets(self, selector):
        return self.find_elements(f"{selector} {Conversation.tweet_text}")

    def compare_first_word(self, tweets, selector):
        if len(tweets) > 0:
            self.assert_element_visible(selector)
            for i, tweet in enumerate(self.find_tweets(selector)):
                text = tweet.text.split(" ")[0]
                self.assert_equal(tweets[i], text)

    @parameterized.expand(thread)
    def test_thread(self, tweet, before, main, after, replies):
        self.open_nitter(tweet)
        self.assert_element_visible(Conversation.main)

        self.assert_text(main, Conversation.main)
        self.assert_text(main, Conversation.main)

        self.compare_first_word(before, Conversation.before)
        self.compare_first_word(after, Conversation.after)

        for i, reply in enumerate(self.find_elements(Conversation.thread)):
            selector = Conversation.replies + f" > div:nth-child({i + 1})"
            self.compare_first_word(replies[i], selector)
