window.addEventListener('load', (event) => {
    window.parent.postMessage(["resizeIframe",
    {
        "url": document.baseURI,
        "w": document.body.offsetWidth,
        "h": document.body.offsetHeight
    }
    ], "*");
})