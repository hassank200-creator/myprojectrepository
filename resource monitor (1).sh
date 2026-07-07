#!/bin/bash
#
# resource_monitor.sh
# Monitors CPU, memory, and disk usage and sends alerts if thresholds are exceeded.
#
# Usage:
#   ./resource_monitor.sh
#
# Optional: set up as a cron job to run periodically, e.g. every 5 minutes:
#   */5 * * * * /path/to/resource_monitor.sh >> /var/log/resource_monitor.log 2>&1
#

# ----------------------------
# CONFIGURATION
# ----------------------------
CPU_THRESHOLD=80        # in percent
MEM_THRESHOLD=80         # in percent
DISK_THRESHOLD=80        # in percent
DISK_PATH="/"             # partition to check (change if monitoring another mount)

LOG_FILE="/var/log/resource_monitor.log"

# Email alert settings (requires 'mail' or 'mailx' installed and configured)
ENABLE_EMAIL_ALERT=false
ALERT_EMAIL="you@example.com"

# ----------------------------
# HELPER FUNCTIONS
# ----------------------------

timestamp() {
    date '+%Y-%m-%d %H:%M:%S'
}

log_message() {
    echo "[$(timestamp)] $1" | tee -a "$LOG_FILE"
}

send_alert() {
    local subject="$1"
    local message="$2"

    log_message "ALERT: $message"

    if [ "$ENABLE_EMAIL_ALERT" = true ]; then
        if command -v mail &> /dev/null; then
            echo "$message" | mail -s "$subject" "$ALERT_EMAIL"
        else
            log_message "WARNING: 'mail' command not found, cannot send email alert."
        fi
    fi
}

# ----------------------------
# CHECK CPU USAGE
# ----------------------------
check_cpu() {
    # Average CPU usage over 1 second sample using /proc/stat
    read -r cpu user nice system idle iowait irq softirq steal _ < /proc/stat
    total_before=$((user + nice + system + idle + iowait + irq + softirq + steal))
    idle_before=$idle

    sleep 1

    read -r cpu user nice system idle iowait irq softirq steal _ < /proc/stat
    total_after=$((user + nice + system + idle + iowait + irq + softirq + steal))
    idle_after=$idle

    total_diff=$((total_after - total_before))
    idle_diff=$((idle_after - idle_before))

    cpu_usage=$(( (100 * (total_diff - idle_diff)) / total_diff ))

    log_message "CPU Usage: ${cpu_usage}%"

    if [ "$cpu_usage" -ge "$CPU_THRESHOLD" ]; then
        send_alert "High CPU Usage Alert" "CPU usage is at ${cpu_usage}%, exceeding threshold of ${CPU_THRESHOLD}%."
    fi
}

# ----------------------------
# CHECK MEMORY USAGE
# ----------------------------
check_memory() {
    mem_total=$(awk '/MemTotal/ {print $2}' /proc/meminfo)
    mem_available=$(awk '/MemAvailable/ {print $2}' /proc/meminfo)
    mem_used=$((mem_total - mem_available))
    mem_usage=$(( (100 * mem_used) / mem_total ))

    log_message "Memory Usage: ${mem_usage}%"

    if [ "$mem_usage" -ge "$MEM_THRESHOLD" ]; then
        send_alert "High Memory Usage Alert" "Memory usage is at ${mem_usage}%, exceeding threshold of ${MEM_THRESHOLD}%."
    fi
}

# ----------------------------
# CHECK DISK USAGE
# ----------------------------
check_disk() {
    disk_usage=$(df -h "$DISK_PATH" | awk 'NR==2 {print $5}' | tr -d '%')

    log_message "Disk Usage ($DISK_PATH): ${disk_usage}%"

    if [ "$disk_usage" -ge "$DISK_THRESHOLD" ]; then
        send_alert "High Disk Usage Alert" "Disk usage on ${DISK_PATH} is at ${disk_usage}%, exceeding threshold of ${DISK_THRESHOLD}%."
    fi
}

# ----------------------------
# MAIN
# ----------------------------
log_message "----- Resource check started -----"
check_cpu
check_memory
check_disk
log_message "----- Resource check completed -----"
