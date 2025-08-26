# SLE Micro 5.5 with MLM and FIPS enabled

## OS Setup / Configuration

1. Install MLM using the SUSE Manager Server SelfInstall ISO

2. Enable Cockpit
   ```
   systemctl enable --now cockpit.socket
   reboot
   ```
3. Register the system
   ```
   transactional-update register -p SUSE-Manager-Server/5.0/x86_64 -r <subscription>
   reboot
   ```

4. Install packages for management
   ```
   transactional-update pkg in podman mgradm mgradm-bash-completion
   reboot
   transactional-update pkg install -t pattern microos-fips
   reboot
   ```

5. Update system
   ```
   transactional-update
   reboot
   ```

## MLM Setup and Configuration

1. Edit hosts for MLM
   ```
   transactional-update shell
   vim /etc/hosts # Add local entry for MLM <ip> <fqdn> <short_name>
   exit
   reboot
   ```

2. Enable and Verify FIPS
   ```
   transactional-update shell
   vim /etc/default/grub
   # Append 'fips=1' to the GRUB_CMDLINE_LINUX_DEFAULT line

   exit
   transactional-update grub.cfg
   reboot

   cat /proc/sys/crypt/fips_enabled
   # Output should be "1"
   ```

3. Install MLM Podman
   ```
   mgradm install podman <fqdn> # This is the fqdn set in the /etc/hosts

   # Enter Container shell to modify taskomatic and tomcat for FIPS
   mgrctl term

   cp /usr/lib64/jvm/java-17-openjdk-17/conf/security/java.security /etc/rhn/

   # Change security.useSystemPropertiesFile=true to false
   vim /etc/rhn/java.security

   # Append the following to the JAVA_OPTS variable
   vim /etc/rhn/taskomatic.conf
       # Additional options for taskomatic

       JAVA_OPTS="-Djava.security.properties==/etc/rhn/java.security -Djava.security.debug=properties"

   # Create this file with the content:
   vim /etc/tomcat/conf.d/my_security.conf 
       JAVA_OPTS=" $JAVA_OPTS -Djava.security.properties==/etc/rhn/java.security"

   exit

   # Restart the container, this will take several minutes for everything to come up.
   mgradm restart 
   ```

4. Log into the WebUI and configure MLM
   ```
   https://<fqdn>
   ```
