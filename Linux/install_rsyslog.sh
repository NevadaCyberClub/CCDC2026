#!/bin/bash

set -e

configure() {
    echo "Configuring rsyslog to point to syslog server at $syslog_host..."

    echo "*.* @$syslog_host" >> /etc/rsyslog.conf

    if which systemctl >/dev/null 2>&1; then
        systemctl restart rsyslog
        systemctl enable rsyslog
    elif which service >/dev/null 2>&1; then
        service rsyslog restart
        chkconfig rsyslog on
    else
        # print to stderr
        echo "Could not determine service manager to restart rsyslog. Please restart it manually." >&2
        return 1
    fi
}

##########################
# Check for root privileges
##########################
if [ "$EUID" -ne 0 ]; then
    echo "Please run this script as root (or with sudo)."
    exit 1
fi

syslog_host="$1"

if [ -z "$syslog_host" ]; then
    echo "Usage: $0 <syslog_server_ip>:<port>"
    exit 1
fi

if which rsyslogd >/dev/null 2>&1; then
    echo "rsyslog is already installed. Configuring it..."
    configure && echo "rsyslog configuration complete."
    exit 0
fi

##########################
# Distro detection and installation of rsyslog
##########################
if [ -f /etc/os-release ]; then
    . /etc/os-release
    distro=$ID
else
    echo "Cannot determine your Linux distribution (missing /etc/os-release)."
    exit 1
fi

echo "Detected Linux distribution: $PRETTY_NAME"

case "$distro" in
    ubuntu|debian|linuxmint)
        echo "Updating package lists..."
        apt update

        echo "Installing rsyslog..."
        apt install -y rsyslog
        ;;

    fedora)
        echo "Installing rsyslog..."
        dnf install -y rsyslog
        ;;

    centos|rhel)
        echo "Enabling EPEL repository (if not already enabled)..."
        if ! rpm -q epel-release >/dev/null 2>&1; then
            yum install -y epel-release
        fi

        echo "Installing rsyslog on CentOS/RHEL..."
        yum install -y rsyslog
        ;;

    opensuse*|sles)
        echo "Refreshing repositories on openSUSE/SLES..."
        zypper refresh

        echo "Installing rsyslog on openSUSE/SLES..."
        zypper install -y rsyslog
        ;;

    arch)
        echo "Installing rsyslog on Arch Linux from the AUR..."
        pacman -Sy --noconfirm git base-devel
        git clone https://aur.archlinux.org/rsyslog.git /tmp/rsyslog
        cd /tmp/rsyslog

        echo "Can not run makepkg as root. Please go to /tmp/rsyslog and run 'makepkg -si' as a non-root user."
        echo "Then re-run this script to configure rsyslog."
        exit 1
        ;;

    alpine)
        echo "Adding rsyslog repository..."
        cd /etc/apk/keys
        wget http://alpine.adiscon.com/rsyslog@lists.adiscon.com-5a55e598.rsa.pub
        echo 'http://alpine.adiscon.com/3.7/stable' >> /etc/apk/repositories
        apk update

        echo "Installing rsyslog on Alpine Linux..."
        apk add rsyslog
        ;;

    *)
        echo "Unsupported or unrecognized Linux distribution: $distro"
        exit 1
        ;;
esac

echo "rsyslog installation complete."

configure && echo "rsyslog configuration complete."

echo "--------------------------------"
