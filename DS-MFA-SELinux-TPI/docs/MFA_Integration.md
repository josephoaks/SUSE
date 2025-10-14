# MFA Integration

## YubiKey/FIDO2 (PAM U2F)

1. Install Tools
   ```bash
   sudo zypper in pam_u2f libfido2
   ```
2. Register Keys
   ```bash
   pamu2fcfg -u <username> > ~/.config/Yubico/u2f_keys
   ```
   *See Client setup for using YubiKey and passing to the server*
3. Deploy to server

   ```bash
   sudo mkdir -p /etc/Yubico
   sudo cp ~/.config/Yubico/u2f_keys /etc/Yubico/
   sudo chmod 600 /etc/Yubico/u2f_keys
   ```
4. Enable in PAM

   `/etc/pam.d/common-auth`
   ```bash
   auth    sufficient      pam_u2f.so      authfile=/etc/Yubico/u2f_keys cue prompt nouserok
   ```

## Okta / Keycloak / SSO via OIDC or SAML

1. Create an OIDC App Integration in Okta:
   * Sign-on method: OIDC – Web App
   * Redirect URI: https://<yourhost>/oauth2/callback
   * Assign to Security-Officers group.

2. Install mod_auth_openidc
   ```bash
   zypper in apache2-mod_auth_openidc`
   ```
3. Configure `/etc/apache2/conf.d/oidc.conf`
   ```apache
   OIDCProviderMetadataURL https://yourdomain.okta.com/.well-known/openid-configuration
   OIDCClientID <client_id>
   OIDCClientSecret <secret>
   OIDCRedirectURI https://ds01.example.com/oauth2/callback
   OIDCCryptoPassphrase randomstring
   OIDCRemoteUserClaim preferred_username
   Require claim groups:Security-Officers
   ```
4. Test
   * Visit a protected URL; Okta prompts MFA (push, WebAuthn, etc.)
   * REMOTE_USER mapped to LDAP user in DS.
  
### Keycloak (SAML or OIDC)

1. Create a realm (e.g., infra), and client tpi-host.
2. Configure Identity Provider: Okta, AD FS, or GitHub OIDC.
3. Export keycloak.json and install mod_auth_openidc as above.
4. Restrict group membership to Security-Officers.

The same TPI wrapper logic applies — only LDAP membership and dual-approval matter.
