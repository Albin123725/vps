#!/bin/bash
set -euo pipefail

# =============================
# UBUNTU VM FILE - HYBRID EDITION
# CREDIT: quanvm0501 (BlackCatOfficial), BiraloGaming
# =============================

# =============================
# CONFIG
# =============================
VM_DIR="$(pwd)/vm"
IMG_URL="https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img"
IMG_FILE="$VM_DIR/ubuntu-image.img"
UBUNTU_PERSISTENT_DISK="$VM_DIR/persistent.qcow2"
SEED_FILE="$VM_DIR/seed.iso"
MEMORY=16G
CPUS=4
SSH_PORT=2222
DISK_SIZE=80G
IMG_SIZE=20G
HOSTNAME="ubuntu"
USERNAME="ubuntu"
PASSWORD="ubuntu"
SWAP_SIZE=4G

# Firebase Environment Detection (safe check)
IS_FIREBASE=0
if [ -n "${GOOGLE_CLOUD_PROJECT:-}" ] || 
   [ -n "${FIREBASE_ENVIRONMENT:-}" ] || 
   hostname 2>/dev/null | grep -q "codespaces\|gitpod\|firebase" ||
   [ -f "/.firebaseconfig" ] || 
   [ -d "/home/firebase" ] ||
   whoami | grep -q "firebase"; then
    IS_FIREBASE=1
fi

# SCREEN/TMUX for hybrid mode
USE_SCREEN=0
USE_TMUX=0
if command -v screen &>/dev/null; then
    USE_SCREEN=1
    SCREEN_NAME="qemu-freeroot-vm"
elif command -v tmux &>/dev/null; then
    USE_TMUX=1
    TMUX_SESSION="qemu-freeroot-vm"
fi

# ALBIN Banner Display
show_banner() {
    clear
    echo "╔══════════════════════════════════════════════════════════╗"
    echo "║                                                          ║"
    echo "║   █████╗ ██╗     ██████╗ ██╗███╗   ██╗                  ║"
    echo "║  ██╔══██╗██║     ██╔══██╗██║████╗  ██║                  ║"
    echo "║  ███████║██║     ██████╔╝██║██╔██╗ ██║                  ║"
    echo "║  ██╔══██║██║     ██╔══██╗██║██║╚██╗██║                  ║"
    echo "║  ██║  ██║███████╗██████╔╝██║██║ ╚████║                  ║"
    echo "║  ╚═╝  ╚═╝╚══════╝╚═════╝ ╚═╝╚═╝  ╚═══╝                  ║"
    echo "║                                                          ║"
    echo "║         QEMU-freeroot HYBRID Mode - SEE & 24/7           ║"
    echo "║                 Console + Background                     ║"
    echo "║                                                          ║"
    echo "╚══════════════════════════════════════════════════════════╝"
    echo ""
}

# Firebase-compatible service management
firebase_service() {
    PID_FILE="$HOME/.qemu-freeroot.pid"
    LOG_FILE="$HOME/.qemu-freeroot.log"
    
    case "$1" in
        start)
            if [ -f "$PID_FILE" ]; then
                pid=$(cat "$PID_FILE")
                if kill -0 "$pid" 2>/dev/null; then
                    echo "[INFO] VM is already running (PID: $pid)"
                    return 0
                fi
            fi
            
            echo "[INFO] Starting VM in 24/7 Firebase background mode..."
            nohup bash "$0" --background > "$LOG_FILE" 2>&1 &
            echo $! > "$PID_FILE"
            echo "[SUCCESS] VM started in 24/7 mode (PID: $!)"
            echo "[INFO] SSH: ssh $USERNAME@localhost -p $SSH_PORT"
            echo "[INFO] Logs: tail -f $LOG_FILE"
            ;;
        stop)
            if [ -f "$PID_FILE" ]; then
                pid=$(cat "$PID_FILE")
                kill "$pid" 2>/dev/null || true
                rm -f "$PID_FILE"
                echo "[INFO] Stopped background VM (PID: $pid)"
            fi
            pkill -f "qemu-system-x86_64" 2>/dev/null || true
            echo "[SUCCESS] All VM instances stopped"
            ;;
        status)
            if [ -f "$PID_FILE" ]; then
                pid=$(cat "$PID_FILE")
                if kill -0 "$pid" 2>/dev/null; then
                    echo "[INFO] ✅ VM is running in 24/7 mode (PID: $pid)"
                    echo "[INFO]   SSH Port: $SSH_PORT"
                    echo "[INFO]   Username: $USERNAME"
                    echo "[INFO]   Password: $PASSWORD"
                    echo "[INFO]   Log file: $LOG_FILE"
                    return 0
                else
                    echo "[INFO] ❌ VM is not running (stale PID file)"
                    rm -f "$PID_FILE"
                fi
            else
                if pgrep -f "qemu-system-x86_64" > /dev/null; then
                    echo "[INFO] ⚠️  VM is running but not managed by 24/7 service"
                else
                    echo "[INFO] ❌ VM is not running"
                fi
            fi
            ;;
        logs)
            if [ -f "$LOG_FILE" ]; then
                tail -f "$LOG_FILE"
            else
                echo "[INFO] No log file found"
            fi
            ;;
        *)
            echo "Usage: $0 --service [start|stop|status|logs]"
            ;;
    esac
}

