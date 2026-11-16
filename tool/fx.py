#!/usr/bin/env python3
"""
FinX Automation CLI (fx)
Automates 90% of repeated development tasks:
- Smart diagnostics (filter errors vs warnings)
- One-command build, deploy, and launch
- Flawless device screenshot capture
- Robust CRLF-safe code patching
- Fast search & file finding with ripgrep (rg), fd, bat, eza
- Living memory updating
"""

import argparse
import datetime
import os
import re
import shutil
import subprocess
import sys
import time

# Ensure UTF-8 output on Windows
if hasattr(sys.stdout, "reconfigure"):
    try:
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    except Exception:
        pass
if hasattr(sys.stderr, "reconfigure"):
    try:
        sys.stderr.reconfigure(encoding="utf-8", errors="replace")
    except Exception:
        pass

# Base directory for FinX project
PROJECT_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
APK_RELEASE_PATH = os.path.join(PROJECT_DIR, "build", "app", "outputs", "flutter-apk", "app-release.apk")
APK_DEBUG_PATH = os.path.join(PROJECT_DIR, "build", "app", "outputs", "flutter-apk", "app-debug.apk")
MEMORY_PATH = os.path.join(PROJECT_DIR, "memory.md")

# Default device to reconnect if needed
DEFAULT_DEVICE_IP = "100.76.114.166:5555"
PACKAGE_NAME = "app.expensio"
MAIN_ACTIVITY = "app.expensio/.MainActivity"

# Color helpers
class Colors:
    HEADER = "\033[95m"
    BLUE = "\033[94m"
    CYAN = "\033[96m"
    GREEN = "\033[92m"
    YELLOW = "\033[93m"
    RED = "\033[91m"
    RESET = "\033[0m"
    BOLD = "\033[1m"
    DIM = "\033[2m"

def log_info(msg):
    print(f"{Colors.BLUE}[fx]{Colors.RESET} {msg}")

def log_success(msg):
    print(f"{Colors.GREEN}[fx OK]{Colors.RESET} {msg}")

def log_warn(msg):
    print(f"{Colors.YELLOW}[fx !]{Colors.RESET} {msg}")

def log_error(msg):
    print(f"{Colors.RED}[fx X]{Colors.RESET} {msg}")

def run_proc(cmd, cwd=PROJECT_DIR, capture=False, check=True):
    """Run a subprocess command safely."""
    shell = isinstance(cmd, str)
    try:
        res = subprocess.run(
            cmd,
            cwd=cwd,
            shell=shell,
            capture_output=capture,
            text=True,
            check=check,
            encoding="utf-8",
            errors="replace"
        )
        return res
    except subprocess.CalledProcessError as e:
        if not capture:
            log_error(f"Command failed with code {e.returncode}: {cmd}")
        raise

# -------------------------------------------------------------
# 1. Smart Analyze
# -------------------------------------------------------------
def cmd_analyze(args):
    """Run flutter analyze and cleanly separate errors, warnings, and infos."""
    log_info("Running flutter analyze on FinX...")
    flutter_bin = shutil.which("flutter") or r"C:\flutter\bin\flutter.bat"
    
    t0 = time.time()
    res = subprocess.run(
        [flutter_bin, "analyze"],
        cwd=PROJECT_DIR,
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="replace"
    )
    elapsed = time.time() - t0

    lines = res.stdout.splitlines()
    errors = []
    warnings = []
    infos = []

    for line in lines:
        sline = line.strip()
        if "error - " in sline:
            errors.append(sline)
        elif "warning - " in sline:
            warnings.append(sline)
        elif "info - " in sline:
            infos.append(sline)

    print()
    print(f"{Colors.BOLD}=== FinX Diagnostics Summary ({elapsed:.1f}s) ==={Colors.RESET}")
    print(f"Errors:   {Colors.RED if errors else Colors.GREEN}{len(errors)}{Colors.RESET}")
    print(f"Warnings: {Colors.YELLOW if warnings else Colors.RESET}{len(warnings)}{Colors.RESET}")
    print(f"Infos:    {Colors.DIM}{len(infos)}{Colors.RESET}")
    print("=" * 45)

    if errors:
        print(f"\n{Colors.RED}{Colors.BOLD}ERRORS ({len(errors)}):{Colors.RESET}")
        for e in errors:
            print(f"  {Colors.RED}* {Colors.RESET}{e}")
        print()
        return 1

    if warnings and args.show_warnings:
        print(f"\n{Colors.YELLOW}{Colors.BOLD}WARNINGS ({len(warnings)}):{Colors.RESET}")
        for w in warnings[:args.limit]:
            print(f"  {Colors.YELLOW}* {Colors.RESET}{w}")
        if len(warnings) > args.limit:
            print(f"  ... and {len(warnings) - args.limit} more warnings.")

    if not errors:
        log_success("0 compile errors! Codebase is ready to build.")
        return 0

