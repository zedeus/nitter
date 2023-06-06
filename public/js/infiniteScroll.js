// @license http://www.gnu.org/licenses/agpl-3.0.html AGPL-3.0
// SPDX-License-Identifier: AGPL-3.0-only
const LOADING_TEXT = "Loading...";

function insertBeforeLast(node, elem) {
    node.insertBefore(elem, node.childNodes[node.childNodes.length - 2]);
}

function getLoadMore(doc) {
    return doc.querySelector(".show-more:not(.timeline-item)");
}

function isDuplicate(item, itemClass) {
    const tweet = item.querySelector(".tweet-link");
    if (tweet == null) return false;
    const href = tweet.getAttribute("href");
    return document.querySelector(itemClass + " .tweet-link[href='" + href + "']") != null;
}

function addScrollToURL(href) {
    const url = new URL(href);
    url.searchParams.append("scroll", "true");
    return url.toString();
}

function fetchAndParse(url) {
    return fetch(url)
        .then(function (response) {
            return response.text();
        })
        .then(function (html) {
            var parser = new DOMParser();
            return parser.parseFromString(html, "text/html");
        });
}

window.onload = function () {
    const url = window.location.pathname;
    const isTweet = url.indexOf("/status/") !== -1;
    const isIncompleteThread =
        isTweet && document.querySelector(".timeline-item.more-replies") != null;

    const containerClass = isTweet ? ".replies" : ".timeline";
    const itemClass = containerClass + " > div:not(.top-ref)";

    var html = document.querySelector("html");
    var mainContainer = document.querySelector(containerClass);
    var loading = false;

    function catchErrors(err) {
        console.warn("Something went wrong.", err);
        loading = true;
    }

    function appendLoadedReplies(loadMore) {
        return function (doc) {
            loadMore.remove();

            for (var item of doc.querySelectorAll(itemClass)) {
                if (item.className == "timeline-item show-more") continue;
                if (isDuplicate(item, itemClass)) continue;
                if (isTweet) mainContainer.appendChild(item);
                else insertBeforeLast(mainContainer, item);
            }

            loading = false;
            const newLoadMore = getLoadMore(doc);
            if (newLoadMore == null) return;
            if (isTweet) mainContainer.appendChild(newLoadMore);
            else insertBeforeLast(mainContainer, newLoadMore);
        };
    }

    var scrollListener = null;
    if (!isIncompleteThread) {
        scrollListener = (e) => {
            if (loading) return;

            if (html.scrollTop + html.clientHeight >= html.scrollHeight - 3000) {
                loading = true;
                var loadMore = getLoadMore(document);
                if (loadMore == null) return;

                loadMore.children[0].text = LOADING_TEXT;

                const fetchUrl = addScrollToURL(loadMore.children[0].href);
                fetchAndParse(fetchUrl)
                    .then(appendLoadedReplies(loadMore))
                    .catch(catchErrors);
            }
        };
    } else {
        function getEarlierReplies(doc) {
            return doc.querySelector(".timeline-item.more-replies.earlier-replies");
        }

        function getLaterReplies(doc) {
            return doc.querySelector(".after-tweet > .timeline-item.more-replies");
        }

        function prependLoadedThread(loadMore) {
            return function (doc) {
                loadMore.remove();

                const targetSelector = ".before-tweet.thread-line";
                const threadContainer = document.querySelector(targetSelector);

                const earlierReplies = doc.querySelector(targetSelector);
                for (var i = earlierReplies.children.length - 1; i >= 0; i--) {
                    threadContainer.insertBefore(
                        earlierReplies.children[i],
                        threadContainer.children[0]
                    );
                }
                loading = false;
            };
        }

        function appendLoadedThread(loadMore) {
            return function (doc) {
                const targetSelector = ".after-tweet.thread-line";
                const threadContainer = document.querySelector(targetSelector);

                const laterReplies = doc.querySelector(targetSelector);
                while (laterReplies && laterReplies.firstChild) {
                    threadContainer.appendChild(laterReplies.firstChild);
                }

                const finalReply = threadContainer.lastElementChild;
                if (finalReply.classList.contains("thread-last")) {
                    fetchAndParse(finalReply.children[0].href).then(function (lastDoc) {
                        loadMore.remove();
                        const anyResponses = lastDoc.querySelector(".replies");
                        anyResponses &&
                            insertBeforeLast(
                                threadContainer.parentElement.parentElement,
                                anyResponses
                            );
                        loading = false;
                    });
                } else {
                    loadMore.remove();
                    loading = false;
                }
            };
        }

        scrollListener = (e) => {
            if (loading) return;

            if (html.scrollTop <= html.clientHeight) {
                var loadMore = getEarlierReplies(document);
                if (loadMore == null) return;
                loading = true;

                loadMore.children[0].text = LOADING_TEXT;

                fetchAndParse(loadMore.children[0].href)
                    .then(prependLoadedThread(loadMore))
                    .catch(catchErrors);
            } else if (html.scrollTop + html.clientHeight >= html.scrollHeight - 3000) {
                var loadMore = getLaterReplies(document);
                if (loadMore != null) {
                    loading = true;

                    loadMore.children[0].text = LOADING_TEXT;

                    fetchAndParse(loadMore.children[0].href)
                        .then(appendLoadedThread(loadMore))
                        .catch(catchErrors);
                } else {
                    loadMore = getLoadMore(document);
                    if (loadMore == null) return;
                    loading = true;

                    loadMore.children[0].text = LOADING_TEXT;

                    mainContainer = document.querySelector(containerClass);
                    fetchAndParse(loadMore.children[0].href)
                        .then(appendLoadedReplies(loadMore))
                        .catch(catchErrors);
                }
            }
        };
    }

    window.addEventListener("scroll", scrollListener);
};
// @license-end
