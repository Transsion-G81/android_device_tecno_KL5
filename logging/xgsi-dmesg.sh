# XGSI da1adf94cf77
#!/system/bin/sh

pick_dir() {
    for base in "$@"; do
        [ -d "$base" ] || continue
        fstype=""
        while read -r _src mnt type _rest; do
            [ "$mnt" = "$base" ] && fstype="$type" && break
        done < /proc/mounts
        case "$fstype" in
            "" | tmpfs | ramfs | rootfs) continue ;;
        esac
        mkdir -p "$base/xgsi" 2>/dev/null || continue
        if : > "$base/xgsi/.probe" 2>/dev/null; then
            rm -f "$base/xgsi/.probe"
            echo "$base/xgsi"
            return 0
        fi
    done
    return 1
}

kdir=""
ldir=""
i=0
while [ $i -lt 120 ]; do
    [ -n "$kdir" ] || kdir=$(pick_dir /persist /mnt/vendor/persist /metadata /cache /data)
    [ -n "$ldir" ] || ldir=$(pick_dir /cache /metadata /data /persist)
    [ -n "$kdir" ] && [ -n "$ldir" ] && break
    sleep 1
    i=$((i + 1))
done

if [ -z "$kdir" ]; then
    echo "XGSI: nowhere persistent for the kernel log" > /dev/kmsg
    exit 1
fi

[ -f "$kdir/dmesg.log" ] && mv -f "$kdir/dmesg.log" "$kdir/dmesg.prev.log" 2>/dev/null
[ -n "$ldir" ] && [ -f "$ldir/logcat.log" ] && mv -f "$ldir/logcat.log" "$ldir/logcat.prev.log" 2>/dev/null
[ -n "$ldir" ] && [ -f "$ldir/crash.log" ] && mv -f "$ldir/crash.log" "$ldir/crash.prev.log" 2>/dev/null
echo "XGSI: kernel log -> $kdir/dmesg.log, logcat -> ${ldir:-none}/logcat.log" > /dev/kmsg

pstore_dir="${ldir:-$kdir}"
grab_pstore() {
    [ -d /sys/fs/pstore ] || return 1
    got=0
    for f in /sys/fs/pstore/*; do
        [ -f "$f" ] || continue
        name=$(basename "$f")
        cat "$f" > "$pstore_dir/pstore-$name.log" 2>/dev/null && got=1
    done
    [ -f /proc/last_kmsg ] && cat /proc/last_kmsg > "$pstore_dir/last_kmsg.log" 2>/dev/null && got=1
    [ "$got" = 1 ] || return 1
    echo "XGSI: previous boot's console -> $pstore_dir/pstore-*.log" > /dev/kmsg
    return 0
}
for f in "$pstore_dir"/pstore-*.log "$pstore_dir/last_kmsg.log"; do
    [ -f "$f" ] && mv -f "$f" "${f%.log}.prev.log" 2>/dev/null
done
pstore_done=0
grab_pstore && pstore_done=1

if command -v timeout >/dev/null 2>&1; then
    LIMIT="timeout 5"
else
    LIMIT=""
fi

complained=0
i=0
while [ $i -lt 900 ]; do
    if [ "$pstore_done" = 0 ]; then
        grab_pstore && pstore_done=1
    fi
    if ! $LIMIT dmesg > "$kdir/dmesg.new" 2>/dev/null; then
        [ $complained -eq 0 ] && echo "XGSI: cannot write $kdir - out of space?" > /dev/kmsg
        complained=1
    else
        mv -f "$kdir/dmesg.new" "$kdir/dmesg.log"
    fi
    if [ -n "$ldir" ]; then
        $LIMIT logcat -d -b crash -v threadtime > "$ldir/crash.new" 2>/dev/null \
            && mv -f "$ldir/crash.new" "$ldir/crash.log"
    fi
    if [ -n "$ldir" ]; then
        if ! $LIMIT logcat -d -b all -v threadtime -t 200000 > "$ldir/logcat.new" 2>/dev/null; then
            [ $complained -eq 0 ] && echo "XGSI: cannot write $ldir - out of space?" > /dev/kmsg
            complained=1
        else
            mv -f "$ldir/logcat.new" "$ldir/logcat.log"
        fi
    fi
    sync
    [ "$(getprop sys.boot_completed)" = "1" ] && break
    sleep 2
    i=$((i + 1))
done