# New HYBRID mode functions
hybrid_service() {
    case "$1" in
        start)
            if [ $USE_SCREEN -eq 1 ]; then
                if screen -list | grep -q "$SCREEN_NAME"; then
                    echo "[INFO] VM already running in screen session"
                    echo "Attach with: screen -r $SCREEN_NAME"
                    return 0
                fi
                echo "[INFO] Starting VM in screen (Hybrid mode)..."
                screen -dmS "$SCREEN_NAME" bash "$0" --hybrid-console
                echo "[SUCCESS] VM started in screen session: $SCREEN_NAME"
                echo "Attach console: screen -r $SCREEN_NAME"
                echo "Detach: Ctrl+A then D (VM continues running)"
                echo "SSH also available: ssh $USERNAME@localhost -p $SSH_PORT"
                
            elif [ $USE_TMUX -eq 1 ]; then
                if tmux has-session -t "$TMUX_SESSION" 2>/dev/null; then
                    echo "[INFO] VM already running in tmux session"
                    echo "Attach with: tmux attach -t $TMUX_SESSION"
                    return 0
                fi
                echo "[INFO] Starting VM in tmux (Hybrid mode)..."
                tmux new-session -d -s "$TMUX_SESSION" "bash '$0' --hybrid-console"
                echo "[SUCCESS] VM started in tmux session: $TMUX_SESSION"
                echo "Attach console: tmux attach -t $TMUX_SESSION"
                echo "Detach: Ctrl+B then D (VM continues running)"
                echo "SSH also available: ssh $USERNAME@localhost -p $SSH_PORT"
                
            else
                echo "[WARNING] Neither screen nor tmux available."
                echo "Falling back to regular background mode..."
                firebase_service start
            fi
            ;;
        stop)
            if [ $USE_SCREEN -eq 1 ]; then
                screen -S "$SCREEN_NAME" -X quit 2>/dev/null
                echo "[INFO] Stopped screen session: $SCREEN_NAME"
            elif [ $USE_TMUX -eq 1 ]; then
                tmux kill-session -t "$TMUX_SESSION" 2>/dev/null
                echo "[INFO] Stopped tmux session: $TMUX_SESSION"
            fi
            pkill -f "qemu-system-x86_64" 2>/dev/null || true
            rm -f ~/.qemu-freeroot.pid 2>/dev/null || true
            echo "[SUCCESS] All VM instances stopped"
            ;;
        attach)
            if [ $USE_SCREEN -eq 1 ]; then
                if screen -list | grep -q "$SCREEN_NAME"; then
                    echo "[INFO] Attaching to screen session..."
                    screen -r "$SCREEN_NAME"
                else
                    echo "[ERROR] No screen session found"
                fi
            elif [ $USE_TMUX -eq 1 ]; then
                if tmux has-session -t "$TMUX_SESSION" 2>/dev/null; then
                    echo "[INFO] Attaching to tmux session..."
                    tmux attach -t "$TMUX_SESSION"
                else
                    echo "[ERROR] No tmux session found"
                fi
            else
                echo "[ERROR] Neither screen nor tmux available"
            fi
            ;;
        status)
            if [ $USE_SCREEN -eq 1 ]; then
                if screen -list | grep -q "$SCREEN_NAME"; then
                    echo "[INFO] ✅ VM running in screen session: $SCREEN_NAME"
                    echo "       Attach: screen -r $SCREEN_NAME"
                    echo "       Detach: Ctrl+A then D"
                    echo "       SSH: ssh $USERNAME@localhost -p $SSH_PORT"
                else
                    echo "[INFO] ❌ VM not running in screen"
                fi
            elif [ $USE_TMUX -eq 1 ]; then
                if tmux has-session -t "$TMUX_SESSION" 2>/dev/null; then
                    echo "[INFO] ✅ VM running in tmux session: $TMUX_SESSION"
                    echo "       Attach: tmux attach -t $TMUX_SESSION"
                    echo "       Detach: Ctrl+B then D"
                    echo "       SSH: ssh $USERNAME@localhost -p $SSH_PORT"
                else
                    echo "[INFO] ❌ VM not running in tmux"
                fi
            else
                firebase_service status
            fi
            
            # Check SSH port
            if timeout 2 bash -c "cat < /dev/null > /dev/tcp/localhost/$SSH_PORT" 2>/dev/null; then
                echo "[INFO] ✅ SSH port $SSH_PORT is open and responding"
            else
                echo "[INFO] ⚠️  SSH port $SSH_PORT not responding (VM may still be booting)"
            fi
            ;;
        *)
            echo "Usage: $0 --hybrid [start|stop|attach|status]"
            ;;
    esac
}

