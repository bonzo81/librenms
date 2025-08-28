# LibreNMS Development Container

This development container provides a complete LibreNMS environment for development and testing.

## 📁 Script Structure (Optimized)

### **setup.sh** - One-time Development Environment Setup
**Purpose:** Prepares the development environment (runs once per container)

**Functions:**
- 📦 Install PHP/Python dependencies (composer, pip)
- 📁 Create Laravel directories and set permissions
- ⚙️ Configure development environment (.env file)
- 🔑 Generate application keys
- ⏰ Install cron/logrotate configurations
- 💬 Set up command completion

**When it runs:** 
- Automatically on first container start
- Can be run manually: `bash .devcontainer/setup.sh`
- Creates `.devcontainer/.setup_complete` marker file

---

### **startup.sh** - Runtime Service Management  
**Purpose:** Manages services and runtime configuration (runs every container start)

**Functions:**
- 👤 Handle host user permission mapping
- 🔧 Apply lightweight runtime permission fixes
- ⚙️ Start system services (nginx, php-fpm, snmpd, cron)
- 🗄️ Wait for database connectivity
- 🔧 Configure installer availability based on installation state
- 📊 Provide intelligent status guidance

**When it runs:**
- Every time the container starts
- Calls `setup.sh` if needed for first-time setup

---

### **init-permissions.sh** - Build-time Permission Setup
**Purpose:** Sets minimal file ownership during container build

**Functions:**
- 👥 Create librenms-dev group
- 👤 Add librenms user to development group  
- 📁 Set basic LibreNMS directory ownership
- ⚙️ Configure umask for group-writable files

**When it runs:**
- During Docker image build process only

---

## 🎯 Intelligent Status Detection

The startup script provides context-aware guidance:

### **Fresh Installation**
```
🔧 SETUP REQUIRED:
  LibreNMS needs to be configured through the web installer.

📋 Next Steps:
  1. Visit: http://localhost:8080/install
  2. Follow the web installation wizard
  3. Create your admin user account
```

### **Installation Complete**
```
✅ INSTALLATION COMPLETE:
  LibreNMS is fully configured and ready to use!

🎯 Quick Actions:
  • Access Web UI: http://localhost:8080/
  • Add first device: http://localhost:8080/addhost
  • Run validation: sudo -u librenms ./validate.php
  • View logs: tail -f /opt/librenms/logs/librenms.log

👤 Login Information:
  Use the admin credentials you created during installation
```

## 🔧 Development Commands

```bash
# Check container status
docker-compose logs -f

# Validate polling service
.devcontainer/validate-polling.sh

# Run validation
docker-compose exec librenms sudo -u librenms ./validate.php

# Access container shell
docker-compose exec librenms bash

# Force re-setup (if needed)
docker-compose exec librenms rm .devcontainer/.setup_complete
docker-compose restart

# Manual permission fix (if needed)
docker-compose exec librenms bash .devcontainer/setup.sh
```

## 🔧 Troubleshooting

### Polling Service Issues
If polling is not working:

1. **Validate polling setup**:
   ```bash
   docker-compose exec librenms .devcontainer/validate-polling.sh
   ```

2. **Check cron jobs are installed**:
   ```bash
   docker-compose exec librenms ls -la /etc/cron.d/librenms*
   ```

3. **Manual polling test**:
   ```bash
   docker-compose exec librenms sudo -u librenms ./lnms device:poll 1
   ```

4. **Restart services**:
   ```bash
   docker-compose restart
   ```

### Permission Issues
If you encounter permission problems:

1. **Check current permissions**:
   ```bash
   docker-compose exec librenms ls -la /opt/librenms
   ```

2. **Re-run setup** (fixes permissions automatically):
   ```bash
   docker-compose exec librenms bash .devcontainer/setup.sh
   ```

3. **Manual permission fix** (if needed):
   ```bash
   docker-compose exec librenms chown -R librenms:librenms /opt/librenms
   docker-compose exec librenms chmod -R ug=rwX /opt/librenms
   ```

## 🎯 Robust Polling Guarantee

The container uses **three layers** of polling service protection:

1. **Build-time**: Cron jobs pre-installed in Docker image
2. **Setup-time**: Cron jobs verified and installed by `setup.sh`
3. **Runtime**: Cron jobs checked and auto-repaired by `startup.sh`

This ensures polling works **every time**, regardless of:
- ✅ Fresh container builds
- ✅ Container rebuilds  
- ✅ Container restarts
- ✅ Manual cron job deletion
- ✅ File system changes

## 📊 Key Improvements

1. **Clean Separation**: Setup vs Runtime responsibilities
2. **Idempotent Operations**: Setup only runs when needed
3. **Smart Detection**: Knows installation state and provides appropriate guidance
4. **Optimized Performance**: Reduced redundant operations
5. **Better UX**: Clear status messages and next steps
- **SNMP** daemon configured
- Optimized Docker layers for faster builds
- Minimal package installation for reduced image size
- All required system utilities and packages
- Pre-configured for LibreNMS development

