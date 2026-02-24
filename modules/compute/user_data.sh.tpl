#!/bin/bash
set -euo pipefail

# --- Logging ---
exec > >(tee /var/log/user-data.log) 2>&1
echo "=== User data script started at $(date) ==="

# --- System updates ---
yum update -y

# --- Install CloudWatch Agent ---
yum install -y amazon-cloudwatch-agent

cat > /opt/aws/amazon-cloudwatch-agent/etc/config.json <<'EOF'
{
  "metrics": {
    "namespace": "${project_name}/${environment}",
    "metrics_collected": {
      "mem": { "measurement": ["mem_used_percent"], "metrics_collection_interval": 60 },
      "disk": { "measurement": ["disk_used_percent"], "resources": ["*"], "metrics_collection_interval": 60 }
    },
    "append_dimensions": { "InstanceId": "$${aws:InstanceId}", "AutoScalingGroupName": "$${aws:AutoScalingGroupName}" }
  },
  "logs": {
    "logs_collected": {
      "files": {
        "collect_list": [
          {
            "file_path": "/var/log/app/*.log",
            "log_group_name": "/app/${project_name}/${environment}",
            "log_stream_name": "{instance_id}",
            "retention_in_days": 30
          },
          {
            "file_path": "/var/log/user-data.log",
            "log_group_name": "/ec2/user-data/${project_name}/${environment}",
            "log_stream_name": "{instance_id}",
            "retention_in_days": 7
          }
        ]
      }
    }
  }
}
EOF

/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
  -a fetch-config -m ec2 \
  -c file:/opt/aws/amazon-cloudwatch-agent/etc/config.json -s

# --- Install Node.js ---
curl -fsSL https://rpm.nodesource.com/setup_20.x | bash -
yum install -y nodejs

# --- Application setup ---
mkdir -p /opt/app /var/log/app
useradd -r -s /sbin/nologin appuser || true

cat > /opt/app/server.js <<'APP'
const http = require('http');
const os = require('os');

const PORT = ${app_port};
const startTime = Date.now();

const server = http.createServer((req, res) => {
  if (req.url === '/health') {
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({
      status: 'healthy',
      uptime: Math.floor((Date.now() - startTime) / 1000),
      hostname: os.hostname(),
      memory: {
        total: Math.floor(os.totalmem() / 1024 / 1024),
        free: Math.floor(os.freemem() / 1024 / 1024),
        usage: Math.floor((1 - os.freemem() / os.totalmem()) * 100)
      },
      timestamp: new Date().toISOString()
    }));
  } else {
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ service: '${project_name}', environment: '${environment}' }));
  }
});

server.listen(PORT, () => console.log('Server running on port ' + PORT));
APP

chown -R appuser:appuser /opt/app /var/log/app

# --- Systemd service (Senior: proper process management) ---
cat > /etc/systemd/system/app.service <<'SVC'
[Unit]
Description=${project_name} Application
After=network.target

[Service]
Type=simple
User=appuser
WorkingDirectory=/opt/app
ExecStart=/usr/bin/node /opt/app/server.js
Restart=always
RestartSec=5
StandardOutput=append:/var/log/app/stdout.log
StandardError=append:/var/log/app/stderr.log
Environment=NODE_ENV=${environment}

[Install]
WantedBy=multi-user.target
SVC

systemctl daemon-reload
systemctl enable app
systemctl start app

echo "=== User data script completed at $(date) ==="
