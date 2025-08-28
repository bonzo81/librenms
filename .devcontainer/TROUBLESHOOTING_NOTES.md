# LibreNMS Dev Container Troubleshooting Notes

*Created: August 27, 2025*

## Issue: Dev Container Port 8080 Not Accessible

### Problem Description
The LibreNMS dev container was not accessible at `localhost:8080` even though VS Code showed the port as "running".

### Root Causes Identified

#### 1. Web Services Not Starting
**Problem**: The `docker-compose.yml` command was overriding the Dockerfile's startup script
```yaml
# Original problematic command:
command: /bin/bash -c "while true; do sleep 1000; done"
```

**Solution**: Modified to run the startup script
```yaml
# Fixed command:
command: /bin/bash -c "/usr/local/bin/startup.sh"
```

#### 2. LibreNMS Installer Disabled by Default
**Problem**: The web installer was returning 403 Forbidden due to missing configuration

**Root Cause**: LibreNMS uses an `INSTALL` environment variable to control installer availability
- Default: `INSTALL=false` (installer disabled)
- Required: `INSTALL=true` (installer enabled)

### How LibreNMS Installer Logic Works (Standard Installation)

LibreNMS determines installation status using the `CheckInstalled` middleware:
```php
$installed = ! config('librenms.install') && file_exists(base_path('.env'));
```

**Translation**:
- System is "installed" when: `INSTALL != true` AND `.env` file exists
- System needs "installation" when: No `.env` OR `INSTALL=true`

**Middleware Behavior**:
- **Not installed + Not on install route**: Redirects to `/install`
- **Installed + On install route**: Blocks access (403/Authorization exception)

### Solutions Implemented

#### 1. Fixed Startup Script Execution
Modified `.devcontainer/docker-compose.yml`:
```yaml
command: /bin/bash -c "/usr/local/bin/startup.sh"
```

#### 2. Smart Installer Management
Updated `.devcontainer/startup.sh` to automatically enable/disable installer:
```bash
# Enable installer only if LibreNMS is not configured yet (matching standard LibreNMS logic)
if [ ! -f "/opt/librenms/.env" ] || ! grep -q "^[^#]*NODE_ID=" /opt/librenms/.env 2>/dev/null; then
    echo "LibreNMS not configured yet - enabling web installer"
    # Add INSTALL=true to .env
else
    echo "LibreNMS already configured - installer disabled"
    # Remove INSTALL variable from .env
fi
```

### Installation Process Results

#### Database Migration Success
- ✅ All 353 migrations completed successfully
- ✅ Database schema is current
- ✅ Database connection working

#### Minor Seeding Issue
**Error encountered**:
```
SQLSTATE[HY000] [2002] No such file or directory (Connection: mysql, SQL: delete from `cache`...)
```

**Cause**: Temporary database connection loss during `RolesSeeder` step
**Resolution**: 
- Manual re-run of seeders completed successfully
- Web installer retry option available for such cases

### Key Learnings

#### 1. LibreNMS Installation Logic
- Checks for `.env` file existence (not `config.php` as initially assumed)
- Uses `INSTALL` environment variable as override switch
- `CheckInstalled` middleware runs on all web routes

#### 2. Dev Container Best Practices
- Always ensure services start automatically via startup scripts
- Match container logic to application's standard behavior
- Implement conditional installer enabling based on configuration state

#### 3. Database Setup Robustness
- Temporary connection issues during seeding are normal
- LibreNMS provides retry mechanisms for installation steps
- Manual seeder re-runs can resolve interrupted installations

### Final Working Configuration

#### Port Mapping
- External: `localhost:8080` → Internal: `port 80`
- Services: nginx + PHP-FPM + SNMP + MariaDB + Redis

#### Installer Behavior
- **Fresh container**: Installer automatically enabled
- **After installation**: Installer automatically disabled
- **Reset capability**: Delete `.env` and restart to re-enable installer

#### Database Connection
```
Host: db
Database: librenms
Username: librenms
Password: librenmspassword
```

### Verification Commands

#### Check Services Status
```bash
ps aux | grep -E "(nginx|php|fpm)" | grep -v grep
```

#### Test Web Access
```bash
curl -I http://localhost/
```

#### Validate Installation
```bash
cd /opt/librenms && php validate.php
```

#### Check Database Migration Status
```bash
cd /opt/librenms && php artisan migrate:status
```

### File Changes Made

