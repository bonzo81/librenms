#!/bin/bash
set -e

echo "🔧 Setting up LibreNMS development environment..."

# Ensure we're in the correct directory
cd /opt/librenms

# Check if setup has already been completed
if [ -f ".devcontainer/.setup_complete" ]; then
    echo "✅ Development environment already configured"
    echo "Use 'rm .devcontainer/.setup_complete' to force re-setup"
    exit 0
fi

# Set proper ownership and permissions for development
echo "📁 Configuring development permissions..."

# Create development group and add librenms user
groupadd -f librenms-dev || true
usermod -a -G librenms-dev librenms || true

# Set ownership and permissions following official LibreNMS documentation
chown -R librenms:librenms /opt/librenms
chmod 771 /opt/librenms
setfacl -d -m g::rwx /opt/librenms/rrd /opt/librenms/logs /opt/librenms/bootstrap/cache/ /opt/librenms/storage/
setfacl -R -m g::rwx /opt/librenms/rrd /opt/librenms/logs /opt/librenms/bootstrap/cache/ /opt/librenms/storage/

# Ensure all required Laravel directories exist
echo "📂 Creating Laravel directories..."
mkdir -p storage/framework/{cache,sessions,views} storage/app bootstrap/cache logs rrd
chmod -R 775 storage bootstrap/cache logs rrd

# Install PHP dependencies if not already installed
if [ ! -d "vendor" ]; then
    echo "📦 Installing PHP dependencies..."
    composer install --no-dev --optimize-autoloader
fi

# Install Python dependencies
echo "🐍 Installing Python dependencies..."
pip3 install --user -r requirements.txt --break-system-packages 2>/dev/null || pip3 install --user -r requirements.txt

# Set up lnms command completion
echo "💬 Setting up command completion..."
ln -sf /opt/librenms/lnms /usr/bin/lnms || true
cp /opt/librenms/misc/lnms-completion.bash /etc/bash_completion.d/ || true

# Set up cron and logrotate configurations
echo "⏰ Installing system configurations..."
cp /opt/librenms/dist/librenms-scheduler.cron /etc/cron.d/librenms-scheduler || true
sed -i 's/\* \* \* \* \* php/\* \* \* \* \* librenms php/' /etc/cron.d/librenms-scheduler || true
cp /opt/librenms/dist/librenms.cron /etc/cron.d/librenms || true
cp /opt/librenms/misc/librenms.logrotate /etc/logrotate.d/librenms || true

# Create basic .env file if it doesn't exist
if [ ! -f ".env" ]; then
    echo "⚙️ Creating environment configuration..."
    cat > .env << EOF
APP_NAME="LibreNMS Development"
APP_ENV=local
APP_KEY=
APP_DEBUG=true
APP_URL=http://localhost:8080

LOG_CHANNEL=stack

DB_CONNECTION=mysql
DB_HOST=db
DB_PORT=3306
DB_DATABASE=librenms
DB_USERNAME=librenms
DB_PASSWORD=librenmspassword

BROADCAST_DRIVER=log
CACHE_DRIVER=database
QUEUE_CONNECTION=database
SESSION_DRIVER=database

MAIL_MAILER=smtp
MAIL_HOST=localhost
MAIL_PORT=1025
MAIL_USERNAME=null
MAIL_PASSWORD=null
MAIL_ENCRYPTION=null
EOF
fi

# Generate application key if not set
if ! grep -q "APP_KEY=base64:" .env; then
    echo "🔑 Generating application key..."
    php artisan key:generate
fi

# Mark setup as complete
mkdir -p .devcontainer
touch .devcontainer/.setup_complete

echo ""
echo "✅ Development environment setup completed!"
echo ""
echo "📋 Environment Ready:"
echo "  • Dependencies installed"
echo "  • Permissions configured"  
echo "  • Laravel environment prepared"
echo "  • System configurations installed"
echo ""
echo "🚀 Next: Start the container to launch LibreNMS services"
