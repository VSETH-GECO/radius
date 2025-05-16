# FreeRADIUS

## Structure

The setup is IMO a bit confusing, so this parts should clarify things.

* `conf`: Containg PolyLAN specific configuration
  * `radiusd.conf`/`default`/`inner-tunnel`/`eap`: Your normal config files
  * `authorize`/`clients.conf`: Only in this repo included for documentation purpose, but are overwritten on startup, see `k8s`. They contain the switches and users.
  * `sql.env`: Includes the database configuration containing env vars. During startup, these env vars are replaced and the file overwrites the default at `mods-enabled/sql`.
* `bootstrap.sh`: Glues all the special cases from above together.

For development purposes:

* `init`: Sets up the local database
* `scripts`: Included the script, that are responsible for overwriting `authorize`/`clients.conf` on startup

## What is configured?

In general, the configuration files are a modified version of the [default configuration files](https://github.com/FreeRADIUS/freeradius-server/tree/release_3_2_0/raddb).

* `radiusd.conf`
  * log to `stdout`
  * log all (accept and reject) auth results
* `default`
  * disable IPv6 listeners
  * disable various username validators in `authorize` (`filter_username`, `chap`, `mschap`, `digest`, `-ldap`)
  * but we also add a validator, that accepts any authentication request (probably because of our setup with login-ng and bouncer):

    ```text
        if (!control:Cleartext-Password && User-Password) {
            update control {
                    Cleartext-Password := "%{User-Password}"
                    # Dummy value, will not be sent:
                    Tunnel-Private-Group-ID := "499"
            }
    }
    ```

  * disable authentication modules, matching the disabled authorization modules
  * enable `sql` authentication backend
  * disable some accounting options (`detailed`, `unix`)
* `inner-tunnel`
  * disable more authorization modules as above (`chap`, `-ldap`, `pap`)
  * same for the authentication modules
  * enable sql
* `eap`
  * set `default_eap_type = ttls`
  * enable caching for Session resumption / fast reauthentication
  * set `default_eap_type = mschapv2` in ttls (tunneled tls)
* `sql`
  * set `dialect = "mysql"`
  * set `driver = "rlm_sql_${dialect}"`
  * disable tls with mysql db
  * set db coordinates via env vars (server, port, database, user, password)
  * set `read_groups = no`
  * set `read_profiles = yes`
  * set `read_clients = yes`

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