# -------------------------------------------------------------
# 2. Test Runner
# -------------------------------------------------------------
def cmd_test(args):
    """Run flutter test with optional pattern filter."""
    log_info("Running flutter test...")
    flutter_bin = shutil.which("flutter") or r"C:\flutter\bin\flutter.bat"
    cmd = [flutter_bin, "test"]
    if args.filter:
        cmd.extend(["--plain-name", args.filter])
    res = subprocess.run(cmd, cwd=PROJECT_DIR)
    return res.returncode

# -------------------------------------------------------------
# 3. ADB Device Discovery & Connect
# -------------------------------------------------------------
DEVICE_FILE = os.path.join(PROJECT_DIR, ".adb_device")

def get_persisted_ip():
    if os.path.exists(DEVICE_FILE):
        try:
            with open(DEVICE_FILE, "r", encoding="utf-8") as f:
                ip = f.read().strip()
                if ip:
                    return ip
        except Exception:
            pass
    return os.environ.get("ADB_DEVICE", DEFAULT_DEVICE_IP)

def persist_device_ip(ip):
    try:
        with open(DEVICE_FILE, "w", encoding="utf-8") as f:
            f.write(ip.strip())
    except Exception:
        pass

def get_active_device(custom_device=None):
    """Discover or reconnect the active ADB device."""
    adb_bin = shutil.which("adb") or "adb"
    
    # 1. Custom device specified
    if custom_device:
        persist_device_ip(custom_device)
        subprocess.run([adb_bin, "connect", custom_device], capture_output=True, text=True)

    # 2. Check attached devices
    res = subprocess.run([adb_bin, "devices"], capture_output=True, text=True)
    lines = res.stdout.splitlines()
    devices = []
    for line in lines[1:]:
        parts = line.strip().split()
        if len(parts) >= 2 and parts[1] == "device":
            devices.append(parts[0])

    if devices:
        return devices[0]

    # 3. Attempt reconnect to persisted IP
    target_ip = get_persisted_ip()
    log_warn(f"No active device found. Attempting to reconnect to {target_ip}...")
    subprocess.run([adb_bin, "connect", target_ip], capture_output=True, text=True)
    time.sleep(1)
    
    res = subprocess.run([adb_bin, "devices"], capture_output=True, text=True)
    for line in res.stdout.splitlines()[1:]:
        parts = line.strip().split()
        if len(parts) >= 2 and parts[1] == "device":
            log_success(f"Connected to {parts[0]}")
            persist_device_ip(parts[0])
            return parts[0]

    log_error("Could not locate or connect to any ADB device.")
    return None

def cmd_connect(args):
    """Explicitly connect to an ADB device IP and save it for future commands."""
    ip = args.device_ip
    persist_device_ip(ip)
    adb_bin = shutil.which("adb") or "adb"
    log_info(f"Connecting to {ip}...")
    res = subprocess.run([adb_bin, "connect", ip], capture_output=True, text=True)
    print(res.stdout.strip())
    device = get_active_device()
    if device:
        log_success(f"Active device is now {device}")
        return 0
    else:
        log_error(f"Failed to connect to {ip}")
        return 1

# -------------------------------------------------------------
# 4. Build APK
# -------------------------------------------------------------
def cmd_build(args):
    """Build APK with release/debug mode and target-platform android-arm64."""
    mode = "release" if args.release else "debug"
    log_info(f"Building {mode.upper()} APK (android-arm64)...")
    flutter_bin = shutil.which("flutter") or r"C:\flutter\bin\flutter.bat"

    cmd = [
        flutter_bin,
        "build",
        "apk",
        "--target-platform",
        "android-arm64",
        f"--{mode}",
    ]
    t0 = time.time()
    try:
        run_proc(cmd, cwd=PROJECT_DIR, check=True)
        elapsed = time.time() - t0
        apk_path = APK_RELEASE_PATH if args.release else APK_DEBUG_PATH
        if os.path.exists(apk_path):
            size_mb = os.path.getsize(apk_path) / (1024 * 1024)
            log_success(f"Built {os.path.basename(apk_path)} ({size_mb:.1f} MB) in {elapsed:.1f}s")
            return 0
        else:
            log_error(f"Expected APK not found at: {apk_path}")
            return 1
    except Exception as e:
        log_error(f"Build failed: {e}")
        return 1

