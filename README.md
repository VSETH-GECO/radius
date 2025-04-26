# FreeRADIUS

## Structure

The setup is IMO a bit confusing, so this parts should clarify things.

* `conf`: Containg PolyLAN specific configuration
  * `radiusd.conf`/`default`/`inner-tunnel`: Your normal config files
  * `authorize`/`clients.conf`: Only in this repo included for documentation purpose, but are overwritten on startup, see `k8s`. They contain the switches and users.
  * `sql.env`: Includes the database configuration containing env vars. During startup, these env vars are overwritten and the file overwrites the default at `mods-enabled/sql`.
  * `eap`: Not sure if this is needed as it is only copied to `mods-available/eap`..
* `bootstrap.sh`: Glues all the special cases from above together.

For development purposes:

* `init`: Sets up the local database
* `scripts`: Included the script, that are responsible for overwriting `authorize`/`clients.conf` on startup

## Run locally

```bash
docker-compose up --build
```

## Testing

In the local setup, there is a client and a user configured:

`clients.conf`:

```text
client dockernet {
 ipaddr = 127.0.0.1/8
 secret = testing123
}
```

`mods-config/files/authorize`:

```text
bob Cleartext-Password := "test"
```

Run (within the container):

```bash
➜ docker exec -it freeradius bash
root@68babbd2d9f0:/# radtest bob test 127.0.0.1 0 testing123
Sent Access-Request Id 3 from 0.0.0.0:48770 to 127.0.0.1:1812 length 73
        User-Name = "bob"
        User-Password = "test"
        NAS-IP-Address = 172.20.0.3
        NAS-Port = 0
        Message-Authenticator = 0x00
        Cleartext-Password = "test"
Received Access-Accept Id 3 from 127.0.0.1:1812 to 127.0.0.1:48770 length 20
```
