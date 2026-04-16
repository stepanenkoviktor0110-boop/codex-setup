#!/usr/bin/env python3
"""
Agent Cleaner — auto-kills orphaned node processes from CLI agents.
Works on macOS and Linux. Checks every CHECK_INTERVAL seconds.
Kills node processes where: system RAM > threshold, parent is dead, age > minimum.
"""

import os
import time
import signal
import platform
import subprocess
from datetime import datetime

# --- Settings ---
CHECK_INTERVAL = 60          # seconds between checks
MIN_UPTIME_BEFORE_KILL = 120 # don't touch processes younger than this (seconds)
RAM_THRESHOLD = 80           # system RAM usage % to trigger cleanup

LOG_FILE = os.path.expanduser("~/agent_cleaner.log")

def log(message):
    timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    line = f"[{timestamp}] {message}"
    print(line, flush=True)
    try:
        with open(LOG_FILE, "a") as f:
            f.write(line + "\n")
    except Exception:
        pass

def get_ram_usage():
    """Get system RAM usage percentage."""
    system = platform.system()
    try:
        if system == "Darwin":
            # macOS: use vm_stat
            result = subprocess.run(["vm_stat"], capture_output=True, text=True)
            lines = result.stdout.strip().split("\n")
            page_size = 16384  # default on Apple Silicon, 4096 on Intel
            # Try to detect page size
            try:
                ps_result = subprocess.run(["sysctl", "-n", "hw.pagesize"],
                                          capture_output=True, text=True)
                page_size = int(ps_result.stdout.strip())
            except Exception:
                pass

            stats = {}
            for line in lines[1:]:
                if ":" in line:
                    key, val = line.split(":", 1)
                    val = val.strip().rstrip(".")
                    try:
                        stats[key.strip()] = int(val)
                    except ValueError:
                        pass

            free = stats.get("Pages free", 0)
            active = stats.get("Pages active", 0)
            inactive = stats.get("Pages inactive", 0)
            speculative = stats.get("Pages speculative", 0)
            wired = stats.get("Pages wired down", 0)
            compressed = stats.get("Pages stored in compressor", 0)

            total = free + active + inactive + speculative + wired + compressed
            if total == 0:
                return 0
            used = active + wired + compressed
            return (used / total) * 100

        elif system == "Linux":
            with open("/proc/meminfo") as f:
                info = {}
                for line in f:
                    parts = line.split(":")
                    if len(parts) == 2:
                        info[parts[0].strip()] = int(parts[1].strip().split()[0])
            total = info.get("MemTotal", 1)
            available = info.get("MemAvailable", total)
            return ((total - available) / total) * 100
        else:
            return 0
    except Exception as e:
        log(f"Error getting RAM: {e}")
        return 0

def get_node_processes():
    """Get list of node processes with pid, ppid, uptime."""
    system = platform.system()
    processes = []
    try:
        if system == "Darwin":
            # macOS: ps with etime
            result = subprocess.run(
                ["ps", "-eo", "pid,ppid,etime,comm"],
                capture_output=True, text=True
            )
        else:
            result = subprocess.run(
                ["ps", "-eo", "pid,ppid,etimes,comm"],
                capture_output=True, text=True
            )

        for line in result.stdout.strip().split("\n")[1:]:
            parts = line.split()
            if len(parts) < 4:
                continue
            comm = parts[3]
            # Match node processes
            if "node" not in comm.lower():
                continue
            # Skip this script's own python process
            pid = int(parts[0])
            ppid = int(parts[1])
            etime_str = parts[2]

            # Parse elapsed time
            if system == "Darwin":
                # Format: [[dd-]hh:]mm:ss
                uptime_sec = parse_etime(etime_str)
            else:
                # etimes = seconds directly
                try:
                    uptime_sec = int(etime_str)
                except ValueError:
                    uptime_sec = parse_etime(etime_str)

            processes.append({
                "pid": pid,
                "ppid": ppid,
                "uptime": uptime_sec,
                "comm": comm
            })
    except Exception as e:
        log(f"Error listing processes: {e}")
    return processes

def parse_etime(etime_str):
    """Parse ps etime format [[dd-]hh:]mm:ss to seconds."""
    total = 0
    # Handle dd- prefix
    if "-" in etime_str:
        days_str, etime_str = etime_str.split("-", 1)
        total += int(days_str) * 86400

    parts = etime_str.split(":")
    if len(parts) == 3:
        total += int(parts[0]) * 3600 + int(parts[1]) * 60 + int(parts[2])
    elif len(parts) == 2:
        total += int(parts[0]) * 60 + int(parts[1])
    elif len(parts) == 1:
        total += int(parts[0])
    return total

def is_orphan(ppid):
    """Check if parent process is dead (process is orphaned)."""
    if ppid <= 1:
        return True
    try:
        os.kill(ppid, 0)
        return False
    except ProcessLookupError:
        return True
    except PermissionError:
        return False  # parent exists but we can't signal it

def kill_process(pid):
    """Kill process by PID."""
    try:
        os.kill(pid, signal.SIGTERM)
        time.sleep(1)
        try:
            os.kill(pid, 0)
            os.kill(pid, signal.SIGKILL)
        except ProcessLookupError:
            pass
        return True
    except Exception as e:
        log(f"  Failed to kill PID {pid}: {e}")
        return False

def check_and_clean():
    """Main check cycle."""
    ram = get_ram_usage()
    if ram < RAM_THRESHOLD:
        return

    processes = get_node_processes()
    killed = 0

    for proc in processes:
        if proc["uptime"] < MIN_UPTIME_BEFORE_KILL:
            continue
        if not is_orphan(proc["ppid"]):
            continue

        log(f"Killing orphaned node PID={proc['pid']} "
            f"(ppid={proc['ppid']}, uptime={proc['uptime']}s, RAM={ram:.0f}%)")
        if kill_process(proc["pid"]):
            killed += 1

    if killed > 0:
        log(f"Cleaned {killed} orphaned node process(es)")

def main():
    log(f"Agent Cleaner started (interval={CHECK_INTERVAL}s, "
        f"ram_threshold={RAM_THRESHOLD}%, min_uptime={MIN_UPTIME_BEFORE_KILL}s)")

    while True:
        try:
            check_and_clean()
        except Exception as e:
            log(f"Error in check cycle: {e}")
        time.sleep(CHECK_INTERVAL)

if __name__ == "__main__":
    main()