# -------------------------------------------------------------
# 5. Deploy & Launch
# -------------------------------------------------------------
def cmd_deploy(args):
    """Deploy the APK to connected device and launch MainActivity."""
    apk_path = APK_RELEASE_PATH if args.release else APK_DEBUG_PATH
    if not os.path.exists(apk_path):
        log_error(f"APK not found at {apk_path}. Run 'fx build' first.")
        return 1

    device = get_active_device()
    if not device:
        return 1

    log_info(f"Installing {os.path.basename(apk_path)} on device {device}...")
    adb_bin = shutil.which("adb") or "adb"
    
    # Install with -r
    res = subprocess.run([adb_bin, "-s", device, "install", "-r", apk_path], capture_output=True, text=True)
    if "Success" in res.stdout:
        log_success("APK installed successfully.")
    else:
        log_error(f"Installation failed: {res.stdout}\n{res.stderr}")
        return 1

    # Launch MainActivity
    log_info(f"Launching {MAIN_ACTIVITY}...")
    subprocess.run([adb_bin, "-s", device, "shell", "am", "start", "-n", MAIN_ACTIVITY], capture_output=True, text=True)
    time.sleep(1)

    # Verify process
    ps_res = subprocess.run([adb_bin, "-s", device, "shell", "ps", "-A"], capture_output=True, text=True)
    if PACKAGE_NAME in ps_res.stdout:
        for line in ps_res.stdout.splitlines():
            if PACKAGE_NAME in line:
                log_success(f"Running: {line.strip()}")
                break
    else:
        log_warn("App launched, but process was not listed in ps. Check device screen.")

    return 0

# -------------------------------------------------------------
# 6. Full Run (Analyze -> Build -> Deploy)
# -------------------------------------------------------------
def cmd_run(args):
    """One command that executes Analyze -> Build -> Deploy -> Launch."""
    log_info(f"{Colors.BOLD}Starting automated FinX build & deploy cycle...{Colors.RESET}")
    
    # 1. Analyze
    if not args.skip_analyze:
        ret = cmd_analyze(args)
        if ret != 0:
            log_error("Analyze failed with errors. Aborting build.")
            return ret
    
    # 2. Build
    ret = cmd_build(args)
    if ret != 0:
        log_error("Build failed. Aborting deploy.")
        return ret

    # 3. Deploy
    return cmd_deploy(args)

# -------------------------------------------------------------
# 7. Screenshot (Flawless adb pull)
# -------------------------------------------------------------
def cmd_snap(args):
    """Capture clean screenshot directly from device without binary corruption."""
    device = get_active_device()
    if not device:
        return 1

    adb_bin = shutil.which("adb") or "adb"
    ts = datetime.datetime.now().strftime("%Y%m%d_%H%M%S")
    out_name = args.name or f"snap_{ts}.png"
    if not out_name.endswith(".png"):
        out_name += ".png"

    dest_dir = args.out_dir or os.path.join(PROJECT_DIR, "screenshots")
    os.makedirs(dest_dir, exist_ok=True)
    dest_path = os.path.join(dest_dir, out_name)

    log_info(f"Capturing screen from {device}...")
    subprocess.run([adb_bin, "-s", device, "shell", "screencap", "-p", "/sdcard/screen.png"], check=True)
    subprocess.run([adb_bin, "-s", device, "pull", "/sdcard/screen.png", dest_path], check=True, capture_output=True)

    if os.path.exists(dest_path):
        size_kb = os.path.getsize(dest_path) / 1024
        log_success(f"Saved screenshot: {dest_path} ({size_kb:.1f} KB)")
        return 0
    else:
        log_error("Failed to save screenshot.")
        return 1

