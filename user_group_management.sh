#!/bin/bash

# User and Group Management System
# Duration: March 2025 – April 2025
# Author: Tejas Aher
# Description: Automates user/group creation, ACL management, and backup with logging, colored output, and progress display.

# -------------------------------
# 🎨 Color Codes
# -------------------------------
RED="\e[31m"
GREEN="\e[32m"
YELLOW="\e[33m"
BLUE="\e[34m"
RESET="\e[0m"

# -------------------------------
# 📢 Color Functions
# -------------------------------
info() {
    echo -e "${BLUE}[INFO] $1${RESET}"
}

success() {
    echo -e "${GREEN}[SUCCESS] $1${RESET}"
}

error() {
    echo -e "${RED}[ERROR] $1${RESET}"
}

warning() {
    echo -e "${YELLOW}[WARNING] $1${RESET}"
}

# -------------------------------
# 🔄 Progress Bar Function
# -------------------------------
progress_bar() {
    local duration=${1:-5}
    local interval=0.1
    local max=$(bc -l <<< "$duration/$interval")
    echo -n "["
    for ((i=0; i<max; i++)); do
        echo -n "#"
        sleep $interval
    done
    echo "] Done!"
}

# -------------------------------
# 📄 Setup Variables
# -------------------------------
LOGFILE="/var/log/user_group_mgmt.log"
BACKUP_DIR="/backup"

# -------------------------------
# ⚡ Ensure script is run as root
# -------------------------------
if [[ $EUID -ne 0 ]]; then
    error "Run this script as root."
    exit 1
fi

# -------------------------------
# 📦 Check and install required packages
# -------------------------------
required_packages=("acl" "tar")
for pkg in "${required_packages[@]}"; do
    if ! rpm -q "$pkg" >/dev/null; then
        info "Installing missing package: $pkg"
        yum install -y "$pkg" >> "$LOGFILE" 2>&1
        success "Package $pkg installed."
    fi
done

# -------------------------------
# 📝 Log Actions
# -------------------------------
log_action() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') : $1" >> "$LOGFILE"
}

# -------------------------------
# 👤 Create User and Group
# -------------------------------
create_user() {
    read -p "Enter username: " username
    read -p "Enter primary group: " groupname

    if ! getent group "$groupname" >/dev/null; then
        groupadd "$groupname"
        success "Group $groupname created."
        log_action "Group $groupname created."
    fi

    if id "$username" &>/dev/null; then
        warning "User $username already exists!"
    else
        useradd -m -g "$groupname" "$username"
        success "User $username created and added to group $groupname."
        log_action "User $username created and added to $groupname."

        passwd "$username"
        chage -M 90 -m 7 -W 7 "$username"
        success "Password policy set for $username (Max: 90, Min: 7, Warn: 7)."
        log_action "Password policy applied for $username."
    fi
}

# -------------------------------
# 🔐 Set ACL Permissions
# -------------------------------
set_acl() {
    read -p "Enter directory (full path): " directory
    read -p "Enter username to set ACL for: " acl_user
    read -p "Enter permissions (e.g., rwx, r--, rw-): " permissions

    mkdir -p "$directory"
    setfacl -m u:"$acl_user":"$permissions" "$directory"
    success "ACL permission '$permissions' set for user '$acl_user' on '$directory'."
    log_action "ACL '$permissions' set for '$acl_user' on '$directory'."
}

# -------------------------------
# 💾 Backup /home Directory
# -------------------------------
backup_users() {
    mkdir -p "$BACKUP_DIR"
    BACKUP_FILE="$BACKUP_DIR/home_backup_$(date +%F).tar.gz"

    info "Creating backup. Please wait..."
    progress_bar 5
    tar -czf "$BACKUP_FILE" /home >> "$LOGFILE" 2>&1

    if [[ $? -eq 0 ]]; then
        success "Backup created at $BACKUP_FILE."
        log_action "Backup successful: $BACKUP_FILE."
    else
        error "Backup failed!"
        log_action "Backup failed!"
    fi
}

# -------------------------------
# 👀 Monitor Active Users
# -------------------------------
monitor_users() {
    info "Currently Logged-in Users:"
    who | tee -a "$LOGFILE"
}

# -------------------------------
# 📜 Main Menu
# -------------------------------
while true; do
    echo ""
    echo "----------------------------------------"
    echo -e "${YELLOW}  User & Group Management System Menu  ${RESET}"
    echo "----------------------------------------"
    echo "1. Create User and Group"
    echo "2. Set ACL Permissions"
    echo "3. Backup User Home Directories"
    echo "4. Monitor Logged-in Users"
    echo "5. Exit"
    echo "----------------------------------------"
    read -p "Enter your choice [1-5]: " choice

    case "$choice" in
        1) create_user ;;
        2) set_acl ;;
        3) backup_users ;;
        4) monitor_users ;;
        5) info "Exiting script. Goodbye!"
           exit 0 ;;
        *) warning "Invalid option! Please try again." ;;
    esac
done
