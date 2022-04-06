# Smallest base image
FROM alpine:3.13

# When using Composer, disable the warning about running commands as root/super user
ENV COMPOSER_ALLOW_SUPERUSER=1

# PHP_INI_DIR to be symmetrical with official php docker image
ENV PHP_INI_DIR /etc/php/7.2

# Persistent runtime dependencies
ARG DEPS="\
        php7.1-phar \
        php7.1-bcmath \
        php7.1-calendar \
        php7.1-mbstring \
        php7.1-exif \
        php7.1-ftp \
        php7.1-openssl \
        php7.1-pdo \
        php7.1-pdo_sqlite \
        php7.1-zip \
        php7.1-sysvsem \
        php7.1-sysvshm \
        php7.1-sysvmsg \
        php7.1-shmop \
        php7.1-sockets \
        php7.1-zlib \
        php7.1-bz2 \
        php7.1-curl \
        php7.1-simplexml \
        php7.1-xml \
        php7.1-opcache \
        php7.1-dom \
        php7.1-xmlreader \
        php7.1-xmlwriter \
        php7.1-tokenizer \
        php7.1-ctype \
        php7.1-session \
        php7.1-fileinfo \
        php7.1-iconv \
        php7.1-json \
        php7.1-posix \
        php7.1-apache2 \
        php7.1-fpm \
        php7.1-gd \
        php7.1-ldap \
        php7.1-mbstring \
        php7.1-mysqli \
        php7.1-mysqlnd \
        php7.1-soap \
        php7.1-sqlite3 \
        php7.1-intl \
        php7.1-mcrypt \
        php-imagick \
        curl \
        git \
        ca-certificates \
        runit \
        openssl \
        sqlite \
        nano \
        composer \
        graphicsmagick \
        imagemagick \
        ghostscript \
        mysql-client \
        iputils \
        apache2 \
"

# PHP.earth Alpine repository for better developer experience
ADD https://repos.php.earth/alpine/phpearth.rsa.pub /etc/apk/keys/phpearth.rsa.pub

#ADD ssh/ssh_script.sh /usr/local/bin

# copy apache folder to racine
COPY apache /

# copy ssh key for deployer
COPY ssh/* /root/.ssh/

# Copy composer 1.4.1
# COPY composer/composer /usr/local/bin/

# Testing: pamtester
RUN echo "http://dl-cdn.alpinelinux.org/alpine/edge/testing/" >> /etc/apk/repositories \
    && echo "https://repos.php.earth/alpine/v3.9" >> /etc/apk/repositories \
    && apk add --upgrade openvpn iptables bash easy-rsa openvpn-auth-pam google-authenticator pamtester libqrencode openssh rsync tar $DEPS \
    && mkdir -p /run/apache2 \
    && mkdir -p /var/www/dev/gateway \
    && mkdir -p /var/www/prod/gateway \
    && echo /var/www/dev/ /var/www/dev/gateway/ | xargs -n 1 cp /var/www/index.php \
    && echo /var/www/prod/ /var/www/prod/gateway/ | xargs -n 1 cp /var/www/index.php \
    && chmod 600  /root/.ssh/authorized_keys \
    && ln -sf /dev/stdout /var/log/apache2/access.log \
    && ln -sf /dev/stderr /var/log/apache2/error.log \
    && ln -s /usr/share/easy-rsa/easyrsa /usr/local/bin \
    && rm -rf /tmp/* /var/tmp/* /var/cache/apk/* /var/cache/distfiles/* \
    && touch /tmp/openvpn-status.log \
    && sed -i s/#PermitRootLogin.*/PermitRootLogin\ yes/ /etc/ssh/sshd_config \
    && sed -i s/#PubkeyAuthentication.*/PubkeyAuthentication\ yes/ /etc/ssh/sshd_config \
    && sed -i s/#PasswordAuthentication.*/PasswordAuthentication\ yes/ /etc/ssh/sshd_config \
    && rm -rf /var/cache/apk/* \
    && sed -ie 's/#Port 22/Port 22/g' /etc/ssh/sshd_config \
    && sed -ri 's/#HostKey \/etc\/ssh\/ssh_host_key/HostKey \/etc\/ssh\/ssh_host_key/g' /etc/ssh/sshd_config \
    && sed -ir 's/#HostKey \/etc\/ssh\/ssh_host_rsa_key/HostKey \/etc\/ssh\/ssh_host_rsa_key/g' /etc/ssh/sshd_config \
    && sed -ir 's/#HostKey \/etc\/ssh\/ssh_host_dsa_key/HostKey \/etc\/ssh\/ssh_host_dsa_key/g' /etc/ssh/sshd_config \
    && sed -ir 's/#HostKey \/etc\/ssh\/ssh_host_ecdsa_key/HostKey \/etc\/ssh\/ssh_host_ecdsa_key/g' /etc/ssh/sshd_config \
    && sed -ir 's/#HostKey \/etc\/ssh\/ssh_host_ed25519_key/HostKey \/etc\/ssh\/ssh_host_ed25519_key/g' /etc/ssh/sshd_config \
    && /usr/bin/ssh-keygen -A \
    && ssh-keygen -t rsa -b 4096 -f  /etc/ssh/ssh_host_key 


# Needed by scripts
ENV OPENVPN=/etc/openvpn
ENV EASYRSA=/usr/share/easy-rsa \
    EASYRSA_CRL_DAYS=3650 \
    EASYRSA_CERT_EXPIRE=3650 \
    EASYRSA_PKI=$OPENVPN/pki

COPY httpd.conf /etc/apache2/
#COPY index.php /var/wwww/

VOLUME ["/etc/openvpn"]

# Internally uses port 1194/udp, remap using `docker run -p 443:1194/tcp`
EXPOSE 80 22 1194/udp 1194/tcp

CMD ["ovpn_run"]

ADD ./bin /usr/local/bin
RUN chmod a+x /usr/local/bin/* \
    && chmod 666 /tmp/*

# Add support for OTP authentication using a PAM module
ADD ./otp/openvpn /etc/pam.d/