# -------------------------------------------------------------
# 8. Safe File Patcher
# -------------------------------------------------------------
def cmd_patch(args):
    """Safe, CRLF/LF agnostic multi-line file patcher with automatic backup."""
    filepath = os.path.abspath(args.file)
    if not os.path.exists(filepath):
        log_error(f"File not found: {filepath}")
        return 1

    with open(filepath, "r", encoding="utf-8", errors="replace") as f:
        content = f.read()

    target = args.find
    replacement = args.replace

    # Check match with normalized newlines
    norm_content = content.replace("\r\n", "\n")
    norm_target = target.replace("\r\n", "\n")
    norm_replacement = replacement.replace("\r\n", "\n")

    if norm_target not in norm_content:
        log_error("Target string was not found in file.")
        return 1

    # Backup
    bak_path = filepath + ".bak"
    shutil.copyfile(filepath, bak_path)

    # Detect original newline style
    is_crlf = "\r\n" in content
    new_norm_content = norm_content.replace(norm_target, norm_replacement, 1 if not args.all else -1)
    
    if is_crlf:
        final_content = new_norm_content.replace("\n", "\r\n")
    else:
        final_content = new_norm_content

    with open(filepath, "w", encoding="utf-8") as f:
        f.write(final_content)

    log_success(f"Patched {filepath} (backup saved to {os.path.basename(bak_path)})")
    return 0

# -------------------------------------------------------------
# 9. Memory Updater
# -------------------------------------------------------------
def cmd_memory(args):
    """Safely append change log entry to memory.md."""
    if not os.path.exists(MEMORY_PATH):
        log_error(f"memory.md not found at {MEMORY_PATH}")
        return 1

    now = datetime.datetime.now().strftime("%Y-%m-%d %H:%M")
    entry = f"\n### Update: {args.title} ({now})\n"
    if args.bullets:
        for b in args.bullets:
            entry += f"- {b}\n"
    else:
        entry += f"- {args.title}\n"

    with open(MEMORY_PATH, "a", encoding="utf-8") as f:
        f.write(entry)

    log_success(f"Updated memory.md with: '{args.title}'")
    return 0

# -------------------------------------------------------------
# 10. Modern Search & Inspection Wrappers
# -------------------------------------------------------------
def cmd_find(args):
    """Invoke fd with project presets."""
    fd_bin = shutil.which("fd")
    if not fd_bin:
        log_error("fd is not installed. Run 'winget install sharkdp.fd'")
        return 1
    cmd = [fd_bin, "--exclude", ".dart_tool", "--exclude", "build", "--exclude", ".git", "--exclude", ".gradle", "--exclude", "graphify-out"]
    if args.query:
        cmd.append(args.query)
    cmd.append(PROJECT_DIR)
    return subprocess.run(cmd).returncode

def cmd_search(args):
    """Invoke ripgrep (rg) with project presets."""
    rg_bin = shutil.which("rg")
    if not rg_bin:
        log_error("rg (ripgrep) is not installed. Run 'winget install BurntSushi.ripgrep.MSVC'")
        return 1
    cmd = [rg_bin, "--glob", "!.dart_tool/**", "--glob", "!build/**", "--glob", "!.git/**", "--glob", "!android/.gradle/**", "--glob", "!graphify-out/**"]
    if args.ignore_case:
        cmd.append("-i")
    cmd.extend([args.pattern, PROJECT_DIR])
    return subprocess.run(cmd).returncode

def cmd_view(args):
    """Invoke bat for syntax highlighted file inspection."""
    bat_bin = shutil.which("bat")
    filepath = os.path.abspath(args.file)
    if not bat_bin:
        # Fallback to python print
        with open(filepath, "r", encoding="utf-8", errors="replace") as f:
            lines = f.readlines()
        start = max(0, (args.start or 1) - 1)
        end = min(len(lines), args.end or len(lines))
        for i in range(start, end):
            print(f"{i+1:4d}: {lines[i]}", end="")
        return 0
    cmd = [bat_bin, "--paging=never", filepath]
    if args.start and args.end:
        cmd.extend(["-r", f"{args.start}:{args.end}"])
    return subprocess.run(cmd).returncode

def cmd_tree(args):
    """Invoke eza for visual directory structure."""
    eza_bin = shutil.which("eza") or shutil.which("exa")
    target_dir = os.path.abspath(args.directory) if args.directory else PROJECT_DIR
    if not eza_bin:
        log_error("eza/exa is not installed.")
        return 1
    cmd = [eza_bin, "--tree", "--level", str(args.level), "--ignore-glob", ".dart_tool|build|.git|.gradle|node_modules", target_dir]
    return subprocess.run(cmd).returncode

