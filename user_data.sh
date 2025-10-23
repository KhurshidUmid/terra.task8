#!/bin/bash
# Update packages and install required utilities
yum update -y
yum install -y httpd aws-cli jq

# Enable and start the web server
systemctl enable httpd
systemctl start httpd

# Get instance metadata using IMDSv2 (simplified)
TOKEN=$(curl -s -X PUT "http://169.254.169.254/latest/api/token" \
  -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")

INSTANCE_ID=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" \
  http://169.254.169.254/latest/meta-data/instance-id)

PRIVATE_IP=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" \
  http://169.254.169.254/latest/meta-data/local-ipv4)

# Create the simple web page
cat > /var/www/html/index.html <<EOF
<html>
  <body>
    <h1>This message was generated on instance $INSTANCE_ID</h1>
    <p>Private IP: $PRIVATE_IP</p>
  </body>
</html>
EOF

# Restart the service to make sure page is served
systemctl restart httpd
