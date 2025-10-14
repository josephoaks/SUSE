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
