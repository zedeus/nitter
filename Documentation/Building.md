
# Building

*How to build your own instance of **Nitter**.*

<br>

## Dependencies

-   `libpcre`

-   `libsass`

-   `redis`

<br>
<br>

To compile Nitter you need a Nim installation, see
[nim-lang.org] for details. It is possible to
install it system-wide or in the user directory you create below.

To compile the scss files, you need to install `libsass`. On Ubuntu and Debian,
you can use `libsass-dev`.

Redis is required for caching and in the future for account info. It should be
available on most distros as `redis` or `redis-server` (Ubuntu/Debian).
Running it with the default config is fine, Nitter's default config is set to
use the default Redis port and localhost.

Here's how to create a `nitter` user, clone the repo, and build the project
along with the scss and md files.

```Shell
# useradd -m nitter
# su nitter
git clone https://github.com/zedeus/nitter
cd nitter
nimble build -d:release
nimble scss
nimble md
cp nitter.example.conf nitter.conf
```

Set your hostname, port, HMAC key, https (must be correct for cookies), and
Redis info in `nitter.conf`. To run Redis, either run
`redis-server --daemonize yes`, or `systemctl enable --now redis` (or
redis-server depending on the distro). Run Nitter by executing `./nitter` or
using the systemd service below. You should run Nitter behind a reverse proxy
such as [Nginx] or [Apache] for security and
performance reasons.

<br>
<br>

## Docker

#### NOTE: For ARM64/ARM support, please use [unixfox's image][Unixfox], more info [here][ARM Info]

To run Nitter with Docker, you'll need to install and run Redis separately
before you can run the container. See below for how to also run Redis using
Docker.

To build and run Nitter in Docker:

```Shell
docker build -t nitter:latest .
docker run -v $(pwd)/nitter.conf:/src/nitter.conf -d --network host nitter:latest
```

A prebuilt Docker image is provided as well:

```Shell
docker run -v $(pwd)/nitter.conf:/src/nitter.conf -d --network host zedeus/nitter:latest
```

Using docker-compose to run both Nitter and Redis as different containers:
Change `redisHost` from `localhost` to `nitter-redis` in `nitter.conf`, then run:

```Shell
docker-compose up -d
```

Note the Docker commands expect a `nitter.conf` file in the directory you run
them.

<br>
<br>

## Systemd

To run Nitter via systemd you can use this service file:

```ini
[Unit]
Description=Nitter (An alternative Twitter front-end)
After=syslog.target
After=network.target

[Service]
Type=simple

# set user and group
User=nitter
Group=nitter

# configure location
WorkingDirectory=/home/nitter/nitter
ExecStart=/home/nitter/nitter/nitter

Restart=always
RestartSec=15

[Install]
WantedBy=multi-user.target
```

Then enable and run the service:

```Shell
systemctl enable    \
    --now           \
    nitter.service
```

<br>
<br>

### Logging

Nitter currently prints some errors to stdout, and there is no real logging
implemented. If you're running Nitter with systemd, you can check stdout like
this: `journalctl -u nitter.service` (add `--follow` to see just the last 15
lines). If you're running the Docker image, you can do this:
`docker logs --follow *nitter container id*`

<br>


<!----------------------------------------------------------------------------->

[nim-lang.org]: https://nim-lang.org/install.html
[ARM Info]: https://github.com/zedeus/nitter/issues/399#issuecomment-997263495
[Unixfox]: https://quay.io/repository/unixfox/nitter?tab=tags
[Apache]: https://github.com/zedeus/nitter/wiki/Apache
[Nginx]: https://github.com/zedeus/nitter/wiki/Nginx

