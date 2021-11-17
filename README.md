# Raspberry Pi Plex Media Player

Build Raspberry Pi Plex Media Player based on [Pi My Life Up blog post][1].

[1]: https://pimylifeup.com/raspberry-pi-plex-media-player/

## Buildings

It's recommended to use BuildKit to speed up and run jobs in parallel.

The build output in form of tar file is placed to directory `out`.

```shell
export DOCKER_BUILDKIT=1
docker build --platform=linux/arm . -o out
```

Or use buildx, which has BuildKit already enabled:

```shell
docker buildx build --platform=linux/arm . -o out
```

To build only specific target:
```sh
docker build --target=mkv-build .
docker build --target=qt-build .
```

To build for a different platform:

```shell
docker build --target=qt-build --platform=linux/arm .
```
