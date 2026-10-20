# XGSI da1adf94cf77
#!/system/bin/sh

dir=""
i=0
while [ $i -lt 120 ]; do
    for base in /cache /metadata /data; do
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
            dir="$base/xgsi"
            break
        fi
    done
    [ -n "$dir" ] && break
    sleep 1
    i=$((i + 1))
done

if [ -z "$dir" ]; then
    echo "XGSI: nowhere persistent for the boot log" > /dev/kmsg
    exit 1
fi

[ -f "$dir/boot.log" ] && mv -f "$dir/boot.log" "$dir/boot.prev.log" 2>/dev/null
echo "XGSI: boot log -> $dir/boot.log" > /dev/kmsg
exec logcat -b all -v threadtime,uid -f "$dir/boot.log" -r 4096 -n 5
