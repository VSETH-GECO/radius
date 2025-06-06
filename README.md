# FreeRADIUS

## Structure

* `conf`: Containing PolyLAN specific configuration
  * `radiusd.conf`/`default`/`inner-tunnel`/`eap`/`sql`: Your normal config files.
* `bootstrap.sh`: Glues all the special cases from above together.

For development purposes:

* `init`: Sets up the local database
* `test`: Sets up the local freeradius

## Synopsis

The RADIUS server is essentially configured to accept any authentication request (?). The user switch is configured that upon a successful authentication response, the user's port on the user switch is assigned to VLAN 499.

In VLAN 499, the user is presented the network login page provided by `login-ng` (dedicated app)

After a successful login, `login-ng` creates a `bouncer` (dedicated app) job that reassigns the user to the VLAN dedicated to the user switch to which the user is plugged in to.

This works because the bounder can access the freeradius database. On an authentication request, freeradius looks up the attributes for a specific username in the `radreply` table. The `bouncer` edits this table, if a user should be relocated to a different VLAN and also triggers re-authentication of the client via Change-of-Authorization (CoA).

Moreover, the `bouncer` sets the `Cleartext-Password` for a user (identified by its MAC) to its MAC (username == password) via the `radcheck` table (not sure how this is used though).

Presumably, the client uses PAP to authenticate with freeradius, or alternatively EAP-TTLS with MSCHAPv2.

## What is configured?

In general, the configuration files are a modified version of the [default configuration files](https://github.com/FreeRADIUS/freeradius-server/tree/release_3_2_0/raddb).

Overview:

* PAP is enabled
* EAP support is enabled
* By default, EAP-TTLS is used with MSCHAPv2

Detailed:

* `radiusd.conf`
  * log to `stdout`
  * log all (accept and reject) auth results
* `default`
  * disable IPv6 listeners
  * disable various modules in `authorize` (`filter_username`, `chap`, `mschap`, `digest`, `-ldap`)
  * a validator is added for [backwards-compatibility](https://networkradius.com/doc/current/upgrading/other.html). Not sure whats going on with `Tunnel-Private-Group-ID := "499"`, though:

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
* `eap`
  * set `default_eap_type = ttls`
  * enable caching for Session resumption / fast reauthentication
  * set `default_eap_type = mschapv2` in ttls (tunneled tls)
* `inner-tunnel`
  * disable more authorization modules as above (`chap`, `-ldap`, `pap`)
  * same for the authentication modules
  * enable sql
* `sql`
  * set `dialect = "mysql"`
  * set `driver = "rlm_sql_${dialect}"`
  * disable tls with mysql db
  * set db coordinates via env vars (server, port, database, user, password)
  * set `read_groups = no`

Nice explanation of the configuration:

* [default](https://networkradius.com/doc/current/raddb/sites-available/default.html)
* [inner-tunnel](https://networkradius.com/doc/current/raddb/sites-available/default.html)

## Run locally

```bash
docker-compose up --build
```

## Testing

In the local setup, there is a client and a user configured:

`clients.conf`:

```text
client localhost {
 ipaddr = 127.0.0.1
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