# Interactive Menu (UPDATED)
show_menu() {
    while true; do
        show_banner
        
        echo "════════════════════ Current Configuration ════════════════════"
        echo "┌─────────────────────────────────────────────────────────────┐"
        echo "│  Hostname: $HOSTNAME"
        echo "│  Username: $USERNAME"
        echo "│  Password: $PASSWORD"
        echo "│  Memory: $MEMORY"
        echo "│  CPU Cores: $CPUS"
        echo "│  Disk Size: $DISK_SIZE"
        echo "│  SSH Port: $SSH_PORT"
        echo "│  Swap Size: $SWAP_SIZE"
        echo "│  Environment: $(if [ $IS_FIREBASE -eq 1 ]; then echo 'Firebase'; else echo 'Local'; fi)"
        echo "└─────────────────────────────────────────────────────────────┘"
        echo ""
        echo "═══════════════════════ NEW HYBRID MENU ═══════════════════════"
        echo "1) 🎮 Start VM (Interactive ONLY - Stops when you close)"
        echo "2) 🌙 Start VM (Background ONLY - 24/7 but no console)"
        echo "3) 🚀 HYBRID MODE (Console + 24/7 Background) ★ NEW!"
        echo "4) 📺 Attach to Hybrid Console"
        echo "5) ⚙️  Configure Settings"
        echo "6) 📊 Check Hybrid Status"
        echo "7) ⏹️  Stop Hybrid VM"
        echo "8) 🔄 Restart Hybrid VM"
        echo "9) 🚪 Exit"
        echo ""
        
        read -p "Select option (1-9): " choice
        
        case $choice in
            1)
                echo "[INFO] Starting in interactive mode..."
                INTERACTIVE_MODE=1
                break
                ;;
            2)
                echo "[INFO] Starting Background 24/7 service..."
                firebase_service start
                read -p "Press any key to continue..."
                ;;
            3)
                echo "[INFO] Starting HYBRID mode (Console + 24/7)..."
                hybrid_service start
                read -p "Press any key to continue..."
                ;;
            4)
                echo "[INFO] Attaching to Hybrid console..."
                hybrid_service attach
                ;;
            5)
                customize_settings
                ;;
            6)
                hybrid_service status
                read -p "Press any key to continue..."
                ;;
            7)
                hybrid_service stop
                read -p "Press any key to continue..."
                ;;
            8)
                echo "[INFO] Restarting Hybrid VM..."
                hybrid_service stop
                sleep 2
                hybrid_service start
                read -p "Press any key to continue..."
                ;;
            9)
                echo "[INFO] Exiting..."
                exit 0
                ;;
            *)
                echo "[ERROR] Invalid option!"
                sleep 1
                ;;
        esac
    done
}

