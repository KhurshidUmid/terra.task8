#!/bin/bash
# Update packages and install required utilities
yum update -y
yum install -y httpd aws-cli jq

# Enable and start the web server
systemctl enable httpd
systemctl start httpd

# Get instance metadata using IMDSv2
TOKEN=$(curl -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
INSTANCE_ID=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" -v http://169.254.169.254/latest/meta-data/instance-id)
PRIVATE_IP=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" -v http://169.254.169.254/latest/meta-data/local-ipv4)

# Create the simple web page
cat > /var/www/html/index.html <<EOF
This message was generated on instance $INSTANCE_ID with the following IP: $PRIVATE_IP
EOF