1. **`.devcontainer/docker-compose.yml`**: Fixed startup command
2. **`.devcontainer/startup.sh`**: Added smart installer logic
3. **`.env`**: Database configuration updated during installation

### Success Indicators
- ✅ `localhost:8080` accessible
- ✅ Redirects to `/login` (not installer)
- ✅ Database validation passes
- ✅ All migrations completed
- ✅ Installer properly disabled after setup

## Issue 5: Validation Issues in Dev Container

**Problems Found During `./validate.php`:**

1. **File Permissions**: Many files owned by root instead of librenms user
   - **Fix**: Added permission fixing to startup.sh with `chown -R librenms:librenms /opt/librenms`
   - **Status**: ✅ Resolved

2. **Base URL Incorrect**: Set to `http://localhost/` instead of `http://localhost:8080/`
   - **Fix**: Added base URL configuration in startup.sh
   - **Status**: ✅ Resolved

3. **Redis Cache Warning**: "You should set CACHE_STORE=redis"
   - **Analysis**: Redis is for distributed polling (advanced/production feature)
   - **Decision**: Removed Redis from dev container - database caching is fine for development
   - **Status**: ✅ Resolved (by design)

4. **Scheduler Not Running**: LibreNMS scheduler service not active
   - **Solution**: Installed cron and used official `/opt/librenms/dist/librenms-scheduler.cron`
   - **Implementation**: Added cron to Dockerfile, copy official cron job in startup.sh
   - **Status**: ✅ Resolved - "Python poller wrapper is polling" now shows OK

5. **No Python Wrapper Pollers**: Missing polling configuration
   - **Status**: ⚠️ Normal for fresh install, devices need to be added first

6. **Git Modified Files**: Dev container creates files that Git tracks
   - **Status**: ⚠️ Expected in development environment

**Key Decisions Made:**
- **Removed Redis**: Not needed for single-instance development
- **Simplified Setup**: Focus on core LibreNMS functionality
- **Container-Friendly**: Avoid systemd dependencies, use basic services

**Final Dev Container Status:**
- ✅ Web interface accessible at localhost:8080
- ✅ Database connected and configured  
- ✅ File permissions correct
- ✅ Base URL configured properly
- ✅ Ready for device addition and development work

## Issue 4: Web Validation Interface JavaScript Errors

**Problem**: After logging in, the validation page shows JavaScript errors and fails to load validation results. Console shows:
```
Uncaught EvalError: Refused to evaluate a string as JavaScript because 'unsafe-eval' is not an allowed source of script in the following Content Security Policy directive: "default-src 'self' http: https: data: blob: 'unsafe-inline'".
```

**Root Cause**: The custom Content Security Policy (CSP) header in nginx configuration was blocking JavaScript frameworks (Alpine.js) from executing dynamic expressions.

**Solution**: Remove the problematic CSP header from nginx configuration. The official LibreNMS documentation does not include CSP headers, and they interfere with the application's JavaScript functionality.

**Fixed in**: `/opt/librenms/.devcontainer/nginx-librenms.conf` - Removed CSP header and excessive security headers that conflict with LibreNMS JavaScript requirements.

**Key Learning**: When adapting LibreNMS for development containers, stick closely to the official nginx configuration from the documentation. Additional security headers may break functionality.

## Development Container Architecture Summary

**Services Used:**
- **Main Container**: LibreNMS application with nginx, PHP-FPM, SNMP
- **Database Container**: MariaDB 10.11 with LibreNMS-specific configuration
- **Removed**: Redis (unnecessary for development, adds complexity)

**Port Mapping:**
- Host `localhost:8080` → Container port `80`
- Host `localhost:8443` → Container port `443` (HTTPS, if configured)

**Key Files:**
- `.devcontainer/docker-compose.yml`: Container orchestration
- `.devcontainer/startup.sh`: Service initialization and configuration
- `.devcontainer/nginx-librenms.conf`: Web server configuration (CSP-free)
- `.devcontainer/Dockerfile`: Container image definition

**Validation Status After Fixes:**
- ✅ Database connectivity and schema
- ✅ File permissions and ownership  
- ✅ Base URL configuration (localhost:8080)
- ✅ Web interface accessibility
- ✅ Scheduler running (Python poller wrapper polling)
- ⚠️ No devices (expected for fresh install)
- ⚠️ Using database locking (acceptable for development)

---

*This document should be updated with any future dev container issues and their solutions.*
