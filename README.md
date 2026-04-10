# FreeRADIUS

## Structure

* `conf`: Containing PolyLAN specific configuration
  * `radiusd.conf`/`default`/`inner-tunnel`/`eap`/`sql`: Your normal config files.
* `bootstrap.sh`: Glues all the special cases from above together.

For development purposes:

* `init`: Sets up the local database
* `test`: Sets up the local freeradius

## Synopsis

The RADIUS server authenticates users via MAC address (MAB - MAC Authentication Bypass). On the first authentication request from an unknown device, FreeRADIUS accepts the authentication and assigns default VLAN 499.

In VLAN 499, the user is presented with the network login page provided by `login-ng` (dedicated app).

After a successful login, `login-ng` creates a `bouncer` (dedicated app) job that reassigns the user to the VLAN dedicated to the user switch to which the user is connected.

This works because the bouncer can access the FreeRADIUS database. On an authentication request, FreeRADIUS looks up the attributes for a specific username in the `radreply` table. The `bouncer` edits this table when a user should be relocated to a different VLAN and also triggers re-authentication of the client via Change-of-Authorization (CoA).

The `bouncer` sets the `Cleartext-Password` for a user (identified by its MAC) to its MAC address (username == password) via the `radcheck` table. This enables PAP authentication where the switch sends the MAC address as both username and password.

Switches use MAB (MAC Authentication Bypass) with PAP authentication. There are also EAP-TTLS, EAP-PEAP, and EAP-MD5 configured, but are currently not used.

The main reason for using MAB on a user switch is that end-user devices do not have to set up 802.1X on their devices.

### Key Points

* **Method**: User switches use MAB (MAC Authentication Bypass)
* **Authentication**: PAP with username = password = MAC address (lowercase, no separators)
* **VLAN Assignment**: FreeRADIUS returns `Tunnel-Private-Group-Id`, `Tunnel-Medium-Type`, and `Tunnel-Type` attributes
* **CoA Port**: Standard CoA port 3799 for dynamic VLAN changes
* **Accounting**: User switches send Start, Interim-Update, and Stop accounting packets
* **SQL Backend**: MySQL database used for authorization, accounting, session tracking

### Example Initial Authentication Flow (First-Time Device)

1. Unknown device connects to switch
2. Switch sends Access-Request with User-Name = MAC address (e.g., `d45d64b09a27`)
3. FreeRADIUS queries SQL - no entries found in `radcheck` or `radreply`
4. Backwards-compatibility code triggers: accepts any password, assigns VLAN 499
5. FreeRADIUS responds with Access-Accept including VLAN 499 attributes
6. Switch assigns port to VLAN 499
7. User authenticates via captive portal web page
8. `bouncer` creates database entries:
   * `radcheck`: `Cleartext-Password = "d45d64b09a27"`
   * `radreply`: `Tunnel-Private-Group-Id = "502"` (switch-specific VLAN)
9. `bouncer` sends CoA to switch triggering re-authentication
10. Switch re-authenticates, now finds database entries, assigns to proper VLAN

### Example Re-Authentication Flow (for an already authenticated device)

1. Switch sends Access-Request with User-Name = MAC address (e.g., `d45d64b09a27`)
2. FreeRADIUS queries SQL:
   * `radcheck` table: Gets `Cleartext-Password` (same as MAC)
   * `radreply` table: Gets VLAN assignment (e.g., `Tunnel-Private-Group-Id = "502"`)
3. FreeRADIUS responds with Access-Accept including VLAN attributes
4. Switch assigns port to specified VLAN
5. Accounting packets track session (Start, Interim-Update, Stop)

## What is configured?

In general, the configuration files are a modified version of the [default configuration files](https://github.com/FreeRADIUS/freeradius-server/tree/release_3_2_7/raddb).

### `radiusd.conf`

* Log to `stdout` instead of files
* Log all authentication results (both accept and reject)
* Run as `freerad` user/group

### `default` (main virtual server)

* **Authorization section**:
  * Disable various modules: `filter_username`, `chap`, `mschap`, `digest`, `-ldap`
  * Enable SQL with `-sql` prefix (fail-safe: continues if DB unavailable)
  * This [backwards-compatibility](https://networkradius.com/doc/current/upgrading/other.html) validator accepts any password when no `radcheck` db table entry exists, allowing unknown devices to authenticate and are assigned to VLAN 499:

    ```text
    if (!control:Cleartext-Password && User-Password) {
        update control {
            Cleartext-Password := "%{User-Password}"
            # Default VLAN for captive portal (overridden by SQL radreply):
            Tunnel-Private-Group-ID := "499"
        }
    }
    ```

    This ensures users land in VLAN 499 initially for captive portal access. The SQL `radreply` table overrides this with switch-specific VLANs after successful login.

* **Authentication section**:
  * Disable authentication modules matching disabled authorization modules
  * Enable PAP for MAC authentication

* **Accounting section**:
  * Enable SQL accounting with `-sql` prefix
  * Disable `detailed` and `unix` accounting

* **Session section**:
  * Enable SQL for Simultaneous-Use checking

* **Post-Auth section**:
  * Enable SQL post-auth logging with `-sql` prefix

### `eap`

* Set `default_eap_type = ttls` (EAP-TTLS as primary method)
* Enable EAP-MD5 for Cisco SG500x series switches
* **TLS Configuration**:
  * Restrict to TLS 1.2 only (`tls_min_version = "1.2"`, `tls_max_version = "1.2"`)
  * Disables TLS 1.0, 1.1, and 1.3 for maximum compatibility
* **Session Caching**:
  * Enable caching for fast reauthentication
  * 24-hour cache lifetime
  * Store `Tunnel-Private-Group-Id` in cache for VLAN persistence
* **TTLS Configuration**:
  * Set `default_eap_type = mschapv2` in tunneled TLS
* **PEAP Configuration**:
  * Also configured with MSCHAPv2 as alternative to TTLS

### `inner-tunnel` (for EAP tunneled authentication)

* **Authorization section**:
  * Enable `filter_username` (unlike default server)
  * Enable `mschap` module (required for MSCHAPv2)
  * Disable `chap`, `-ldap`
  * Enable SQL with `-sql` prefix
  * Comment out `pap` (not needed with MSCHAPv2)

* **Authentication section**:
  * Enable `mschap` for MSCHAPv2 authentication
  * Disable other authentication modules

* **Session section**:
  * Enable both `radutmp` and `sql` for session tracking

### `sql`

* Set `dialect = "mysql"`
* Set `driver = "rlm_sql_${dialect}"`
* Disable TLS with MySQL database
* Configure database connection via environment variables:
  * `RADIUS_DB_HOST` (server)
  * `RADIUS_DB_PORT` (port)
  * `RADIUS_DB_DB` (database name)
  * `RADIUS_DB_USER` (username)
  * `RADIUS_DB_PASSWORD` (password)
* Set `read_groups = no` (disable group-based authorization)

### Key Deviations from Standard FreeRADIUS v3.0.x

1. **Default VLAN 499**: Custom logic to assign initial VLAN for captive portal
2. **SQL fail-safe mode**: Using `-sql` prefix allows operation even if database is temporarily unavailable
3. **TLS version lock**: Restricted to TLS 1.2 only for compatibility
4. **EAP-MD5 support**: Added specifically for Cisco SG500x switches
5. **Session caching**: Stores VLAN assignment for fast reconnection
6. **No group support**: `read_groups = no` simplifies authorization to per-user basis only

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
