FROM freeradius/freeradius-server:3.2.0

ADD conf/radiusd.conf /etc/freeradius/radiusd.conf
ADD conf/default /etc/freeradius/sites-enabled/default
ADD conf/inner-tunnel /etc/freeradius/sites-enabled/inner-tunnel
ADD conf/eap /etc/freeradius/mods-available/eap
ADD conf/sql.env /etc/freeradius/mods-available/sql.env

# these files are overwritten by the k8s deployment and only included for documentation purposes
# https://github.com/VSETH-GECO/k8s/blob/main/radius/configmap.yaml
ADD conf/authorize /etc/freeradius/mods-config/files/authorize
ADD conf/clients.conf /etc/freeradius/clients.conf

ADD bootstrap.sh /

RUN apt update && \
    apt install -y gettext && \
    rm -Rf /var/cache/apt/*

ENTRYPOINT /bootstrap.sh
