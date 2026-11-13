# Certificates: Self-Signed to CA-Signed

[Home](README.md) › Certificates: Self-Signed to CA-Signed

## Where certs live

| Secret | Contents |
|---|---|
| `uyuni-ca` | Server CA bundle |
| `uyuni-cert` | Server certificate (+ intermediates) |
| `uyuni-key` | Server private key |
| `uyuni-db-ca`, `uyuni-db-cert`, `uyuni-db-key` | Database equivalents |
| `uyuni-db-user`, `uyuni-db-pass`, `uyuni-db-admin-user`, `uyuni-db-admin-pass` | Database credentials (don't touch for cert work) |
| `uyuni-reportdb-user`, `uyuni-reportdb-pass` | Reporting DB credentials (don't touch for cert work) |

```bash
podman secret ls | grep uyuni
```

> **Key point:** Moving from self-signed to your org's or a commercial CA **changes the root CA**. Every client and proxy must trust the new CA **before** the switch. A client that doesn't can no longer connect, and you'd have to deploy the CA to it by hand.

---

## Step 0: Prepare the files (on the container host)

| File | What it is |
|---|---|
| `ca.crt` | Root CA public certificate |
| `intermediate.crt` | Intermediate CA(s), if any |
| `server.key` | Server private key, **unencrypted** |
| `server.crt` | Server certificate; its SANs must include the server FQDN |

All files in PEM format; RSA or EC keys. The database no longer needs `db` / `reportdb` SANs; the external FQDN is enough, and the same cert can serve both the server and the database.

**Generate a key and CSR:**

```bash
openssl req -new -newkey rsa:4096 -nodes \
  -keyout server.key -out server.csr \
  -subj "/C=US/ST=Utah/O=YourOrg/CN=mlm.example.com" \
  -addext "subjectAltName=DNS:mlm.example.com,DNS:mlm"
```

**Sanity checks:**

```bash
# Key matches cert: the two hashes must match
openssl x509 -noout -modulus -in server.crt | openssl md5
openssl rsa  -noout -modulus -in server.key | openssl md5

openssl x509 -in server.crt -noout -ext subjectAltName      # FQDN present
openssl verify -CAfile ca.crt -untrusted intermediate.crt server.crt
openssl x509 -in server.crt -noout -dates

# Required for 5.2: CA must have Basic Constraints critical, CA:TRUE
openssl x509 -in ca.crt -noout -ext basicConstraints
```

**Combined server cert** (server first, then intermediates in order):

```bash
cat server.crt intermediate.crt > server-combined.crt
```

**Back up first:**

```bash
mgradm backup create /root/mlm-backup-$(date +%F)
```

---

## Path A: MLM 5.2+ — `mgradm ssl` (staged, low disruption, Podman only)

**A1. Stage the new CA alongside the old one.** Both are trusted, and the served cert doesn't change yet.

```bash
mgradm ssl addca --ssl-ca-root /root/ca.crt \
  --ssl-ca-intermediate /root/intermediate.crt
# repeat --ssl-ca-intermediate for each intermediate
```

It restarts services and prints the new CA's SHA-256 fingerprint. Note it.

**A2. Push the combined CA bundle to all clients.**
Web UI: **Systems → Overview** → select all → **Systems → System Set Manager → Overview** → **States: Apply**, then **Highstate: Apply Highstate**.

**A3. Update each proxy's trust** (on each proxy host):

```bash
curl -o /tmp/proxy-ca.pem http://mlm.example.com/pub/RHN-ORG-TRUSTED-SSL-CERT
podman secret create --replace uyuni-ca /tmp/proxy-ca.pem
systemctl restart uyuni-proxy-pod
```

**A4. Confirm clients trust the new CA.**

```bash
mgradm ssl rotate --check-only        # reports which Salt minions trust the new CA
```

It only covers minions that respond. Check offline minions and non-minion systems by hand:

```bash
while openssl x509 -noout -fingerprint -sha256; do :; done \
  < /etc/pki/trust/anchors/RHN-ORG-TRUSTED-SSL-CERT
```

The fingerprint from A1 must be in the list.

**A5. Switch to the new CA and server cert:**

```bash
mgradm ssl rotate --ssl-ca-root /root/ca.crt \
  --ssl-ca-intermediate /root/intermediate.crt \
  --ssl-server-cert /root/server.crt \
  --ssl-server-key /root/server.key
```

The database reuses the server values unless you pass `--ssl-db-*`. `rotate` refuses to proceed if minions don't trust the new CA, unless you add `--force`.

Then go to **After the switch**.

---

## Path B: MLM 5.1 (or 5.2 without staging) — replace Podman secrets

**B1. Replace the secrets** on the container host:

```bash
podman secret create --replace uyuni-ca      /root/ca.crt
podman secret create --replace uyuni-cert    /root/server-combined.crt
podman secret create --replace uyuni-key     /root/server.key

podman secret create --replace uyuni-db-ca   /root/ca.crt
podman secret create --replace uyuni-db-cert /root/server-combined.crt
podman secret create --replace uyuni-db-key  /root/server.key
```

**B2. Restart:**

```bash
mgradm restart
```

**B3. Push the new root CA to all clients immediately** (Web UI: System Set Manager → **Apply States**, then **Apply Highstate**, or `salt '*' state.apply certs`).

There's no staging on this path, so clients can't reach the server over HTTPS until B3 completes. Plan a maintenance window. Deploying the new root CA to clients in advance, where possible, keeps the outage short.

---

## After the switch (both paths)

**1. Verify the server is serving the new cert:**

```bash
openssl s_client -connect mlm.example.com:443 -servername mlm.example.com \
  </dev/null 2>/dev/null | openssl x509 -noout -issuer -subject -dates
```

**2. Spot-check a client:** `zypper ref` should complete with no SSL errors.

**3. Regenerate and redeploy each proxy's config.** Proxy certs are embedded in it, and must be signed by the **same CA** as the server.

```bash
for f in ca.crt proxy.crt proxy.key; do mgrctl cp $f server:/tmp/$f; done
mgrctl cp intermediate.crt server:/tmp/intermediateCA.pem

mgrctl exec -ti 'spacecmd proxy_container_config -- -p 8022 -i /tmp/intermediateCA.pem pxy.example.com mlm.example.com 2048 admin@example.com /tmp/ca.crt /tmp/proxy.crt /tmp/proxy.key -o /tmp/config.tar.gz'

mgrctl cp server:/tmp/config.tar.gz .
```

Copy `config.tar.gz` to the proxy and re-run `mgrpxy install` with it.

**4. Kiwi image build hosts only** (if the CA changed):

```bash
mgrctl exec mgr-package-rpm-certificate-osimage
```

Then apply highstate on the build hosts.

**5. Clean up** private keys from the container and host:

```bash
mgrctl exec -- rm -f /tmp/proxy.key /tmp/ca.crt /tmp/proxy.crt /tmp/intermediateCA.pem
shred -u /root/server.key     # once it's stored securely elsewhere
```

---

## Troubleshooting

| Symptom | Likely cause |
|---|---|
| Clients: `unable to get local issuer certificate` | New CA not on the client. Re-apply states + highstate. |
| Browsers warn about the chain | Intermediates missing. Use the combined cert, or pass `--ssl-ca-intermediate`. |
| Container won't start after replacing secrets | Key/cert mismatch, or encrypted key. Re-run the modulus check. |
| Proxy clients fail, direct clients fine | Proxy config not regenerated, or proxy cert from a different CA. |
| Hostname mismatch | FQDN or alias clients use isn't in the SANs. Reissue the cert. |
| Upgrade to 5.2 fails cert validation | CA missing critical Basic Constraints. Rotate the CA. |

**Related:** [Proxy config generation](09-proxy.md) · [Salt `certs` state](07-salt-api-database.md) · [Backup first](03-server-admin.md#backup-and-restore) · [5.2 CA requirement during upgrade](11-updates-and-upgrades.md)

---

[← Proxy (mgrpxy)](09-proxy.md) · [Home](README.md) · [Updating and Upgrading MLM →](11-updates-and-upgrades.md)
