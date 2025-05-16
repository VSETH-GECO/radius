FROM freeradius/freeradius-server:3.2.7

# general
ADD conf/radiusd.conf /etc/freeradius/radiusd.conf
# sites
ADD conf/default /etc/freeradius/sites-enabled/default
ADD conf/inner-tunnel /etc/freeradius/sites-enabled/inner-tunnel
# mods
ADD conf/eap /etc/freeradius/mods-enabled/eap 
ADD conf/sql /etc/freeradius/mods-enabled/sql

# these files are overwritten by the k8s deployment and only included for documentation purposes
# https://github.com/VSETH-GECO/k8s/blob/main/radius/configmap.yaml
ADD conf/authorize /etc/freeradius/mods-config/files/authorize
ADD conf/clients.conf /etc/freeradius/clients.conf

ADD bootstrap.sh /

RUN apt update && \
    apt install -y gettext && \
    rm -Rf /var/cache/apt/*

ENTRYPOINT [ "/bootstrap.sh" ]
