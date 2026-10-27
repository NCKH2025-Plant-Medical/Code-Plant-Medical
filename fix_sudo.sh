#!/bin/bash
cat > /etc/sudoers.d/deploy << 'EOF'
Defaults:deploy !use_pty
deploy ALL=(ALL) NOPASSWD: /usr/bin/systemctl restart plant-api, /usr/bin/systemctl stop plant-api, /usr/bin/systemctl start plant-api, /usr/bin/journalctl
EOF
chmod 440 /etc/sudoers.d/deploy
visudo -c -f /etc/sudoers.d/deploy && echo FILE_OK
