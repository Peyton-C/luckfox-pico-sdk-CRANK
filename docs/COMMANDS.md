# Various commands
## Basics
### Health checks
```sh
cat /sys/class/thermal/thermal_zone0/temp     # SoC temp in millidegrees C
top                                           # CPU load
free                                          # memory
dmesg | grep -iE "sc3336|rkisp|rkcif|err"     # sensor and ISP errors
df -h                                         # disk space, check /userdata and /oem
```

### Board config menu
Menu for pin muxing, enabling interfaces and USB host/peripheral mode.

```sh
luckfox-config
```

### Get connected model
Board
```sh
cat /proc/device-tree/model; echo
```

SOC (should be rv1103 or rv1106)
```sh
tr '\0' '\n' < /proc/device-tree/compatible
```

### Using vi
Open a file with `vi <file>`. `nano` is also available if you prefer it.

| Key | Action |
|-----|--------|
| `i` | Enter insert mode to type |
| `Esc` | Leave insert mode |
| `:wq` | Save and exit |
| `:q!` | Exit without saving |
| `/text` | Search for text, `n` for next match |
| `dd` | Delete the current line |
| `u` | Undo |

### Image and kernel info
```sh
uname -a
cat /etc/os-release
```

### Check Uptime
```sh
uptime
```

## Network and Access
### Setting the IP
Replace usb0 with the interface name you want from `ip a`. This is lost on reboot.

```sh
ip addr flush usb0
ip addr add 192.168.10.100/24 dev usb0
ip link set usb0 up
```

### Setting the IP permanently
On boot, `RkLunch.sh` runs `udhcpc` on eth0 and `dhcpcd` also manages it. Replace the DHCP call with a static address and tell dhcpcd to leave eth0 alone.

In `/oem/usr/bin/RkLunch.sh`, inside `network_init()`, change:
```sh
ifconfig eth0 up && udhcpc -i eth0 >/dev/null 2>&1
```
to:
```sh
ip addr flush eth0
ip addr add 192.168.10.100/24 dev eth0
ip link set eth0 up
```

Then:
```sh
echo "denyinterfaces eth0" >> /etc/dhcpcd.conf
reboot
```

The usb0 IP (default 172.32.0.93) is set by `TARGET_IP` in `/etc/init.d/S99usb0config`.

### Ethernet link status
Speed in Mbps and whether the link is up. dmesg shows link up/down events.

```sh
cat /sys/class/net/eth0/speed /sys/class/net/eth0/operstate
dmesg | grep -i eth0
```

### Finding the board's IP
Run on your computer after plugging in the board. Or use `adb shell ip a`.

```sh
ip neigh
```

### Throughput testing
requires iperf3 on the host and connected computer.
```sh
iperf3 -s                          # on the board
iperf3 -c 192.168.10.100           # on your computer, board to computer is -R
```

5 minute bidirectional test
```sh
iperf3 -s                                        # on the board
iperf3 -c 192.168.10.100 --bidir -t 300 -i 10    # on your computer
```

### Lateny and jitter testing
```sh
ping -i 0.2 192.168.10.100
```

### Copying files to and from the board via ssh
```sh
scp file root@192.168.10.100:/root/
scp root@192.168.10.100:/path/to/file .
```

### ADB
Run these on your computer with the board plugged in over USB.

```sh
adb devices                          # list connected boards and their serials
adb shell                            # open a shell on the board
adb shell cat /proc/rkisp-vir0       # run a single command
adb push file /root/                 # copy a file to the board
adb pull /path/to/file .             # copy a file from the board
```

If more than one board is connected, pick one by serial with `-s`:
```sh
adb -s <serial> shell
```

ADB also works over the network:
```sh
adb connect 192.168.10.100:5555
adb disconnect 192.168.10.100:5555
```

If the board stops showing up, restart the adb server:
```sh
adb kill-server && adb start-server
```

## Video / Camera
### Changing rkipc settings
`/userdata/rkipc.ini` is overwritten from `/oem/usr/share/rkipc-300w.ini` on every boot, so edit the `/oem` copy.

```sh
vi /oem/usr/share/rkipc-300w.ini
RkLunch-stop.sh && RkLunch.sh
```

### Running rkipc in the foreground
Shows rkipc's logs, useful when the stream won't start. Ctrl+C to stop, then `RkLunch.sh` to restart normally.

```sh
RkLunch-stop.sh
rkipc -a /oem/usr/share/iqfiles
```

### Sensor (CIF) info
Shows the framerate coming from the sensor before the ISP. Look for `fps:` and `rate:`.

```sh
cat /proc/rkcif-mipi-lvds
```

### ISP info
`rate:` is milliseconds per frame (33ms = 30fps). `frameloss:` should stay at 0.

```sh
cat /proc/rkisp-vir0
```

### Check ISP reported framerate over a short bit of time
```sh
a=$(grep -o 'frame:[0-9]*' /proc/rkisp-vir0 | tail -1 | cut -d: -f2); sleep 10
b=$(grep -o 'frame:[0-9]*' /proc/rkisp-vir0 | tail -1 | cut -d: -f2); echo $(( (b-a)/10 ))fps
```

### Video encoder info
`RealFps*10` = 300 is the expected result for 30fps.

```sh
cat /proc/vcodec/enc/venc_info
```

### Watch the whole pipeline
Prints CIF, ISP, encoder and memory stats every 5 seconds.

```sh
/rockchip_test/runtime_monitor.sh -i 5
```

### Low latency viewing
Requires MPV.
```sh
mpv \
  --profile=low-latency \
  --rtsp-transport=tcp \
  --no-cache \
  --cache-secs=0 \
  --demuxer-readahead-secs=0 \
  --untimed \
  --no-audio \
  --vd-lavc-threads=1 \
  --demuxer-lavf-o=fflags=nobuffer,flags=low_delay,probesize=32,analyzeduration=0,max_delay=0 \
  "rtsp://192.168.10.100/live/0"
```

### Recording
Requires ffmpeg.
```sh
ffmpeg -rtsp_transport tcp -i rtsp://192.168.10.100/live/0 -c copy out.mkv
```