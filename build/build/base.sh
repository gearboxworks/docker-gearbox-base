#!/bin/bash

test -f /etc/gearbox/bin/colors.sh && . /etc/gearbox/bin/colors.sh

c_ok "Started."

case "${GEARBOX_BASE_VERSION}" in
	"alpine-"*)
		case "${GEARBOX_BASE_VERSION}" in
			"alpine-3.3"|"alpine-3.4"|"alpine-3.5")
				# APKS="tini bash openrc nfs-utils sshfs openssh-client openssh git rsync sudo ncurses"
				APKS="s6 s6-rc s6-portable-utils s6-linux-utils bash nfs-utils sshfs openssh-client openssh git rsync sudo ncurses"
				;;

			"alpine-3.6"|"alpine-3.7"|"alpine-3.8"|"alpine-3.9"|"alpine-3.10"|"alpine-3.11")
				# APKS="tini bash openrc nfs-utils sshfs openssh-client openssh-server openssh git shadow rsync sudo ncurses"
				APKS="s6 s6-rc s6-portable-utils s6-linux-utils bash nfs-utils sshfs openssh-client openssh-server openssh git shadow rsync sudo ncurses"
				;;

			*)
				# APKS="tini bash openrc nfs-utils ssh-tools sshfs openssh-client openssh-server openssh git shadow rsync sudo ncurses"
				APKS="s6 s6-rc s6-portable-utils s6-linux-utils bash nfs-utils ssh-tools sshfs openssh-client openssh-server openssh git shadow rsync sudo ncurses"
				;;
		esac

		c_info "Update packages."
		apk update; checkExit
		apk add --no-cache ${APKS}; checkExit
		;;

	"debian-"*)
		case "${GEARBOX_BASE_VERSION}" in
			"debian-stretch")
				c_info "Update packages."
				DEBS="bash git rsync sudo wget nfs-common ssh fuse sshfs"
				echo 'debconf debconf/frontend select Noninteractive' | debconf-set-selections
				apt-get update; checkExit
				apt-get install -y --no-install-recommends ${DEBS}; checkExit

				apt-get install -y apt-utils locales; checkExit
				# apt-get install -y curl tzdata; checkExit
				# locale-gen en_US.UTF-8; checkExit
				# curl -SLO "https://github.com/just-containers/s6-overlay/releases/download/v1.20.0.0/s6-overlay-${ARCH}.tar.gz"; checkExit
				cd /
				wget -nv --no-check-certificate "https://github.com/just-containers/s6-overlay/releases/download/v1.20.0.0/s6-overlay-amd64.tar.gz"; checkExit
				tar -xzf /s6-overlay-amd64.tar.gz -C /; checkExit
				tar -xzf /s6-overlay-amd64.tar.gz -C /usr ./bin; checkExit
				rm -rf /s6-overlay-amd64.tar.gz; checkExit
				;;

			"debian-"*)
				c_info "Update packages."
				DEBS="bash git rsync sudo wget s6 nfs-common ssh fuse libnfs-utils sshfs ssh-tools"
				apt-get update; checkExit
				apt-get install -y --no-install-recommends ${DEBS}; checkExit

				# Different path for S6 on later versions of Debian.
				ls -1 /usr/bin/s6* | xargs -i ln -s {} /bin 2>/dev/null
				echo ""
				;;
			esac

			find /var/lib/apt/lists -type f -delete; checkExit

			if [ ! -d /run/sshd ]
			then
				mkdir /run/sshd
			fi
		;;

	"ubuntu-"*)
		c_info "Update packages."
		DEBS="bash git rsync sudo wget nfs-common ssh fuse sshfs"
		echo 'debconf debconf/frontend select Noninteractive' | debconf-set-selections
		apt-get update; checkExit
		apt-get install -y --no-install-recommends ${DEBS}; checkExit

		apt-get install -y apt-utils locales; checkExit
		# apt-get install -y curl tzdata; checkExit
		# locale-gen en_US.UTF-8; checkExit
		# curl -SLO "https://github.com/just-containers/s6-overlay/releases/download/v1.20.0.0/s6-overlay-${ARCH}.tar.gz"; checkExit

		c_info "Install S6."
		cd /
		wget -nv --no-check-certificate "https://github.com/just-containers/s6-overlay/releases/download/v1.20.0.0/s6-overlay-amd64.tar.gz"; checkExit
		tar -xzf /s6-overlay-amd64.tar.gz -C /; checkExit
		tar -xzf /s6-overlay-amd64.tar.gz -C /usr ./bin; checkExit
		rm -rf /s6-overlay-amd64.tar.gz; checkExit

		find /var/lib/apt/lists -type f -delete; checkExit

		if [ ! -d /run/sshd ]
		then
			mkdir /run/sshd
		fi
		;;

	*)
		c_err "Unknown base O/S."
		exit 1
		;;