## Getting Started

### Prerequisites

- VS Code with the Dev Containers extension
- Docker and Docker Compose

### Setup

1. Open this project in VS Code
2. When prompted, click "Reopen in Container" or use the command palette:
   - `Ctrl+Shift+P` (or `Cmd+Shift+P` on Mac)
   - Select "Dev Containers: Reopen in Container"

3. Wait for the container to build and start (this may take several minutes on first run)

4. Once the container is running, the setup script will automatically run to:
   - Install PHP dependencies with Composer
   - Set proper file permissions
   - Create necessary directories
   - Configure environment variables

### Completing the Installation

After the dev container starts:

1. **Access the web installer**: Open http://localhost:8080/install in your browser

2. **Follow the web installer**:
   - The installer will guide you through the setup process
   - Use these database connection details when prompted:
     - **Host**: `db`
     - **Database**: `librenms`
     - **Username**: `librenms`
     - **Password**: `librenmspassword`

3. **Create admin user**: Follow the installer prompts to create your admin user

4. **Complete configuration**: The installer may prompt you to create or update the `config.php` file

## Services

The dev container includes these services:

- **LibreNMS Web Interface**: http://localhost:8080 (port 8080)
- **MariaDB Database**: Internal container communication
- **Redis**: Internal container communication
- **SNMP Daemon**: Running on the container for testing

## Development Workflow

### File Permissions

The dev container is configured to handle file permissions properly for development:

- **Host User ID**: The container is configured to use your host user ID (1002) for the `librenms` user
- **Shared Group**: A `librenms-dev` group (GID 9999) is created for shared access
- **ACLs**: Access Control Lists are used when available for flexible permissions
- **Automatic Setup**: Permissions are configured automatically during container startup

If you encounter permission issues while editing files in VS Code:

1. **Run the fix-permissions script**:
   ```bash
   .devcontainer/fix-permissions.sh
   ```

2. **Manual permission fix**:
   ```bash
   sudo chown -R librenms:librenms-dev /opt/librenms
   sudo chmod -R g+w /opt/librenms
   ```

3. **Check your user groups** (you should see `librenms-dev`):
   ```bash
   groups
   ```

### Running Commands

Use the integrated terminal in VS Code to run LibreNMS commands:

```bash
# Validate installation
./validate.php

# Run discovery
php discovery.php -h all

# Run polling
php poller.php -h all

# Use lnms commands
lnms device:add localhost
```

### File Permissions

The container automatically sets up proper file permissions for LibreNMS. If you encounter permission issues, run:

```bash
.devcontainer/fix-permissions.sh
```

### Database Access

To access the database directly:

```bash
mysql -h db -u librenms -plibrenmspassword librenms
```

### Logs

View LibreNMS logs:

```bash
tail -f logs/librenms.log
```

## Customization

### Environment Variables

Modify `.env` file in the project root to customize:
- Database settings
- Redis settings
- Application settings
- Debug options

### NGINX Configuration

The NGINX configuration is in `.devcontainer/nginx-librenms.conf` and can be modified as needed.

### PHP Configuration

PHP settings can be modified by updating the Dockerfile and rebuilding the container.

## Troubleshooting

### Container Won't Start

1. Check Docker is running
2. Ensure ports 80 and 3306 are not in use by other services
3. Try rebuilding the container: `Dev Containers: Rebuild Container`

### Permission Issues

Run the setup script again:
```bash
.devcontainer/setup.sh
```

Or use the dedicated fix-permissions script:
```bash
.devcontainer/fix-permissions.sh
```

**Note**: The dev container is configured to handle file permissions properly by:
- Creating the `librenms` user with your host user ID (1002)
- Using a shared `librenms-dev` group for collaborative access
- Setting up ACLs when available for flexible permissions
- Allowing both the container user and your VS Code session to edit files

### Database Connection Issues

Ensure the database service is running:
```bash
docker-compose ps
```

### Web Interface Issues

1. Check NGINX is running: `sudo service nginx status`
2. Check PHP-FPM is running: `sudo service php8.3-fpm status`
3. Check the NGINX error log: `sudo tail -f /var/log/nginx/error.log`

## Production Considerations

This dev container is configured for development and testing only. For production deployment:

1. Use proper SSL/TLS certificates
2. Change default passwords
3. Configure proper security settings
4. Set up proper monitoring and alerting
5. Follow the official production installation guide

## Additional Resources

- [LibreNMS Documentation](https://docs.librenms.org/)
- [LibreNMS GitHub Repository](https://github.com/librenms/librenms)
- [LibreNMS Community](https://community.librenms.org/)
- [LibreNMS Discord](https://discord.gg/librenms)
