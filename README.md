## This production-grade Bash script automates the complete deployment workflow for Dockerized applications on remote Linux servers. It handles everything from Git cloning to Nginx configuration with full error handling and validation.


## About Me
- **Name:** Onibonoje Mariam T.
- **Slack Username:** @Mayreeharm
- **Track:** DevOps
- **Stage:** 1

## Project Description
This project is a **production-grade Bash script** that automates the complete setup, deployment, and configuration of a Dockerized application on a remote Linux server. It demonstrates advanced DevOps automation, infrastructure management, and deployment best practices.

## 🚀 Key Features

### Core Functionality
- ✅ **Interactive Parameter Collection** - Validates user inputs (URLs, IPs, ports, SSH keys).
- ✅ **Git Repository Management** - Clones/updates repos using Personal Access Tokenith (PAT) authentication.
- ✅ **Automated Server Provisioning** - Installs Docker, Docker Compose, and Nginx
- ✅ **Dockerized Deployment** - Builds and runs containers with health checks automatically
- ✅ **Nginx Reverse Proxy** - Automatic configuration for port 80 routing to container
- ✅ **Comprehensive Validation** - Tests SSH, Docker, Nginx, and endpoint health
- ✅ **Health Validation** – Tests endpoint responses for 200 OK.
- ✅ **Idempotent Execution** - Safely re-run without breaking existing setups
- ✅ **Detailed Logging** - Timestamped logs for troubleshooting
- ✅ **Error Handling** - Graceful failures with meaningful messages
- ✅ **Cleanup Mode** - Remove all deployed resources with `--cleanup` flag

## 📋 Requirements

### Local Machine
- Bash 4.0 or higher
- Git
- SSH client
- rsync
- curl

### Remote Server
- Ubuntu 20.04+ (or compatible Linux distribution)
- SSH access with key-based authentication
- Sudo privileges
- Ports 22 (SSH), 80 (HTTP), and custom app port (e.g., 8080) open

### GitHub
- Personal Access Token (PAT) with `repo` scope
- Repository containing a `Dockerfile` or `docker-compose.yml`

## 🎯 Usage

### Basic Deployment

```bash
# Make script executable
chmod +x deploy.sh

# Run deployment
./deploy.sh
```

### Cleanup Deployed Resources

```bash
./deploy.sh --cleanup
```

## 📝 Deployment Steps

The script performs the following automated steps:

1. **Collect Parameters**
   - Git repository URL
   - Personal Access Token (PAT)
   - Branch name (default: main)
   - Remote server SSH details (username, IP, key path)
   - Application ports (internal/external)

2. **Clone Repository**
   - Authenticates with PAT
   - Clones or updates repository
   - Switches to specified branch

3. **Verify Docker Files**
   - Checks for Dockerfile or docker-compose.yml
   - Validates project structure

4. **Test SSH Connection**
   - Verifies remote server accessibility
   - Tests key-based authentication

5. **Prepare Remote Environment**
   - Updates system packages
   - Installs Docker, Docker Compose, Nginx
   - Configures services and permissions

6. **Deploy Application**
   - Transfers files via rsync
   - Builds Docker image
   - Runs container with restart policy

7. **Configure Nginx**
   - Creates reverse proxy configuration
   - Routes port 80 to container
   - Reloads Nginx service

8. **Validate Deployment**
   - Checks Docker and Nginx services
   - Verifies container health
   - Tests HTTP endpoint

## 🔐 Security Considerations

- **PAT Handling**: Token is used securely and never logged
- **SSH Keys**: Key-based authentication required (no passwords)
- **Input Validation**: All user inputs are validated before use
- **Error Handling**: Sensitive information protected in error messages

## 📊 Example Output

```
======================================
  Docker Deployment Automation Tool   
======================================
[2025-10-21 20:00:00] === Step 1: Collecting Deployment Parameters ===
Enter Git Repository URL: https://github.com/user/repo.git
Enter Personal Access Token (PAT): ********
Enter branch name [main]: main
Enter remote server username [ubuntu]: ubuntu
Enter remote server IP address: 54.82.33.36
Enter SSH key path [~/.ssh/id_ed25519]: 
Enter application internal port [80]: 80
Enter container external port [8080]: 8080
[2025-10-21 20:00:15] Parameters collected successfully
[2025-10-21 20:00:15] === Step 2: Cloning/Updating Repository ===
[2025-10-21 20:00:20] Repository ready at /tmp/repo
...
[2025-10-28 20:05:00] ✓ Deployment validated successfully!
[2025-10-28 20:05:00] Your app is live at: http://34.204.42.199
======================================
✓ Deployment completed successfully!
======================================
```

## 🛠️ Troubleshooting

### SSH Connection Failed
- Verify SSH key permissions: `chmod 600 ~/.ssh/id_ed25519`
- Ensure public key is in server's `~/.ssh/authorized_keys`
- Check security group allows port 22

### Docker Build Failed
- Check Dockerfile syntax
- Verify all required files are in repository
- Review log file for detailed error messages

### Nginx Configuration Error
- Check port conflicts: `sudo netstat -tulpn | grep :80`
- Test config manually: `sudo nginx -t`
- View Nginx logs: `sudo tail -f /var/log/nginx/error.log`

### Container Not Running
- Check logs: `sudo docker logs hng-app-container`
- Verify port mapping: `sudo docker ps`
- Ensure no port conflicts on host

## 📁 Project Structure

```
.
├── deploy.sh              # Main deployment script
├── Dockerfile             # Docker image definition
├── index.html             # Application content
├── README.md              # This file
└── deploy_*.log           # Timestamped log files
```

## 🎓 Learning Outcomes

This project demonstrates:
- Bash scripting for DevOps automation
- Docker containerization and deployment
- Nginx reverse proxy configuration
- Infrastructure as Code principles
- Error handling and logging best practices
- Idempotent script design
- Security considerations in automation

## 🔗 HNG Internship

This project was created as part of the HNG13 DevOps Internship program.

- Learn more: [HNG Internship](https://hng.tech/internship)
- Hire talented developers: [HNG Hire](https://hng.tech/hire)

## 📄 License

MIT License - Feel free to use and modify for your own projects.

## 👤 Author

**Mariam Temitope Onibonoje**