esac


## Add env for SSHD
#env|sort|egrep '^GEARBOX|^HTTP' | awk -F= '{print$1"=\x27"$2"\x27; export "$1}' > /etc/profile.d/00-gearbox.sh
## Important for passing environment through for SSH.
#env | awk -F= '
#$1~/^HOSTNAME$/||$1~/^PWD$/||$1~/^HOME$/||$1~/^SHLVL$/||$1~/^PATH$/||$1~/^_$/||$1~/^SSH/||$1~/^SHELL$/||$1~/^LOGNAME$/{next}
#{print$1"=\x27"$2"\x27; export "$1}
#' | sort > /etc/environment


GROUP="$(grep ^gearbox /etc/group)"
if [ -z "${GROUP}" ]
then
	c_ok "Adding gearbox group."
	GROUPADD="$(which groupadd)"
	if [ -z "${GROUPADD}" ]
	then
		echo 'gearbox:x:1000:' >> /etc/group
	else
		groupadd -g 1000 gearbox; checkExit
	fi
fi


if [ ! -d /var/mail ]
then
	c_ok "Creating /var/mail."
	mkdir /var/mail
fi


PASSWD=$(grep ^gearbox /etc/passwd)
if [ -z "${PASSWD}" ]
then
	c_ok "Adding gearbox user."
	GROUPADD="$(which useradd)"
	if [ -z "${GROUPADD}" ]
	then
		echo 'gearbox:x:1000:1000:Gearbox user:/home/gearbox:/bin/bash' >> /etc/passwd
		echo 'gearbox:$6$XdlAWysgxyUyxjAV$ivrS09OkFINgCUdHjUQYG68FqW/Dkyia1iB1AN2RpgqdmgGP4DtYOAj47C5xCX8pD5iOub0q6M66zBn2bX27m1:17927:0:99999:7:::' >> /etc/shadow
	else
		useradd -d /home/gearbox -c "Gearbox user" -u 1000 -g 1000 -N -s /bin/bash -p '$6$XdlAWysgxyUyxjAV$ivrS09OkFINgCUdHjUQYG68FqW/Dkyia1iB1AN2RpgqdmgGP4DtYOAj47C5xCX8pD5iOub0q6M66zBn2bX27m1' gearbox; checkExit
	fi
fi


if [ -d "/etc/gearbox/rootfs/" ]
then
	c_ok "Copying /etc/gearbox/rootfs/ to /."
	chown -fhR root:root /etc/gearbox/rootfs; checkExit
	chown -fhR gearbox:gearbox /etc/gearbox/rootfs/home/gearbox; checkExit
	rsync -HvaxP /etc/gearbox/rootfs/ /; checkExit
else
	c_err "Error: /tmp/rootfs does not exist."
	exit 1
fi


c_info "Generate SSH host keys."
/usr/bin/ssh-keygen -A
addgroup fuse 2>/dev/null
addgroup gearbox fuse 2>/dev/null


#c_ok "Installing MailHog client."
#export GOPATH=/etc/gearbox/gocode
#if [ ! -d "${GOPATH}" ]
#then
#	mkdir -p ${GOPATH}; checkExit
#fi
#go get github.com/mailhog/mhsendmail; checkExit
#find ${GOPATH} | xargs ls -ld
#du -sh ${GOPATH}
#mv ${GOPATH}/bin/MailHog /usr/local/bin; checkExit
#rm -rf ${GOPATH}


c_ok "Cleaning up."
find /usr/local/*bin -type f | xargs chmod 775


c_ok "Finished."
exit 0
