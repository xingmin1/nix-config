# tuf3 磁盘休眠与一次性 RTC 唤醒

2026-11-23 晚间设置一次性闹钟，目标为北京时间 2026-11-24 08:00:00。内核报告 `rtc_cmos PNP0B00:00: RTC can wake from S4`，`/sys/class/rtc/rtc0/device/power/wakeup` 为 `enabled`。logind 的 `CanHibernate` 返回 `yes`，`/sys/power/disk` 选中 `platform`，同一次开机的历史日志有成功磁盘休眠及恢复。配置里的 systemd 休眠服务负责处理 PEG1 唤醒源。

- 双系统使用 `LocalRTC=yes`，`/etc/adjtime` 为 `LOCAL`。用 `TZ=Asia/Shanghai date -d '2026-11-24 08:00:00' +%s` 得到 Unix 时间 `1795478400`，以管理员权限执行 `rtcwake --local --device rtc0 --mode no --time 1795478400`，仅写硬件闹钟。写入前检查没有已有闹钟。
- 写入后使用 `rtcwake --local --device rtc0 --mode show` 回读为 `alarm: on  Tue Nov 24 08:00:00 2026`。`/proc/driver/rtc` 显示 `alarm_IRQ: yes`，硬件时钟闹钟为 `07:59:55`，其中五秒差异来自 RTC 与系统钟的偏差补偿。sysfs 原始读数为 `1795507195`，该接口将本地 RTC 日历值按 UTC 形式转换成秒数。
- 通过 `systemctl hibernate` 使用系统已有的磁盘休眠流程。闹钟读回验证只证明设置成功，实际唤醒由硬件在次日触发。 [util-linux RTC 唤醒机制](https://man7.org/linux/man-pages/man8/rtcwake.8.html)