# Quick Presets
quick_presets() {
    show_banner
    echo "════════════════════ Quick Presets ════════════════════"
    echo "1) 🎮 Gaming VM (8GB RAM, 4 CPU, 100GB Disk)"
    echo "2) 🖥️  Dev VM (4GB RAM, 2 CPU, 50GB Disk)"
    echo "3) 🐳 Docker VM (16GB RAM, 8 CPU, 200GB Disk)"
    echo "4) 🚀 High Performance (32GB RAM, 16 CPU, 500GB Disk)"
    echo "5) 🔙 Back to Main Menu"
    echo ""
    
    read -p "Select preset (1-5): " preset
    
    case $preset in
        1)
            MEMORY="8G"
            CPUS="4"
            DISK_SIZE="100G"
            echo "[SUCCESS] Gaming preset applied!"
            ;;
        2)
            MEMORY="4G"
            CPUS="2"
            DISK_SIZE="50G"
            echo "[SUCCESS] Dev preset applied!"
            ;;
        3)
            MEMORY="16G"
            CPUS="8"
            DISK_SIZE="200G"
            echo "[SUCCESS] Docker preset applied!"
            ;;
        4)
            MEMORY="32G"
            CPUS="16"
            DISK_SIZE="500G"
            echo "[SUCCESS] High Performance preset applied!"
            ;;
        5)
            return
            ;;
        *)
            echo "[ERROR] Invalid preset!"
            ;;
    esac
    
    save_config
    sleep 1
}

# Customize Settings
customize_settings() {
    show_banner
    echo "════════════════════ Customize Settings ════════════════════"
    
    echo "1) Change Hostname [Current: $HOSTNAME]"
    echo "2) Change Username [Current: $USERNAME]"
    echo "3) Change Password [Current: $PASSWORD]"
    echo "4) Change Memory [Current: $MEMORY]"
    echo "5) Change CPU Cores [Current: $CPUS]"
    echo "6) Change Disk Size [Current: $DISK_SIZE]"
    echo "7) Change SSH Port [Current: $SSH_PORT]"
    echo "8) Change Swap Size [Current: $SWAP_SIZE]"
    echo "9) Save & Return to Main Menu"
    echo ""
    
    read -p "Select option (1-9): " choice
    
    case $choice in
        1) read -p "New Hostname: " HOSTNAME ;;
        2) read -p "New Username: " USERNAME ;;
        3) read -p "New Password: " PASSWORD ;;
        4) read -p "New Memory (e.g., 8G, 16G): " MEMORY ;;
        5) read -p "New CPU Cores: " CPUS ;;
        6) read -p "New Disk Size (e.g., 40G, 80G): " DISK_SIZE ;;
        7) read -p "New SSH Port: " SSH_PORT ;;
        8) read -p "New Swap Size (0G to disable): " SWAP_SIZE ;;
        9)
            echo "[INFO] Settings saved!"
            save_config
            return
            ;;
        *)
            echo "[ERROR] Invalid option!"
            sleep 1
            return
            ;;
    esac
    
    save_config
    echo "[SUCCESS] Configuration saved!"
    sleep 1
}

# Save configuration
save_config() {
    mkdir -p "$VM_DIR"
    cat > "$VM_DIR/vm.config" <<EOF
HOSTNAME="$HOSTNAME"
USERNAME="$USERNAME"
PASSWORD="$PASSWORD"
MEMORY="$MEMORY"
CPUS="$CPUS"
DISK_SIZE="$DISK_SIZE"
SSH_PORT="$SSH_PORT"
SWAP_SIZE="$SWAP_SIZE"
EOF
}

