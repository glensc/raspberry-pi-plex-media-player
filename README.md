# Raspberry Pi Plex Media Player

Build Raspberry Pi Plex Media Player based on [Pi My Life Up blog post][1].

[1]: https://pimylifeup.com/raspberry-pi-plex-media-player/

## Buildings

It's recommended to use BuildKit to speed up and run jobs in parallel.

```shell
export DOCKER_BUILDKIT=1
docker build .
```

Or use buildx, which has BuildKit already enabled:

```shell
docker buildx build .
```

To build only specific target:
```sh
docker build --target=mkv-build .
docker build --target=qt-build .
```
