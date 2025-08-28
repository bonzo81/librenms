FROM ubuntu:24.04

# Set environment variables to avoid interactive prompts
ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=UTC

# Set the timezone and update package lists
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone && \
    apt-get update

# Install core system packages
RUN apt-get install -y --no-install-recommends \
    curl \
    wget \
    git \
    unzip \
    ca-certificates \
    sudo \
    && rm -rf /var/lib/apt/lists/*

# Install LibreNMS specific packages
RUN apt-get update && apt-get install -y --no-install-recommends \
    acl \
    cron \
    fping \
    graphviz \
    imagemagick \
    mariadb-client \
    mtr-tiny \
    nginx-full \
    nmap \
    rrdtool \
    snmp \
    snmpd \
    whois \
    traceroute \
    && rm -rf /var/lib/apt/lists/*

# Install PHP 8.3 and essential extensions
RUN apt-get update && apt-get install -y --no-install-recommends \
    php8.3 \
    php8.3-cli \
    php8.3-curl \
    php8.3-fpm \
    php8.3-gd \
    php8.3-gmp \
    php8.3-mbstring \
    php8.3-mysql \
    php8.3-snmp \
    php8.3-xml \
    php8.3-zip \
    php8.3-bcmath \
    php8.3-intl \
    php8.3-redis \
    && rm -rf /var/lib/apt/lists/*

# Install Python and essential packages
RUN apt-get update && apt-get install -y --no-install-recommends \
    python3 \
    python3-pip \
    python3-command-runner \
    python3-pymysql \
    python3-dotenv \
    python3-redis \
    python3-setuptools \
    python3-psutil \
    python3-systemd \
    && rm -rf /var/lib/apt/lists/*

# Install Composer and create users in one layer
RUN curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer && \
    groupadd --gid 1002 librenms && \
    useradd --uid 1002 --gid 1002 -d /opt/librenms -M -s "$(which bash)" librenms && \
    groupadd --gid 9999 librenms-dev && \
    usermod -a -G sudo,librenms-dev librenms && \
    echo "librenms ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/librenms && \
    mkdir -p /opt/librenms && \
    chown -R librenms:librenms /opt/librenms && \
    chmod 771 /opt/librenms

# Configure PHP and services in one layer
RUN sed -i 's/;date.timezone =/date.timezone = UTC/' /etc/php/8.3/fpm/php.ini && \
    sed -i 's/;date.timezone =/date.timezone = UTC/' /etc/php/8.3/cli/php.ini && \
    cp /etc/php/8.3/fpm/pool.d/www.conf /etc/php/8.3/fpm/pool.d/librenms.conf && \
    sed -i 's/\[www\]/[librenms]/' /etc/php/8.3/fpm/pool.d/librenms.conf && \
    sed -i 's/user = www-data/user = librenms/' /etc/php/8.3/fpm/pool.d/librenms.conf && \
    sed -i 's/group = www-data/group = librenms/' /etc/php/8.3/fpm/pool.d/librenms.conf && \
    sed -i 's|listen = /run/php/php8.3-fpm.sock|listen = /run/php-fpm-librenms.sock|' /etc/php/8.3/fpm/pool.d/librenms.conf && \
    rm -f /etc/nginx/sites-enabled/default

# Copy configuration files
COPY .devcontainer/nginx-librenms.conf /etc/nginx/sites-available/librenms.conf
COPY .devcontainer/snmpd.conf /etc/snmp/snmpd.conf
COPY .devcontainer/startup.sh /usr/local/bin/startup.sh
COPY .devcontainer/setup.sh /usr/local/bin/setup.sh
COPY .devcontainer/init-permissions.sh /usr/local/bin/init-permissions.sh

# Final configuration layer
RUN ln -s /etc/nginx/sites-available/librenms.conf /etc/nginx/sites-enabled/librenms.conf && \
    curl -o /usr/bin/distro https://raw.githubusercontent.com/librenms/librenms-agent/master/snmp/distro && \
    chmod +x /usr/bin/distro && \
    chmod +x /usr/local/bin/startup.sh && \
    chmod +x /usr/local/bin/setup.sh && \
    chmod +x /usr/local/bin/init-permissions.sh && \
    /usr/local/bin/init-permissions.sh

# Set working directory
WORKDIR /opt/librenms

# Expose ports
EXPOSE 80 443

# Start services
CMD ["/usr/local/bin/startup.sh"]