# Load saved config
load_config() {
    if [ -f "$VM_DIR/vm.config" ]; then
        # Use safe source to avoid issues
        if [ -r "$VM_DIR/vm.config" ]; then
            while IFS='=' read -r key value; do
                # Skip comments and empty lines
                [[ $key =~ ^[[:space:]]*# ]] && continue
                [[ -z $key ]] && continue
                
                # Remove quotes from value
                value="${value%\"}"
                value="${value#\"}"
                
                # Export variable
                export "$key"="$value"
            done < "$VM_DIR/vm.config"
            echo "[INFO] Loaded saved configuration from $VM_DIR/vm.config"
        fi
    fi
}

# Parse command line arguments
parse_args() {
    case "${1:-}" in
        --menu|-m)
            show_menu
            ;;
        --background|-b)
            BACKGROUND_MODE=1
            ;;
        --hybrid|-y)
            if [ -n "${2:-}" ]; then
                hybrid_service "$2"
                exit 0
            else
                echo "Usage: $0 --hybrid [start|stop|attach|status]"
                exit 1
            fi
            ;;
        --hybrid-console)
            HYBRID_CONSOLE=1
            ;;
        --service|-s)
            if [ -n "${2:-}" ]; then
                firebase_service "$2"
                exit 0
            else
                echo "Usage: $0 --service [start|stop|status|logs]"
                exit 1
            fi
            ;;
        --stop)
            hybrid_service stop
            exit 0
            ;;
        --status)
            hybrid_service status
            exit 0
            ;;
        --attach)
            hybrid_service attach
            exit 0
            ;;
        --logs)
            firebase_service logs
            exit 0
            ;;
        --help|-h)
            show_help
            exit 0
            ;;
        "")
            # No arguments, continue normally
            ;;
        *)
            echo "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
}

# Show help
show_help() {
    echo "╔══════════════════════════════════════════════════════════╗"
    echo "║                 QEMU-freeroot VM Manager                ║"
    echo "║                  HYBRID Console + 24/7                  ║"
    echo "╚══════════════════════════════════════════════════════════╝"
    echo ""
    echo "Usage: $0 [OPTION]"
    echo ""
    echo "🌟 NEW HYBRID MODE (Console + 24/7):"
    echo "  --hybrid, -y     Start/Manage Hybrid session"
    echo "                   [start|stop|attach|status]"
    echo ""
    echo "Traditional modes:"
    echo "  --menu, -m       Interactive menu"
    echo "  --background, -b Background 24/7 mode (no console)"
    echo "  --service, -s    Firebase service [start|stop|status|logs]"
    echo ""
    echo "Hybrid Features:"
    echo "  • See console output LIVE"
    echo "  • Detach (Ctrl+A D or Ctrl+B D)"
    echo "  • VM continues 24/7 in background"
    echo "  • Reattach anytime"
    echo "  • SSH also available"
    echo ""
    echo "Examples:"
    echo "  $0 --hybrid start    # Start Hybrid (Console + 24/7)"
    echo "  $0 --hybrid attach   # Reattach to console"
    echo "  $0 --hybrid status   # Check if running"
    echo "  $0 --menu            # Interactive menu"
}

# =============================
# MAIN EXECUTION
# =============================

# Load saved configuration
load_config

