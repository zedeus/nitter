import subprocess
from parameterized import parameterized

BASE_URL = 'http://localhost:8080'


def curl_status(url):
    """Get HTTP status code using curl to avoid URL normalization by Python libs."""
    result = subprocess.run(
        ['curl', '-s', '-o', '/dev/null', '-w', '%{http_code}', url],
        capture_output=True, text=True, timeout=30
    )
    return int(result.stdout)


class TestMalformedPaths:
    """Test that malformed paths don't crash the server.

    URLs like //foo are parsed as having 'foo' as the authority (host),
    resulting in an empty path. Empty paths previously crashed jester's
    static file handler. Now they return 400.

    URLs like //foo/bar are parsed as authority='foo', path='/bar',
    so they route normally (not empty path).
    """

    @parameterized.expand([
        # These parse to empty paths -> 400
        ('//lefty_rae', 400),
        ('//test', 400),
        ('//anyuser', 400),
    ])
    def test_empty_path_returns_400(self, path, expected_status):
        """URLs that parse to empty paths should return 400, not crash."""
        status = curl_status(f'{BASE_URL}{path}')
        assert status == expected_status, \
            f'Expected {expected_status} for {path}, got {status}'

    @parameterized.expand([
        ('/jack', 200),
        ('/about', 200),
        ('/', 200),
    ])
    def test_normal_paths_work(self, path, expected_status):
        """Normal paths should still work."""
        status = curl_status(f'{BASE_URL}{path}')
        assert status == expected_status, \
            f'Expected {expected_status} for {path}, got {status}'

    def test_server_survives_malformed_requests(self):
        """Server should handle malformed requests without crashing."""
        # These all parse to empty paths
        malformed_paths = ['//a', '//b', '//c', '//user', '//test']
        for path in malformed_paths:
            status = curl_status(f'{BASE_URL}{path}')
            assert status == 400, f'Expected 400 for {path}, got {status}'

        # Verify server is still responding after malformed requests
        status = curl_status(f'{BASE_URL}/')
        assert status == 200, 'Server should still be alive'
