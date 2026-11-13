# Proxy (`mgrpxy`)

[Home](README.md) › Proxy (mgrpxy)

```bash
mgrpxy install config.tar.gz              # 5.2 docs form; 5.1 also accepts `mgrpxy install podman config.tar.gz` (check --help)
mgrpxy start
mgrpxy stop
mgrpxy status                             # expect 5 containers in proxy-pod
mgrpxy upgrade podman
mgrpxy support config
mgrpxy --version
systemctl restart uyuni-proxy-pod
```

Proxy containers: `uyuni-proxy-httpd`, `-squid`, `-salt-broker`, `-ssh`, `-tftpd`. The proxy host must be registered as a Salt client of the server before generating its config.

## Generating proxy config on the server

Web UI: **Systems → Proxy Configuration → Generate**. Or:

```bash
# Self-signed server CA only:
mgrctl exec -ti 'spacecmd proxy_container_config_generate_cert -- pxy.example.com srv.example.com 2048 admin@example.com -o /tmp/config.tar.gz'

# Custom / third-party certs:
mgrctl exec -ti 'spacecmd proxy_container_config -- -p 8022 pxy.example.com srv.example.com 2048 admin@example.com /tmp/ca.crt /tmp/proxy.crt /tmp/proxy.key -o /tmp/config.tar.gz'

mgrctl cp server:/tmp/config.tar.gz .
```

**Related:** [Certificates (proxy config after a CA change)](10-certificates.md) · [Proxy updates](11-updates-and-upgrades.md)

---

[← Logs and Persistent Volumes](08-logs-and-volumes.md) · [Home](README.md) · [Certificates: Self-Signed to CA-Signed →](10-certificates.md)