# Parse command line arguments
if [ $# -gt 0 ]; then
    parse_args "$@"
elif [ -t 0 ] && [ -t 1 ]; then
    # If running in terminal with no args, show menu
    show_menu
fi

# Create VM directory if it doesn't exist
mkdir -p "$VM_DIR"
cd "$VM_DIR"

# =============================
# TOOL CHECK
# =============================
for cmd in qemu-system-x86_64 qemu-img cloud-localds; do
    if ! command -v $cmd &>/dev/null; then
        echo "[ERROR] Required command '$cmd' not found. Install it first."
        exit 1
    fi
done

# =============================
# HYBRID CONSOLE HEADER (NEW!)
# =============================
if [ -n "${HYBRID_CONSOLE:-}" ]; then
    clear
    echo "╔══════════════════════════════════════════════════════════╗"
    echo "║                    HYBRID MODE ACTIVE                    ║"
    echo "║          VM Console + 24/7 Background Operation          ║"
    echo "╚══════════════════════════════════════════════════════════╝"
    echo ""
    echo "📺 You are viewing the LIVE VM console"
    if [ $USE_SCREEN -eq 1 ]; then
        echo "🔌 Detach with: Ctrl+A then D"
        echo "🔄 Reattach with: screen -r $SCREEN_NAME"
    elif [ $USE_TMUX -eq 1 ]; then
        echo "🔌 Detach with: Ctrl+B then D"
        echo "🔄 Reattach with: tmux attach -t $TMUX_SESSION"
    fi
    echo "🌐 SSH also available: ssh $USERNAME@localhost -p $SSH_PORT"
    echo "🔧 Password: $PASSWORD"
    echo "═══════════════════════════════════════════════════════════════════"
    echo ""
    echo "[INFO] Booting VM... (First boot takes 2-3 minutes)"
    echo ""
fi

# =============================
# VM IMAGE SETUP
# =============================
if [ ! -f "$IMG_FILE" ]; then
    echo "[INFO] Downloading Ubuntu Base/Cloud Image..."
    wget "$IMG_URL" -O "$IMG_FILE"
    qemu-img resize "$IMG_FILE" "$DISK_SIZE"

    # Cloud-init setup for OpenSSH and Swap
    cat > user-data <<EOF
#cloud-config
hostname: $HOSTNAME
manage_etc_hosts: true
disable_root: false
ssh_pwauth: true
chpasswd:
  list: |
    $USERNAME:$PASSWORD
  expire: false
packages:
  - openssh-server
runcmd:
  - echo "$USERNAME:$PASSWORD" | chpasswd
  - mkdir -p /var/run/sshd
  - systemctl start ssh
  - systemctl enable ssh
  # Swap file creation and activation
  - fallocate -l $SWAP_SIZE /swapfile
  - chmod 600 /swapfile
  - mkswap /swapfile
  - swapon /swapfile
  - echo '/swapfile none swap sw 0 0' | tee -a /etc/fstab
    
growpart:
  mode: auto
  devices: ["/"]
  ignore_growroot_disabled: false
resize_rootfs: true
EOF

    cat > meta-data <<EOF
instance-id: iid-local01
local-hostname: $HOSTNAME
EOF

    cloud-localds "$SEED_FILE" user-data meta-data
    echo "[INFO] VM image setup complete with OpenSSH and Swap!"
else
    echo "[INFO] VM image exists, skipping download..."
fi

# =============================
# PERSISTENT DISK SETUP
# =============================
if [ ! -f "$UBUNTU_PERSISTENT_DISK" ]; then
    echo "[INFO] Creating persistent disk..."
    qemu-img create -f qcow2 "$UBUNTU_PERSISTENT_DISK" "$IMG_SIZE"
fi

# =============================
# GRACEFUL SHUTDOWN TRAP
# =============================
cleanup() {
    echo ""
    echo "[INFO] Shutting down VM gracefully..."
    pkill -f "qemu-system-x86_64" || true
}
trap cleanup SIGINT SIGTERM

# =============================
# START VM
# =============================
# Check if KVM is available
clear
if [ -e /dev/kvm ]; then
    ACCELERATION_FLAG="-enable-kvm -cpu host"
    echo "[INFO] KVM is available. Using hardware acceleration."
else
    ACCELERATION_FLAG="-accel tcg"
    echo "[INFO] KVM is not available. Falling back to TCG software emulation."
fi

# Show banner for interactive mode
if [ -z "${BACKGROUND_MODE:-}" ] && [ -z "${INTERACTIVE_MODE:-}" ] && [ -z "${HYBRID_CONSOLE:-}" ]; then
    show_banner
    echo "CREDIT: quanvm0501 (BlackCatOfficial), BiraloGaming"
    echo "[INFO] Starting VM..."
    echo "════════════════════ VM Details ════════════════════"
    echo "Hostname: $HOSTNAME"
    echo "Username: $USERNAME"
    echo "Password: $PASSWORD"
    echo "Memory: $MEMORY"
    echo "CPU Cores: $CPUS"
    echo "Disk Size: $DISK_SIZE"
    echo "SSH Port: $SSH_PORT"
    echo "Swap Size: $SWAP_SIZE"
    echo "═══════════════════════════════════════════════════"
    echo ""
    echo "[TIP] Use './vm.sh --menu' for interactive menu"
    echo "[TIP] Use './vm.sh --hybrid start' for Console+24/7 mode"
    echo ""
    read -n1 -r -p "Press any key to start VM..."
fi

# Build QEMU command
QEMU_CMD="qemu-system-x86_64 \
    $ACCELERATION_FLAG \
    -m \"$MEMORY\" \
    -smp \"$CPUS\" \
    -drive file=\"$IMG_FILE\",format=qcow2,if=virtio,cache=writeback \
    -drive file=\"$UBUNTU_PERSISTENT_DISK\",format=qcow2,if=virtio,cache=writeback \
    -drive file=\"$SEED_FILE\",format=raw,if=virtio \
    -boot order=c \
    -device virtio-net-pci,netdev=n0 \
    -netdev user,id=n0,hostfwd=tcp::\"$SSH_PORT\"-:22 \
    -nographic -serial mon:stdio"

# Add daemonize flag for background mode
if [ -n "${BACKGROUND_MODE:-}" ]; then
    QEMU_CMD="$QEMU_CMD -daemonize"
    echo "[INFO] Starting VM in 24/7 Firebase background mode..."
    echo "[INFO] VM will continue running even when you close browser"
    echo "[INFO] SSH: ssh $USERNAME@localhost -p $SSH_PORT"
    echo "[INFO] Use './vm.sh --status' to check if it's running"
    echo "[INFO] Use './vm.sh --stop' to stop it"
    eval $QEMU_CMD
    echo "[SUCCESS] VM is now running in 24/7 background mode!"
    exit 0
elif [ -n "${HYBRID_CONSOLE:-}" ]; then
    # Hybrid mode - runs in screen/tmux, shows console
    echo "[INFO] Starting VM in HYBRID mode..."
    echo "[INFO] Detach with: $(if [ $USE_SCREEN -eq 1 ]; then echo 'Ctrl+A then D'; else echo 'Ctrl+B then D'; fi)"
    echo "[INFO] Reattach with: ./vm.sh --hybrid attach"
    echo "[INFO] SSH also available: ssh $USERNAME@localhost -p $SSH_PORT"
    echo "[INFO] First boot takes 2-3 minutes..."
    echo "═══════════════════════════════════════════════════════════════════"
    echo ""
    exec qemu-system-x86_64 \
        $ACCELERATION_FLAG \
        -m "$MEMORY" \
        -smp "$CPUS" \
        -drive file="$IMG_FILE",format=qcow2,if=virtio,cache=writeback \
        -drive file="$UBUNTU_PERSISTENT_DISK",format=qcow2,if=virtio,cache=writeback \
        -drive file="$SEED_FILE",format=raw,if=virtio \
        -boot order=c \
        -device virtio-net-pci,netdev=n0 \
        -netdev user,id=n0,hostfwd=tcp::"$SSH_PORT"-:22 \
        -nographic -serial mon:stdio
else
    # Interactive mode
    echo "[INFO] Starting VM in interactive mode..."
    echo "[INFO] Note: VM will STOP when you close this terminal"
    echo "[INFO] For 24/7 operation, use: ./vm.sh --hybrid start"
    echo ""
    exec qemu-system-x86_64 \
        $ACCELERATION_FLAG \
        -m "$MEMORY" \
        -smp "$CPUS" \
        -drive file="$IMG_FILE",format=qcow2,if=virtio,cache=writeback \
        -drive file="$UBUNTU_PERSISTENT_DISK",format=qcow2,if=virtio,cache=writeback \
        -drive file="$SEED_FILE",format=raw,if=virtio \
        -boot order=c \
        -device virtio-net-pci,netdev=n0 \
        -netdev user,id=n0,hostfwd=tcp::"$SSH_PORT"-:22 \
        -nographic -serial mon:stdio
fi
