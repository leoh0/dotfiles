#!/bin/bash
set -e
set -o pipefail

# install.sh
#	This script installs my basic setup for a manjaro laptop

# Choose a user account to use for this installation
get_user() {
	if [ -z "${TARGET_USER-}" ]; then
		mapfile -t options < <(find /home/* -maxdepth 0 -printf "%f\\n" -type d)
		# if there is only one option just use that user
		if [ "${#options[@]}" -eq "1" ]; then
			readonly TARGET_USER="${options[0]}"
			echo "Using user account: ${TARGET_USER}"
			return
		fi

		# iterate through the user options and print them
		PS3='command -v user account should be used? '

		select opt in "${options[@]}"; do
			readonly TARGET_USER=$opt
			break
		done
	fi
}

check_is_sudo() {
	if [ "$EUID" -ne 0 ]; then
		echo "Please run as root."
		exit
	fi
}

base() {
	if [ "$(dmidecode -s system-product-name)" == "XPS 15 9570" ]; then
		if ! grep -q net.ifnames=0 /etc/default/grub; then
			#sed -i 's/quiet/systemd.mask=systemd-networkd-wait-online.service systemd.mask=mhwd-live.service acpi_rev_override=1 net.ifnames=0/g' /etc/default/grub
			sed -i 's/quiet/systemd.mask=mhwd-live.service acpi_rev_override=1 net.ifnames=0/g' /etc/default/grub
			update-grub
		fi
		if ! test -e "/etc/systemd/system/systemd-user-sessions.service"; then
			cat << EOF >> /etc/systemd/system/systemd-user-sessions.service
#  This file is part of systemd.
#
#  systemd is free software; you can redistribute it and/or modify it
#  under the terms of the GNU Lesser General Public License as published by
#  the Free Software Foundation; either version 2.1 of the License, or
#  (at your option) any later version.

[Unit]
Description=Permit User Sessions
Documentation=man:systemd-user-sessions.service(8)
After=remote-fs.target nss-user-lookup.target

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/usr/lib/systemd/systemd-user-sessions start
ExecStop=/usr/lib/systemd/systemd-user-sessions stop
EOF
		fi
		if ! test -e "/etc/modprobe.d/blacklist.conf"; then
			cat << EOF >> /etc/modprobe.d/blacklist.conf
blacklist nouveau
#blacklist rivafb
#blacklist nvidiafb
#blacklist rivatv
#blacklist nv
EOF
			cat << EOF >> /etc/modprobe.d/nvidia.conf
options nvidia NVreg_EnableMSI=0
EOF
			#echo 'w /sys/bus/pci/devices/0000:01:00.0/power/control - - - - auto' >> /etc/tmpfiles.d/nvidia_pm.conf
			pacman -S --noconfirm \
				linux419-nvidia-390xx \
				bumblebee

			systemctl enable bumblebeed.service
			#systemctl disable systemd-networkd-wait-online.service
			#systemctl mask systemd-networkd-wait-online.service

			echo 'going to reboot....'
			reboot
		fi
	fi

	pkill xautolock

	# upgrade
	pacman -Syyuu --noconfirm

	# if you install docker from AUR you need to reboot (NAT problem)
	pacman -S --noconfirm \
		yay

	install_scripts

	setup_sudo

	su "$TARGET_USER" -c "
		yay -S --noconfirm \
		bash-completion \
		bcc \
		bind-tools \
		fd \
		hexyl \
		imwheel \
		jq \
		neovim \
		net-tools \
		networkmanager-openconnect \
		openconnect \
		pass \
		ripgrep \
		strace \
		tig \
		tmux \
		ttf-nanum \
		ttf-nanumgothic_coding \
		uim \
		unzip \
		urxvt-resize-font-git \
		yq-bin \
	"

        # set ntp time
        timedatectl set-ntp true
}


# setup sudo for a user
# because fuck typing that shit all the time
# just have a decent password
# and lock your computer when you aren't using it
# if they have your password they can sudo anyways
# so its pointless
# i know what the fuck im doing ;)
setup_sudo() {
	# add user to systemd groups
	# then you wont need sudo to view logs and shit
	gpasswd -a "$TARGET_USER" systemd-journal
	gpasswd -a "$TARGET_USER" systemd-network

	# create docker group
	groupadd docker || true
	gpasswd -a "$TARGET_USER" docker

	# add user to bumblebee
	gpasswd -a "$TARGET_USER" bumblebee || true

	# add go path to secure path
	{ \
		echo -e "Defaults	secure_path=\"/usr/local/go/bin:/home/${TARGET_USER}/.go/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/share/bcc/tools\""; \
		echo -e 'Defaults	env_keep += "ftp_proxy http_proxy https_proxy no_proxy GOPATH EDITOR"'; \
		echo -e "${TARGET_USER} ALL=(ALL) NOPASSWD:ALL"; \
		echo -e "${TARGET_USER} ALL=NOPASSWD: /sbin/ifconfig, /sbin/ifup, /sbin/ifdown, /sbin/ifquery"; \
	} >> /etc/sudoers

	# setup downloads folder as tmpfs
	# that way things are removed on reboot
	# i like things clean but you may not want this
	#mkdir -p "/home/$TARGET_USER/Downloads"
	#echo -e "\\n# tmpfs for downloads\\ntmpfs\\t/home/${TARGET_USER}/Downloads\\ttmpfs\\tnodev,nosuid,size=2G\\t0\\t0" >> /etc/fstab
}

# install custom scripts/binaries
install_scripts() {
	# install speedtest
	curl -sSL https://raw.githubusercontent.com/sivel/speedtest-cli/master/speedtest.py  > /usr/local/bin/speedtest
	chmod +x /usr/local/bin/speedtest

	# install icdiff
	curl -sSL https://raw.githubusercontent.com/jeffkaufman/icdiff/master/icdiff > /usr/local/bin/icdiff
	curl -sSL https://raw.githubusercontent.com/jeffkaufman/icdiff/master/git-icdiff > /usr/local/bin/git-icdiff
	chmod +x /usr/local/bin/icdiff
	chmod +x /usr/local/bin/git-icdiff

	# install lolcat
	curl -sSL https://raw.githubusercontent.com/tehmaze/lolcat/master/lolcat > /usr/local/bin/lolcat
	chmod +x /usr/local/bin/lolcat


	local scripts=( have light )

	for script in "${scripts[@]}"; do
		curl -sSL "https://misc.j3ss.co/binaries/$script" > "/usr/local/bin/${script}"
		chmod +x "/usr/local/bin/${script}"
	done
}

get_dotfiles() {
	# create subshell
	(
	cd "$HOME"

	if [[ ! -d "${HOME}/dotfiles" ]]; then
		# install dotfiles from repo
		git clone git@github.com:leoh0/dotfiles.git "${HOME}/dotfiles"
	fi

	cd "${HOME}/dotfiles"

	# installs all the things
	make

	# enable dbus for the user session
	# systemctl --user enable dbus.socket

	#sudo systemctl enable "i3lock@${TARGET_USER}"
	#sudo systemctl enable suspend-sedation.service

	#sudo systemctl enable systemd-networkd systemd-resolved
	#sudo systemctl start systemd-networkd systemd-resolved

	cd "$HOME"
	mkdir -p ~/Pictures/Screenshots
	)

	install_docker
	install_golang
	install_python
	install_autoenv
	install_vim
}

install_vim() {
	# create subshell
	(
	cd "$HOME"

	# install .vim files
	sudo rm -rf "${HOME}/.vim"
	git clone --recursive git@github.com:leoh0/.vim.git "${HOME}/.vim"
	(
	cd "${HOME}/.vim"
	make install
	)
	)
}

install_docker() {
	yay -S --noconfirm \
		dive \
		docker \
		libnvidia-container-bin \
		libnvidia-container-tools-bin \
		nvidia-container-runtime-bin \
		nvidia-container-runtime-hook-bin \
		nvidia-docker \
		skopeo

	sudo systemctl enable docker
}

install_python() {
	curl https://pyenv.run | bash

	export PATH="/home/al/.pyenv/bin:$PATH"
	eval "$(pyenv init -)"
	eval "$(pyenv virtualenv-init -)"

	pyenv install 3.6.8
	pyenv virtualenv -p python3.6 3.6.8 py36
	pyenv activate py36

	pip3 install -U \
		pip \
		setuptools \
		wheel \
		neovim
}

# install/update golang from source
install_golang() {
	export GO_VERSION
	GO_VERSION=$(curl -sSL "https://golang.org/VERSION?m=text")
	export GO_SRC=/usr/local/go

	# shellcheck source=/dev/null
	source "$HOME/.path"

	# if we are passing the version
	if [[ ! -z "$1" ]]; then
		GO_VERSION=$1
	fi

	# purge old src
	if [[ -d "$GO_SRC" ]]; then
		sudo rm -rf "$GO_SRC"
		sudo rm -rf "$GOPATH"
	fi

	GO_VERSION=${GO_VERSION#go}

	# subshell
	(
	kernel=$(uname -s | tr '[:upper:]' '[:lower:]')
	curl -sSL "https://storage.googleapis.com/golang/go${GO_VERSION}.${kernel}-amd64.tar.gz" | sudo tar -v -C /usr/local -xz
	local user="$USER"
	# rebuild stdlib for faster builds
	sudo chown -R "${user}" /usr/local/go/pkg
	CGO_ENABLED=0 go install -a -installsuffix cgo std
	)

	# get commandline tools
	(
	set -x
	set +e
	go get golang.org/x/lint/golint
	go get golang.org/x/tools/cmd/cover
	go get golang.org/x/review/git-codereview
	go get golang.org/x/tools/cmd/goimports
	go get golang.org/x/tools/cmd/gorename
	go get golang.org/x/tools/cmd/guru

	go get github.com/genuinetools/amicontained
	go get github.com/genuinetools/apk-file
	go get github.com/genuinetools/audit
	go get github.com/genuinetools/bpfd
	go get github.com/genuinetools/bpfps
	go get github.com/genuinetools/certok
	go get github.com/genuinetools/netns
	go get github.com/genuinetools/pepper
	go get github.com/genuinetools/reg
	go get github.com/genuinetools/udict
	go get github.com/genuinetools/weather

	go get github.com/jessfraz/gmailfilters
	go get github.com/jessfraz/junk/sembump
	go get github.com/jessfraz/secping
	go get github.com/jessfraz/ship
	go get github.com/jessfraz/tdash

	go get github.com/axw/gocov/gocov
	go get honnef.co/go/tools/cmd/staticcheck

	# Tools for vimgo.
	go get github.com/jstemmer/gotags
	go get github.com/nsf/gocode
	go get github.com/rogpeppe/godef
	)

	# symlink weather binary for motd
	sudo ln -snf "${GOPATH}/bin/weather" /usr/local/bin/weather
}

install_autoenv() {
	git clone git://github.com/kennethreitz/autoenv.git "$HOME/.autoenv"
}

install_stuff() {
	echo "install stuff"
}

usage() {
	echo -e "install.sh\\n\\tThis script installs my basic setup for a debian laptop\\n"
	echo "Usage:"
	echo "  base                              - setup sources & install base pkgs"
	echo "  dotfiles                          - get dotfiles"
	echo "  vim                               - install vim specific dotfiles"
	echo "  golang                            - install golang and packages"
	echo "  scripts                           - install scripts"
	echo "  docker                            - install docker"
	echo "  python                            - install python"
	echo "  autoenv                           - install autoenv"
	echo "  stuff                             - install stuff"
}

main() {
	local cmd=$1

	if [[ -z "$cmd" ]]; then
		usage
		exit 1
	fi

	if [[ $cmd == "base" ]]; then
		check_is_sudo
		get_user

		base
	elif [[ $cmd == "dotfiles" ]]; then
		get_user
		get_dotfiles
	elif [[ $cmd == "vim" ]]; then
		install_vim
	elif [[ $cmd == "scripts" ]]; then
		install_scripts
	elif [[ $cmd == "docker" ]]; then
		install_docker
	elif [[ $cmd == "golang" ]]; then
		install_golang "$2"
	elif [[ $cmd == "python" ]]; then
		install_python
	elif [[ $cmd == "autoenv" ]]; then
		install_autoenv
	elif [[ $cmd == "stuff" ]]; then
		install_stuff
	else
		usage
	fi
}

main "$@"
