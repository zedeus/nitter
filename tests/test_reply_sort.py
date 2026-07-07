from parameterized import parameterized

from base import BaseTestCase, Conversation

sort_modes = [
    ['jack/status/20', 'Relevant'],
    ['jack/status/20?sort=relevance', 'Relevant'],
    ['jack/status/20?sort=recency', 'Recent'],
    ['jack/status/20?sort=likes', 'Liked'],
    ['jack/status/20?sort=garbage', 'Relevant'],
    ['jack/status/20?sort=%3Cscript%3E', 'Relevant'],
]


class ReplySortTest(BaseTestCase):
    @parameterized.expand(sort_modes)
    def test_active_mode(self, page, expected_active):
        self.open_nitter(page)
        self.assert_element_visible(Conversation.reply_sort)
        active = self.get_text(Conversation.reply_sort_active)
        self.assert_equal(active.strip(), expected_active)

    def test_all_three_options_present(self):
        self.open_nitter('jack/status/20')
        options = self.find_elements('.reply-sort-option')
        labels = [o.text.strip() for o in options]
        self.assert_equal(labels, ['Relevant', 'Recent', 'Liked'])

    def test_option_links_carry_sort_param(self):
        self.open_nitter('jack/status/20')
        for slug in ['Relevance', 'Recency', 'Likes']:
            self.assert_element(f'.reply-sort-option[href="?sort={slug}#r"]')

    def test_load_more_preserves_sort(self):
        self.open_nitter('jack/status/20?sort=Likes')
        href = self.get_attribute('.replies .show-more a', 'href')
        self.assert_true('sort=Likes' in href, f'sort missing from: {href}')
