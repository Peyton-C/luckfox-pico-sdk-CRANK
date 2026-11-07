# Building in a container
The SDK expects Ubuntu 22.04. Building directly on a newer host (e.g. Fedora 44) fails, for example the kernel build dies on a missing `openssl/engine.h`. Build inside a container instead, either rootless podman or docker.

Every command below has a podman and a docker form. Pick one per SDK tree, since mixing them leaves files with different owners (see [Gotchas](#gotchas)).

If `docker` can't connect, it's probably pointed at Docker Desktop. Switch to the system daemon with `docker context use default`.

## Create the image
The image is defined by the `Dockerfile` in the SDK root. Build it once from the SDK root (rebuild after changing the `Dockerfile`):
```sh
podman build -t luckfox-build .
docker build -t luckfox-build .
```

`.dockerignore` excludes everything, so the multi-GB SDK isn't sent as build context. The SDK is mounted at run time instead.

## Build an image
Run from the SDK root. The SDK is mounted at `/sdk` (`:Z` relabels it for SELinux).

```sh
podman run --rm -v "$PWD":/sdk:Z -w /sdk localhost/luckfox-build bash -c \
  "ln -rfs project/cfg/BoardConfig_IPC/<BOARD_CONFIG>.mk .BoardConfig.mk && ./build.sh 2>&1 | tee build.log"
docker run --rm -v "$PWD":/sdk:Z -w /sdk luckfox-build bash -c \
  "ln -rfs project/cfg/BoardConfig_IPC/<BOARD_CONFIG>.mk .BoardConfig.mk && ./build.sh 2>&1 | tee build.log"
```

Common board configs (all in `project/cfg/BoardConfig_IPC/`):

| Board | Config |
|---|---|
| Pico Mini (SPI NAND) | `BoardConfig-SPI_NAND-Buildroot-RV1103_Luckfox_Pico_Mini-IPC.mk` |
| Pico Mini (SD card) | `BoardConfig-SD_CARD-Buildroot-RV1103_Luckfox_Pico_Mini-IPC.mk` |
| Pico Pro Max (SPI NAND) | `BoardConfig-SPI_NAND-Buildroot-RV1106_Luckfox_Pico_Pro_Max-IPC.mk` |

Setting `.BoardConfig.mk` with `ln` skips the interactive `./build.sh lunch` menu, which hangs a non-interactive build.

Output lands in `output/image/` (`update.img` plus the individual partition images), with a dated copy under `IMAGE/`.

## Building over SSH
Start the build inside tmux so it survives disconnecting. Rootless podman containers get killed when you log out unless linger is enabled, and with docker the build log would otherwise be lost.

```sh
tmux new-session -d -s build 'podman run --rm -v "$PWD":/sdk:Z -w /sdk localhost/luckfox-build bash -c \
  "ln -rfs project/cfg/BoardConfig_IPC/<BOARD_CONFIG>.mk .BoardConfig.mk && ./build.sh" > build.log 2>&1'
tmux new-session -d -s build 'docker run --rm -v "$PWD":/sdk:Z -w /sdk luckfox-build bash -c \
  "ln -rfs project/cfg/BoardConfig_IPC/<BOARD_CONFIG>.mk .BoardConfig.mk && ./build.sh" > build.log 2>&1'
```

Check on it with `tmux attach -t build` (detach with `Ctrl-b d`) or `tail -f build.log`.

## Switching boards / clean builds
Run a clean when switching between boards:

```sh
podman run --rm -v "$PWD":/sdk:Z -w /sdk localhost/luckfox-build ./build.sh clean
docker run --rm -v "$PWD":/sdk:Z -w /sdk luckfox-build ./build.sh clean
```

`clean` deletes `.BoardConfig.mk`, so set it again with `ln` before the next build.

## Gotchas
- **Always run `build.sh` inside the container**, including `clean`. Files the build creates can end up owned by someone other than you on the host, and then the host user can't delete them, so a host-side `./build.sh clean` fails with `Permission denied`:
  - **podman:** tarballs extracted during the build keep their original owners, which show up as a high subuid (e.g. `525287`, which is container UID 1000).
  - **docker:** the container runs as real root, so everything it creates is owned by `root`.
- To take ownership back on the host (no sudo needed):
  ```sh
  podman unshare chown -R 0:0 .
  docker run --rm -v "$PWD":/sdk:Z luckfox-build chown -R "$(id -u):$(id -g)" /sdk
  ```
- Don't mix host and container builds in the same tree.
