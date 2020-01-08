#!/bin/sh

yum -y remove cloud-init
yum -y upgrade

chown -R root:root /root/.ssh
chmod 700 /root/.ssh
chmod 600 /root/.ssh/authorized_keys

mkdir -p /etc/systemd/system/serial-getty@ttyS0.service.d
cat > /etc/systemd/system/serial-getty@ttyS0.service.d/override.conf <<EOF
[Service]
ExecStart=
ExecStart=-/sbin/agetty -o '-p -- \\u' --keep-baud 115200,38400,9600 --noclear --autologin root ttyS0 $TERM
EOF

if ! grep -q /etc/securetty /etc/pam.d/login; then
	sed -i '/^#%PAM/ a\auth sufficient pam_listfile.so item=tty sense=allow file=/etc/securetty onerr=fail apply=root' /etc/pam.d/login
fi

echo ttyS0 > /etc/securetty

