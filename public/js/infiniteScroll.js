// @license http://www.gnu.org/licenses/agpl-3.0.html AGPL-3.0
// SPDX-License-Identifier: AGPL-3.0-only
function insertBeforeLast(node, elem) {
    node.insertBefore(elem, node.childNodes[node.childNodes.length - 2]);
}

function getLoadMore(doc) {
    return doc.querySelector('.show-more:not(.timeline-item)');
}

function isDuplicate(item, itemClass) {
    const tweet = item.querySelector(".tweet-link");
    if (tweet == null) return false;
    const href = tweet.getAttribute("href");
    return document.querySelector(itemClass + " .tweet-link[href='" + href + "']") != null;
}

window.onload = function() {
    const url = window.location.pathname;
    const isTweet = url.indexOf("/status/") !== -1;
    const containerClass = isTweet ? ".replies" : ".timeline";
    const itemClass = containerClass + ' > div:not(.top-ref)';

    var html = document.querySelector("html");
    var container = document.querySelector(containerClass);
    var loading = false;

    window.addEventListener('scroll', function() {
        if (loading) return;
        if (html.scrollTop + html.clientHeight >= html.scrollHeight - 3000) {
            loading = true;
            var loadMore = getLoadMore(document);
            if (loadMore == null) return;

            loadMore.children[0].text = "Loading...";

            var url = new URL(loadMore.children[0].href);
            url.searchParams.append('scroll', 'true');

            fetch(url.toString()).then(function (response) {
                return response.text();
            }).then(function (html) {
                var parser = new DOMParser();
                var doc = parser.parseFromString(html, 'text/html');
                loadMore.remove();

                for (var item of doc.querySelectorAll(itemClass)) {
                    if (item.className == "timeline-item show-more") continue;
                    if (isDuplicate(item, itemClass)) continue;
                    if (isTweet) container.appendChild(item);
                    else insertBeforeLast(container, item);
                }

                loading = false;
                const newLoadMore = getLoadMore(doc);
                if (newLoadMore == null) return;
                if (isTweet) container.appendChild(newLoadMore);
                else insertBeforeLast(container, newLoadMore);
            }).catch(function (err) {
                console.warn('Something went wrong.', err);
                loading = true;
            });
        }
    });
};
// @license-end
