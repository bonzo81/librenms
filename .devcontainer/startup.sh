#!/bin/bash
set -e

echo "🚀 Starting LibreNMS Development Container..."

# Run one-time setup if not already completed
if [ ! -f "/opt/librenms/.devcontainer/.setup_complete" ]; then
    echo "📦 First-time setup required..."
    bash /opt/librenms/.devcontainer/setup.sh
fi

# Handle user permissions for development (runtime fix)
if [ ! -z "$HOST_USER_ID" ] && [ ! -z "$HOST_GROUP_ID" ]; then
    echo "👤 Configuring permissions for host user ID $HOST_USER_ID..."
    groupadd -f -g 9999 librenms-dev || true
    usermod -a -G librenms-dev librenms || true
    if ! id -u "$HOST_USER_ID" >/dev/null 2>&1; then
        useradd -u "$HOST_USER_ID" -g "$HOST_GROUP_ID" -G librenms-dev -s /bin/bash -d /home/vscode vscode || true
    fi
fi

# Runtime permission fixes (lightweight)
echo "🔧 Applying runtime permission fixes..."
chown -R librenms:librenms /opt/librenms/rrd /opt/librenms/logs /opt/librenms/bootstrap/cache /opt/librenms/storage 2>/dev/null || true

# Start system services
echo "⚙️ Starting services..."
service php8.3-fpm start
service nginx start
service snmpd start  
service cron start

# Ensure polling cron jobs are installed (critical for every container start)
echo "📡 Verifying polling service configuration..."
if [ ! -f "/etc/cron.d/librenms-scheduler" ]; then
    echo "   Installing scheduler cron job..."
    cp /opt/librenms/dist/librenms-scheduler.cron /etc/cron.d/librenms-scheduler
    sed -i 's/\* \* \* \* \* php/\* \* \* \* \* librenms php/' /etc/cron.d/librenms-scheduler
fi

if [ ! -f "/etc/cron.d/librenms" ]; then
    echo "   Installing polling cron jobs..."
    cp /opt/librenms/dist/librenms.cron /etc/cron.d/librenms
fi

# Reload cron to pick up any new jobs
service cron reload > /dev/null 2>&1

# Wait for database connectivity
echo "🗄️ Waiting for database connection..."
while ! mysqladmin ping -h"$DB_HOST" -u"$DB_USERNAME" -p"$DB_PASSWORD" --silent; do
    echo "   Waiting for database..."
    sleep 2
done
echo "   Database is ready!"

# Configure installer availability based on installation state
cd /opt/librenms
if [ ! -f ".env" ] || ! grep -q "^[^#]*NODE_ID=" .env 2>/dev/null; then
    echo "🔧 Enabling web installer (fresh installation)..."
    if [ ! -f ".env" ]; then
        echo "APP_KEY=" > .env
    fi
    if ! grep -q "^INSTALL=" .env 2>/dev/null; then
        echo "INSTALL=true" >> .env
    else
        sed -i 's/^INSTALL=.*/INSTALL=true/' .env
    fi
    php artisan config:clear 2>/dev/null || true
else
    echo "✅ LibreNMS configured - disabling installer..."
    sed -i '/^INSTALL=/d' .env 2>/dev/null || true
    php artisan config:clear 2>/dev/null || true
    
    # Set correct base URL for development
    sudo -u librenms ./lnms config:set base_url 'http://localhost:8080/' 2>/dev/null || true
fi

# Keep container running
echo "LibreNMS development container is ready!"
echo "Services started:"
echo "  - NGINX (port 80, accessible via localhost:8080)"
echo "  - PHP-FPM"
echo "  - SNMPD"
echo "  - Cron Service (LibreNMS Scheduler)"
echo ""

# Check installation status and provide appropriate guidance
if [ ! -f "/opt/librenms/.env" ] || ! grep -q "^[^#]*NODE_ID=" /opt/librenms/.env 2>/dev/null; then
    echo "🔧 SETUP REQUIRED:"
    echo "  LibreNMS needs to be configured through the web installer."
    echo ""
    echo "📋 Next Steps:"
    echo "  1. Visit: http://localhost:8080/install"
    echo "  2. Follow the web installation wizard"
    echo "  3. Create your admin user account"
    echo ""
else
    # Check if we have users in the database to determine if setup is complete
    cd /opt/librenms
    USER_COUNT=$(mysql -h"$DB_HOST" -u"$DB_USERNAME" -p"$DB_PASSWORD" "$DB_DATABASE" -sNe "SELECT COUNT(*) FROM users;" 2>/dev/null || echo "0")
    
    if [ "$USER_COUNT" = "0" ]; then
        echo "⚠️  CONFIGURATION INCOMPLETE:"
        echo "  LibreNMS database is configured but no admin user exists."
        echo ""
        echo "📋 Next Steps:"
        echo "  1. Visit: http://localhost:8080/install"
        echo "  2. Complete the user creation process"
        echo ""
    else
        echo "✅ INSTALLATION COMPLETE:"
        echo "  LibreNMS is fully configured and ready to use!"
        echo ""
        echo "🎯 Quick Actions:"
        echo "  • Access Web UI: http://localhost:8080/"
        echo "  • Add first device: http://localhost:8080/addhost"
        echo "  • Run validation: sudo -u librenms ./validate.php"
        echo "  • View logs: tail -f /opt/librenms/logs/librenms.log"
        echo ""
        echo "👤 Login Information:"
        echo "  Use the admin credentials you created during installation"
        echo ""
    fi
fi

# Keep the container running
tail -f /dev/null
