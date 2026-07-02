from base import BaseTestCase
from parameterized import parameterized


COMMUNITY_ID = '1493446837214187523'
COMMUNITY_PATH = f'i/communities/{COMMUNITY_ID}'


class CommunityTest(BaseTestCase):
    def test_top_page_loads(self):
        self.open_nitter(COMMUNITY_PATH)
        self.assert_element_visible('.community-header')
        self.assert_text('Build in Public', '.community-name')

    def test_banner_visible(self):
        self.open_nitter(COMMUNITY_PATH)
        self.assert_element_visible('.timeline-banner img')

    def test_member_count(self):
        self.open_nitter(COMMUNITY_PATH)
        self.assert_element_visible('.community-member-count')
        self.assert_text('Members', '.community-member-count')

    def test_description_visible(self):
        self.open_nitter(COMMUNITY_PATH)
        self.assert_element_visible('.community-description')

    def test_tabs_present(self):
        self.open_nitter(COMMUNITY_PATH)
        tabs = self.find_elements('.tab a')
        labels = [t.text for t in tabs]
        self.assertEqual(labels, ['Top', 'Latest', 'Media', 'About'])

    def test_top_tab_active(self):
        self.open_nitter(COMMUNITY_PATH)
        self.assert_element_visible('.tab .active a[href$="/' + COMMUNITY_ID + '"]')

    def test_top_has_tweets(self):
        self.open_nitter(COMMUNITY_PATH)
        self.assert_element_visible('.timeline-item .tweet-body')

    def test_top_has_pagination(self):
        self.open_nitter(COMMUNITY_PATH)
        self.assert_element_visible('.show-more')
        self.assert_text('Load more', '.show-more')

    def test_latest_has_tweets(self):
        self.open_nitter(f'{COMMUNITY_PATH}/latest')
        self.assert_element_visible('.timeline-item .tweet-body')

    def test_latest_tab_active(self):
        self.open_nitter(f'{COMMUNITY_PATH}/latest')
        self.assert_element_visible('.tab .active a[href$="/latest"]')

    def test_media_has_tweets(self):
        self.open_nitter(f'{COMMUNITY_PATH}/media')
        self.assert_element_visible('.timeline-item .tweet-body')

    def test_media_tab_active(self):
        self.open_nitter(f'{COMMUNITY_PATH}/media')
        self.assert_element_visible('.tab .active a[href$="/media"]')

    def test_about_page(self):
        self.open_nitter(f'{COMMUNITY_PATH}/about')
        self.assert_element_visible('.community-about')
        self.assert_text('Community Info', '.community-info h2')

    def test_about_rules(self):
        self.open_nitter(f'{COMMUNITY_PATH}/about')
        self.assert_element_visible('.community-rules')
        self.assert_text('Rules', '.community-rules h2')
        rules = self.find_elements('.community-rule')
        self.assertGreater(len(rules), 0)

    def test_about_creator(self):
        self.open_nitter(f'{COMMUNITY_PATH}/about')
        self.assert_text('Created', '.community-info')
        link = self.find_element('.community-info-item a')
        self.assertTrue(link.text.startswith('@'))
        self.assertGreater(len(link.text), 1)

    def test_about_tab_active(self):
        self.open_nitter(f'{COMMUNITY_PATH}/about')
        self.assert_element_visible('.tab .active a[href$="/about"]')

    def test_about_moderators(self):
        self.open_nitter(f'{COMMUNITY_PATH}/about')
        self.assert_element_visible('.community-moderators')
        self.assert_text('Moderators', '.community-moderators h2')
        mods = self.find_elements('.community-moderator')
        self.assertGreater(len(mods), 0)

    def test_about_moderators_have_avatars(self):
        self.open_nitter(f'{COMMUNITY_PATH}/about')
        avatars = self.find_elements('.community-mod-avatar')
        self.assertGreater(len(avatars), 0)

    def test_about_moderators_link_to_profiles(self):
        self.open_nitter(f'{COMMUNITY_PATH}/about')
        links = self.find_elements('.community-mod-username')
        self.assertGreater(len(links), 0)
        for link in links:
            self.assertTrue(link.text.startswith('@'))
            self.assertTrue(link.get_attribute('href').startswith('http'))

    def test_about_see_all_link(self):
        self.open_nitter(f'{COMMUNITY_PATH}/about')
        link = self.find_element('.community-mods-link')
        self.assertEqual(link.text, 'See all')
        self.assertIn('/moderators', link.get_attribute('href'))

    def test_members_page(self):
        self.open_nitter(f'{COMMUNITY_PATH}/members')
        self.assert_element_visible('.timeline-item')
        users = self.find_elements('.timeline-item .username')
        self.assertGreater(len(users), 0)

    def test_members_has_member_tabs(self):
        self.open_nitter(f'{COMMUNITY_PATH}/members')
        tabs = self.find_elements('.tab a')
        labels = [t.text for t in tabs]
        self.assertEqual(labels, ['All', 'Moderators'])

    def test_members_all_tab_active(self):
        self.open_nitter(f'{COMMUNITY_PATH}/members')
        self.assert_element_visible('.tab .active a[href$="/members"]')

    def test_members_count_is_link(self):
        self.open_nitter(COMMUNITY_PATH)
        link = self.find_element('.community-member-count')
        self.assertIn('Members', link.text)
        self.assertIn('/members', link.get_attribute('href'))

    def test_moderators_page(self):
        self.open_nitter(f'{COMMUNITY_PATH}/moderators')
        self.assert_element_visible('.timeline-item')
        users = self.find_elements('.timeline-item .username')
        self.assertGreater(len(users), 0)

    def test_moderators_tab_active(self):
        self.open_nitter(f'{COMMUNITY_PATH}/moderators')
        self.assert_element_visible('.tab .active a[href$="/moderators"]')

    def test_moderators_has_member_tabs(self):
        self.open_nitter(f'{COMMUNITY_PATH}/moderators')
        tabs = self.find_elements('.tab a')
        labels = [t.text for t in tabs]
        self.assertEqual(labels, ['All', 'Moderators'])

    def test_pinned_tweet_label(self):
        self.open_nitter(COMMUNITY_PATH)
        self.assert_element_visible('.pinned')
        self.assert_text('Pinned by Community mods', '.pinned')

    def test_hashtags_visible(self):
        self.open_nitter(COMMUNITY_PATH)
        self.assert_element_visible('.community-tags')
        tags = self.find_elements('.community-tag')
        self.assertGreater(len(tags), 0)

    def test_hashtags_are_links(self):
        self.open_nitter(COMMUNITY_PATH)
        tags = self.find_elements('.community-tag')
        for tag in tags:
            href = tag.get_attribute('href')
            self.assertIn('/hashtag/', href)
            self.assertTrue(tag.text.startswith('#'))

    def test_hashtag_page(self):
        self.open_nitter(f'{COMMUNITY_PATH}/hashtag/buildinpublic')
        self.assert_element_visible('.timeline-item .tweet-body')

    def test_hashtag_shows_header(self):
        self.open_nitter(f'{COMMUNITY_PATH}/hashtag/buildinpublic')
        self.assert_element_visible('.community-header')
        self.assert_text('Build in Public', '.community-name')

    def test_hashtag_shows_tag_title(self):
        self.open_nitter(f'{COMMUNITY_PATH}/hashtag/buildinpublic')
        self.assert_element_visible('.community-hashtag-header')
        self.assert_text('#buildinpublic', '.community-hashtag-title')

    def test_hashtag_no_main_tabs(self):
        self.open_nitter(f'{COMMUNITY_PATH}/hashtag/buildinpublic')
        tabs = self.find_elements('.tab a')
        tab_labels = [t.text for t in tabs]
        self.assertNotIn('Top', tab_labels)
        self.assertNotIn('About', tab_labels)

    def test_category_visible(self):
        self.open_nitter(COMMUNITY_PATH)
        self.assert_element_visible('.community-category')

    def test_about_join_policy(self):
        self.open_nitter(f'{COMMUNITY_PATH}/about')
        self.assert_text('Anyone can join', '.community-info')

    def test_about_visibility_note(self):
        self.open_nitter(f'{COMMUNITY_PATH}/about')
        self.assert_text('publicly visible', '.community-info')

    def test_404_invalid_id(self):
        self.open_nitter('i/communities/999')
        self.assert_element_visible('.error-panel')
        self.assert_text('not found', '.error-panel')

    @parameterized.expand(['', '/latest', '/media', '/about',
                           '/members', '/moderators'])
    def test_page_no_error(self, suffix):
        self.open_nitter(f'{COMMUNITY_PATH}{suffix}')
        self.assert_element_not_visible('.error-panel')
