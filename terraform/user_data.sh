#!/bin/bash
# EC2 첫 부팅 때 한 번 실행된다. 로그: /var/log/cloud-init-output.log
dnf install -y nginx

# GET /health → 200 OK
cat > /etc/nginx/default.d/health.conf <<'CONF'
location = /health {
    default_type text/plain; # 브라우저가 파일로 내려받지 않고 글자로 보여 주게 한다
    return 200 "OK\n";
}
CONF

systemctl enable --now nginx
