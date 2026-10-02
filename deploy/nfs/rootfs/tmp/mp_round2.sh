#!/bin/sh
# 第二轮：验证"去掉 -srate / 去掉 -zoom"是否解决卡顿，并对比原始 800x600 片源
RUN_SECONDS=20

busy_cpu() {
    awk '/^cpu /{print $2+$3+$4+$7+$8}' /proc/stat
}

run_case() {
    name="$1"
    file="$2"
    shift 2

    killall -9 mplayer 2>/dev/null
    sleep 1

    nohup /bin/mplayer -slave -idle -noconsolecontrols "$@" "$file" \
        >"/tmp/r2_$name.log" 2>&1 &

    sleep 3

    c1=$(busy_cpu)
    sleep "$RUN_SECONDS"
    c2=$(busy_cpu)

    echo "### $name"
    echo "    文件     : $file"
    echo "    系统忙CPU: $((c2 - c1)) jiffies/${RUN_SECONDS}s = $(( (c2 - c1) * 100 / RUN_SECONDS ))% 单核"
    echo -n "    A-V      : "
    tr '\r' '\n' < "/tmp/r2_$name.log" | grep -E '^A:' | tail -1
    grep -a -q "too SLOW" "/tmp/r2_$name.log" && echo "    mplayer  : *** too SLOW ***"
    grep -a -m1 "AO:" "/tmp/r2_$name.log" | sed 's/^/    /'
    grep -a -m1 "VO:" "/tmp/r2_$name.log" | sed 's/^/    /'
    echo

    killall -9 mplayer 2>/dev/null
    sleep 1
}

echo "== 第二轮 A/B（片源 /video/demo_520x330.mp4 为 520x330 Baseline 670kbps）=="
echo

run_case best_520x330 /video/demo_520x330.mp4 \
    -vo fbdev2:/dev/fb0 -geometry 0:55 \
    -ao alsa:device=plughw=0.1 -channels 2 \
    -framedrop -hardframedrop -cache 8192 -cache-min 5 -autosync 30

run_case zoom_520x330 /video/demo_520x330.mp4 \
    -vo fbdev2:/dev/fb0 -geometry 0:55 -zoom -x 520 -y 330 \
    -ao alsa:device=plughw=0.1 -channels 2 \
    -framedrop -hardframedrop -cache 8192 -cache-min 5 -autosync 30

run_case best_800x600 /video/test.avi \
    -vo fbdev2:/dev/fb0 -geometry 0:55 \
    -ao alsa:device=plughw=0.1 -channels 2 \
    -framedrop -hardframedrop -cache 8192 -cache-min 5 -autosync 30

echo "== 结束 =="