# -------------------------------------------------------------
# Main CLI Dispatcher
# -------------------------------------------------------------
def main():
    parser = argparse.ArgumentParser(description="FinX Automation CLI (fx)")
    subparsers = parser.add_subparsers(dest="subcommand", required=True)

    # connect
    p_con = subparsers.add_parser("connect", help="Connect to wireless ADB device and save as default")
    p_con.add_argument("device_ip", help="Device IP:PORT, e.g. 100.76.114.166:5555")
    p_con.set_defaults(func=cmd_connect)

    # analyze
    p_ana = subparsers.add_parser("analyze", help="Smart flutter analyze with error filtering")
    p_ana.add_argument("--show-warnings", action="store_true", help="Display warnings as well")
    p_ana.add_argument("--limit", type=int, default=10, help="Max warnings to print")
    p_ana.set_defaults(func=cmd_analyze)

    # test
    p_tst = subparsers.add_parser("test", help="Run flutter test")
    p_tst.add_argument("filter", nargs="?", default=None, help="Plain name filter for tests")
    p_tst.set_defaults(func=cmd_test)

    # build
    p_bld = subparsers.add_parser("build", help="Build release or debug APK")
    p_bld.add_argument("--debug", dest="release", action="store_false", help="Build debug APK instead of release")
    p_bld.set_defaults(release=True, func=cmd_build)

    # deploy
    p_dep = subparsers.add_parser("deploy", help="Deploy APK to ADB device & launch MainActivity")
    p_dep.add_argument("--debug", dest="release", action="store_false", help="Deploy debug APK instead of release")
    p_dep.set_defaults(release=True, func=cmd_deploy)

    # run (analyze + build + deploy)
    p_run = subparsers.add_parser("run", help="Run full pipeline: analyze -> build -> deploy -> launch")
    p_run.add_argument("--skip-analyze", action="store_true", help="Skip analyze check")
    p_run.add_argument("--debug", dest="release", action="store_false", help="Build and deploy debug APK")
    p_run.add_argument("--show-warnings", action="store_true", help="Display analyze warnings")
    p_run.add_argument("--limit", type=int, default=10)
    p_run.set_defaults(release=True, func=cmd_run)

    # snap
    p_snp = subparsers.add_parser("snap", help="Capture device screenshot without binary corruption")
    p_snp.add_argument("name", nargs="?", default=None, help="Optional filename for screenshot")
    p_snp.add_argument("--out-dir", default=None, help="Output directory")
    p_snp.set_defaults(func=cmd_snap)

    # patch
    p_pat = subparsers.add_parser("patch", help="Safely replace target text in file")
    p_pat.add_argument("file", help="File to patch")
    p_pat.add_argument("--find", required=True, help="Target string to find")
    p_pat.add_argument("--replace", required=True, help="Replacement string")
    p_pat.add_argument("--all", action="store_true", help="Replace all occurrences")
    p_pat.set_defaults(func=cmd_patch)

    # memory
    p_mem = subparsers.add_parser("memory", help="Append structured entry to memory.md")
    p_mem.add_argument("title", help="Title of the update")
    p_mem.add_argument("-b", "--bullets", nargs="*", help="List of bullet points")
    p_mem.set_defaults(func=cmd_memory)

    # find (fd)
    p_fnd = subparsers.add_parser("find", help="Find files with fd (fast, smart excludes)")
    p_fnd.add_argument("query", nargs="?", default="", help="File pattern to search")
    p_fnd.set_defaults(func=cmd_find)

    # search (rg)
    p_src = subparsers.add_parser("search", help="Search content with ripgrep (rg)")
    p_src.add_argument("pattern", help="Regex pattern to search")
    p_src.add_argument("-i", "--ignore-case", action="store_true", help="Case-insensitive search")
    p_src.set_defaults(func=cmd_search)

    # view (bat)
    p_viw = subparsers.add_parser("view", help="View file with syntax highlighting (bat)")
    p_viw.add_argument("file", help="File path to view")
    p_viw.add_argument("-s", "--start", type=int, help="Start line number")
    p_viw.add_argument("-e", "--end", type=int, help="End line number")
    p_viw.set_defaults(func=cmd_view)

    # tree (eza)
    p_tre = subparsers.add_parser("tree", help="Visual directory tree (eza)")
    p_tre.add_argument("directory", nargs="?", default="", help="Directory to inspect")
    p_tre.add_argument("-l", "--level", type=int, default=2, help="Depth level (default: 2)")
    p_tre.set_defaults(func=cmd_tree)

    args = parser.parse_args()
    return args.func(args)

if __name__ == "__main__":
    sys.exit(main() or 0)
