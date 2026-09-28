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
| `ssh-config-github` | `~/.ssh/config` block: SSH over 443, connection reuse, long timeouts, small key exchange |
| `99-mtu.conf` | sysctl that enables TCP MTU probing |

## Install

```bash
ln -sf ~/plane-net/plane-net ~/bin/plane-net
cat ~/plane-net/ssh-config-github >> ~/.ssh/config
sudo cp ~/plane-net/99-mtu.conf /etc/sysctl.d/ && sudo sysctl --system
```

`~/bin` is added to `PATH` by Ubuntu's `~/.profile` at login, if the directory exists.

## Before the flight

- `gh auth status`, and log in to anything else that needs a browser.
- Use an authenticator app for 2FA, not SMS.
- Check `ssh -T git@github.com` works with the SSH config above.

## On the plane

```bash
plane-net           # diagnose only
plane-net --apply   # also set the interface MTU to the probed value (sudo)
plane-net --reset   # restore MTU 1500 (sudo)
```

`plane-net` checks, in order:

1. **Portal:** fetches a URL that returns 204 unless intercepted. If
   intercepted, open `http://neverssl.com` and log in, then rerun.
2. **MTU:** binary-searches the largest unfragmented ping to github.com.
   If ping is blocked entirely, guess with `sudo ip link set <iface> mtu 1400`.
3. **GitHub:** attempts SSH auth to `git@github.com`.

After one SSH connection succeeds, later git commands reuse it (via
`ControlMaster`) and skip the handshake.

If everything passes and git still hangs, the cause is likely throttling or the
link dropping, not MTU.
