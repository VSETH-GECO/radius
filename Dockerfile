FROM freeradius/freeradius-server:3.0.25

ADD conf/inner-tunnel /etc/freeradius/sites-enabled/inner-tunnel
ADD conf/default /etc/freeradius/sites-enabled/default
ADD conf/authorize /etc/freeradius/mods-config/files/authorize
ADD conf/clients.conf /etc/freeradius/clients.conf
ADD conf/eap /etc/freeradius/mods-available/eap
ADD conf/radiusd.conf /etc/freeradius/radiusd.conf
ADD conf/sql.env /etc/freeradius/mods-available/sql.env
ADD bootstrap.sh /

RUN apt update && \
    apt install -y gettext && \
    rm -Rf /var/cache/apt/*

ENTRYPOINT /bootstrap.sh
