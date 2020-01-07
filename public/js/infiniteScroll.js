function insertBeforeLast(node, elem) {
    node.insertBefore(elem, node.childNodes[node.childNodes.length - 2]);
}

function getLoadMore(doc) {
    return doc.querySelector('.show-more:not(.timeline-item)');
}

window.onload = function() {
    const isTweet = window.location.pathname.indexOf("/status/") !== -1;
    const containerClass = isTweet ? ".replies" : ".timeline";
    const itemClass = isTweet ? ".thread-line" : ".timeline-item";

    var html = document.querySelector("html");
    var container = document.querySelector(containerClass);
    var loading = false;

    window.addEventListener('scroll', function() {
        if (loading) return;
        if (html.scrollTop + html.clientHeight >= html.scrollHeight - 3000) {
            loading = true;
            var topRef = document.querySelector('.top-ref');
            var loadMore = getLoadMore(document);
            if (loadMore == null) return;

            loadMore.children[0].text = "Loading...";

            var url = new URL(loadMore.children[0].href);
            window.history.pushState('', '', url.toString());
            url.searchParams.append('scroll', 'true');

            fetch(url.toString()).then(function (response) {
	            return response.text();
            }).then(function (html) {
                var parser = new DOMParser();
                var doc = parser.parseFromString(html, 'text/html');
                loadMore.remove();

                for (var item of doc.querySelectorAll(itemClass)) {
                    if (item.className == "timeline-item show-more") continue;
                    if (isTweet) container.appendChild(item);
                    else insertBeforeLast(container, item);
                }

                if (isTweet) container.appendChild(getLoadMore(doc));
                else insertBeforeLast(container, getLoadMore(doc));
                loading = false;
            }).catch(function (err) {
	            console.warn('Something went wrong.', err);
                loading = true;
            });
        }
    });
};
