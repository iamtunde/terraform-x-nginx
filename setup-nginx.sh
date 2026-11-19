#! /bin/bash
set -euo pipefail

apt-get update -y
apt-get install nginx -y

cat > /var/www/html/index.html <<'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>Terraform Deployment</title>
</head>
<body>
    <h1>Deployed with Terraform</h1>
    <p>My first AWS infrastructure deployment.</p>
</body>
</html>
EOF

systemctl enable --now nginx