from base import BaseTestCase, Poll
from parameterized import parameterized

poll = [
    ['nim_lang/status/1064219801499955200', 'Style insensitivity', '91', 1, [
        ('47%', 'Yay'), ('53%', 'Nay')
    ]],

    ['polls/status/1031986180622049281', 'What Tree Is Coolest?', '3,322', 1, [
        ('30%', 'Oak'), ('42%', 'Bonsai'), ('5%', 'Hemlock'), ('23%', 'Apple')
    ]]
]


class MediaTest(BaseTestCase):
    @parameterized.expand(poll)
    def test_poll(self, tweet, text, votes, leader, choices):
        self.open_nitter(tweet)
        self.assert_text(text, '.main-tweet')
        self.assert_text(votes, Poll.votes)

        poll_choices = self.find_elements(Poll.choice)
        for i in range(len(choices)):
            v, o = choices[i]

            choice = poll_choices[i]
            value = choice.find_element_by_class_name(Poll.value)
            option = choice.find_element_by_class_name(Poll.option)
            choice_class = choice.get_attribute('class')

            self.assert_equal(v, value.text)
            self.assert_equal(o, option.text)

            if i == leader:
                self.assertIn(Poll.leader, choice_class)
            else:
                self.assertNotIn(Poll.leader, choice_class)
