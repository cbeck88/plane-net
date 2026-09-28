# plane-net

Tools for getting git and GitHub working over in-flight Wi-Fi.

In-flight networks fail in a few typical ways:

- **Captive portal.** Before login, or after the session expires, the network
  intercepts connections. TLS shows certificate errors or hangs.
- **MTU blackhole.** Full-size packets are silently dropped. Small requests
  work, but TLS/SSH handshakes hang, because the server's certificates and key
  exchange fill full-size packets.
- **Satellite latency.** 600 ms+ round trips and random loss make every new
  connection slow, and short timeouts give up.
- **Authentication.** Browser logins and SMS 2FA don't work well in the air.

## Files

| File | What it does |
|---|---|
| `plane-net` | Diagnoses portal, path MTU, and GitHub SSH; optionally lowers the MTU |
| `ssh-config-github` | `~/.ssh/config` block: SSH over 443, connection reuse, dead-link detection, small key exchange |
| `99-mtu.conf` | sysctl that enables TCP MTU probing |
| `install.sh` | Installs all of the above; safe to rerun |

## Install

```bash
~/plane-net/install.sh
```

This:

- links `~/bin/plane-net` (creating `~/bin` if needed),
- adds `Include ~/plane-net/ssh-config-github` to the **top** of `~/.ssh/config`.
  OpenSSH uses the first value it finds for each option, so a `Host` block
  above it would override it,
- installs `99-mtu.conf` to `/etc/sysctl.d/` (sudo).

Ubuntu's `~/.profile` only adds `~/bin` to `PATH` if it existed at login, so a
fresh `~/bin` needs a re-login.

## Before the flight

- `gh auth status`, and log in to anything else that needs a browser.
- Use an authenticator app for 2FA, not SMS.
- Check `ssh -T git@github.com` works with the SSH config above.

## On the plane

```bash
plane-net           # diagnose only
plane-net --apply   # also set the interface MTU to the probed value (sudo)
plane-net --reset   # restore the MTU that --apply replaced (sudo)
```

`plane-net` checks, in order:

1. **Portal:** fetches a URL that returns 204 unless intercepted. If
   intercepted, open `http://neverssl.com` and log in, then rerun. No response
   at all is reported separately as no connectivity.
2. **MTU:** binary-searches the largest unfragmented ping to `1.1.1.1`, down
   to 576. GitHub's hosts aren't used, because some drop large pings. If ping is blocked entirely,
   guess with `sudo ip link set <iface> mtu 1400`. ping can't send past the
   interface MTU, so after `--apply` the probe can't see a better path until
   `--reset`.
3. **GitHub:** attempts SSH auth on a fresh connection, bypassing any shared
   connection whose link may have died.

`--apply` records the interface and its original MTU, and `--reset` restores
exactly that, even if the default route has since moved (e.g. to a VPN).

After one SSH connection succeeds, later git commands reuse it (via
`ControlMaster`) and skip the handshake. If the link drops, that shared
connection is closed after about 45 s and the next command opens a new one.

If everything passes and git still hangs, the cause is likely throttling or the
link dropping, not MTU.
