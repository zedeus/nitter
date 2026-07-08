from parameterized import parameterized

from base import BaseTestCase, Search

# [url, expected active tab label]
active_tabs = [
    ['search?f=tweets&q=nasa', 'Latest'],
    ['search?f=top&q=nasa', 'Top'],
    ['search?f=media&q=nasa', 'Media'],
    ['search?f=users&q=nasa', 'Users'],
    ['search?f=lists&q=test', 'Lists'],
    # unknown/hostile values fall back to Latest
    ['search?f=garbage&q=nasa', 'Latest'],
    ['search?f=%3Cscript%3E&q=nasa', 'Latest'],
    # x.com URL compat: f=live/user/list (f=media/top match natively)
    ['search?f=live&q=nasa', 'Latest'],
    ['search?f=user&q=nasa', 'Users'],
    ['search?f=list&q=test', 'Lists'],
]

results_pages = [
    ['search?f=tweets&q=nasa'],
    ['search?f=top&q=nasa'],
    ['search?f=media&q=nasa'],
]


class SearchProductTest(BaseTestCase):
    @parameterized.expand(active_tabs)
    def test_active_tab(self, page, expected_active):
        self.open_nitter(page)
        active = self.get_text(Search.tab_active)
        self.assert_equal(active.strip(), expected_active)

    def test_all_tabs_present(self):
        self.open_nitter('search?f=tweets&q=nasa')
        tabs = self.find_elements(Search.tab_item)
        labels = [t.text.strip() for t in tabs]
        self.assert_equal(labels, ['Top', 'Latest', 'Media', 'Users', 'Lists'])

    @parameterized.expand(results_pages)
    def test_results_render(self, page):
        self.open_nitter(page)
        self.assert_element('.timeline .timeline-item')

    def test_tab_links_carry_kind(self):
        self.open_nitter('search?f=tweets&q=nasa')
        self.assert_element('.tab-item a[href="?f=top&q=nasa"]')
        self.assert_element('.tab-item a[href="?f=media&q=nasa"]')
        self.assert_element('.tab-item a[href="?f=tweets&q=nasa"]')
        self.assert_element('.tab-item a[href="?f=users&q=nasa"]')
        self.assert_element('.tab-item a[href="?f=lists&q=nasa"]')

    def test_show_more_preserves_kind(self):
        self.open_nitter('search?f=media&q=nasa')
        href = self.get_attribute('.show-more a', 'href')
        self.assert_true('f=media' in href, f'f=media missing from: {href}')

    def test_search_form_preserves_kind(self):
        self.open_nitter('search?f=top&q=nasa')
        self.assert_element_present('.search-field input[name="f"][value="top"]')

    def test_media_operators_compose(self):
        self.open_nitter('search?f=media&q=nasa&e-nativeretweets=on')
        self.assert_element('.timeline .timeline-item')

    @parameterized.expand([['DAAC'], ['AB'], ['maxid:'], ['maxid:abc']])
    def test_garbage_cursor_no_crash(self, cursor):
        # short/invalid cursors must render the page, not a 500 error
        self.open_nitter(f'search?f=media&q=nasa&cursor={cursor}')
        self.assert_element(Search.tab_active)

    def test_no_results(self):
        self.open_nitter('search?f=media&q=xkqzjwv_no_results_2026')
        self.assert_text('No items found', '.timeline-none')

    def test_list_results_render(self):
        self.open_nitter('search?f=lists&q=test')
        self.assert_element('.timeline-item.list-result')
        self.assert_element('.list-result .list-name')
        self.assert_element('.list-result .list-members')

    def test_list_card_links_to_list(self):
        self.open_nitter('search?f=lists&q=test')
        href = self.get_attribute('.list-result .list-name', 'href')
        self.assert_true('/i/lists/' in href, f'unexpected list link: {href}')

    def test_list_row_clickable(self):
        self.open_nitter('search?f=lists&q=test')
        href = self.get_attribute('.list-result a.tweet-link', 'href')
        self.assert_true('/i/lists/' in href, f'unexpected row link: {href}')

    def test_list_avatar_links_to_user(self):
        self.open_nitter('search?f=lists&q=test')
        # the avatar link in a row must point at the user named in that row
        row = '.list-result:has(a.facepile-link)'
        self.assert_element(f'{row} a.facepile-link > img')
        href = self.get_attribute(f'{row} a.facepile-link', 'href')
        ctx = self.get_text(f'{row} .list-result-context')
        mentioned = ctx.split('@')[-1].strip()
        self.assert_true(href.endswith('/' + mentioned),
                         f'avatar link {href} does not match @{mentioned}')

    def test_list_pagination_preserves_kind(self):
        self.open_nitter('search?f=lists&q=test')
        href = self.get_attribute('.show-more a', 'href')
        self.assert_true('f=lists' in href, f'f=lists missing from: {href}')

    def test_list_garbage_cursor_no_crash(self):
        self.open_nitter('search?f=lists&q=test&cursor=DAAC')
        self.assert_element(Search.tab_active)

    def test_media_view_tabs_present(self):
        self.open_nitter('search?f=media&q=nasa')
        tabs = self.find_elements('.media-view-tabs .tab-item')
        labels = [t.text.strip() for t in tabs]
        self.assert_equal(labels, ['Timeline', 'Grid', 'Gallery'])

    def test_media_view_grid(self):
        self.open_nitter('search?f=media&q=nasa&view=grid')
        self.assert_element('.timeline.media-grid-view')

    def test_media_view_gallery(self):
        self.open_nitter('search?f=media&q=nasa&view=gallery')
        self.assert_element('.timeline.media-gallery-view .gallery-masonry')

    def test_media_view_tabs_only_on_media(self):
        self.open_nitter('search?f=tweets&q=nasa')
        self.assert_element_not_present('.media-view-tabs')
