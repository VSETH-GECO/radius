FROM freeradius/freeradius-server:3.2.7

RUN apt update && \
    apt install -y gettext && \
    rm -Rf /var/cache/apt/*

# general
ADD conf/radiusd.conf /etc/freeradius/radiusd.conf
# sites
ADD conf/default /etc/freeradius/sites-enabled/default
ADD conf/inner-tunnel /etc/freeradius/sites-enabled/inner-tunnel
# mods
ADD conf/eap /etc/freeradius/mods-enabled/eap 
ADD conf/sql /etc/freeradius/mods-enabled/sql

ADD bootstrap.sh /

ENTRYPOINT [ "/bootstrap.sh" ]
