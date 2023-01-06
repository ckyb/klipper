#!/bin/sh
# This script installs Klipper on a Raspberry Pi machine running a
# PostmarketOS (Alpine Linux) distribution.

set -o errexit
set -o nounset

PYTHONDIR="${HOME}/klippy-env"

# Find SRCDIR from the pathname of this script
SRCDIR="$(dirname "$(realpath "$0")")"

SUDO=$(which sudo)
DOAS=$(which doas)

_SUDO=
if [ "$(id -u)" != "0" ] ; then
	# we are not root
	if [ -n "${SUDO}" ] ; then
		_SUDO="${SUDO}"
	elif [ -n "${DOAS}" ] ; then
		_SUDO="${DOAS}"
	else
		echo "ERROR: Unable to find a suitable doas/sudo executable, and we are not root!" >&2
		exit 1
	fi
fi

# run a command with either DOAS or SUDO if needed
_sudo() {
	${_SUDO} "$@"
}

# Step 1: Install system packages
install_packages()
{
    # Packages for python cffi
	PKGLIST="py3-virtualenv python3-dev libffi-dev build-base gcc wget git"
    # kconfig requirements
    PKGLIST="${PKGLIST} ncurses-dev"
    # hub-ctrl
    PKGLIST="${PKGLIST} libusb-dev"
    # AVR chip installation and building
    PKGLIST="${PKGLIST} avrdude gcc-avr binutils-avr avr-libc"
    # ARM chip installation and building
    PKGLIST="${PKGLIST} stm32flash dfu-util newlib-arm-none-eabi"
    PKGLIST="${PKGLIST} gcc-arm-none-eabi binutils-arm-none-eabi libusb"

    # Update system package info
    report_status "Running apk update..."
    _sudo apk update

    # Install desired packages
    report_status "Installing packages..."
    _sudo apk add ${PKGLIST}
}

# Step 2: Create python virtual environment
create_virtualenv()
{
    report_status "Updating python virtual environment..."

    # Create virtualenv if it doesn't already exist
    [ ! -d ${PYTHONDIR} ] && virtualenv ${PYTHONDIR}

    # Install/update dependencies
    ${PYTHONDIR}/bin/pip install -r ${SRCDIR}/scripts/klippy-requirements.txt
}

# Step 3: Install startup script
install_script()
{
    report_status "Installing system start script..."
    _sudo cp "${SRCDIR}/scripts/klipper-start.sh" /etc/init.d/klipper
	_sudo chmod +x /etc/init.d/klipper
	_sudo rc-update add klipper
}

# Step 4: Install startup script config
install_config()
{
    DEFAULTS_FILE=/etc/default/klipper
    [ -f $DEFAULTS_FILE ] && return

    report_status "Installing system start configuration..."
    cat <<-EOF | _sudo tee "${DEFAULTS_FILE}"
	# Configuration for /etc/init.d/klipper

	KLIPPY_USER=${USER}

	KLIPPY_EXEC="${PYTHONDIR}/bin/python"

	KLIPPY_ARGS="${SRCDIR}/klippy/klippy.py ${HOME}/printer.cfg -l /tmp/klippy.log"

	EOF
}

# Step 5: Start host software
start_software()
{
    report_status "Launching Klipper host software..."
	_sudo rc-service klipper restart
}

# Helper functions
report_status()
{
	printf "\n\n###### %s\n" "$1"
}

# Run installation steps defined above
verify_ready
install_packages
create_virtualenv
install_script
install_config
start_software
