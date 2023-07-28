# Media

SUSE uses a unified installer, this means you can download for example SLES 15 SP4 iso
either Online or Full and be able to install all the products from a single media source.

### Product to Install

* SUSE Linux Enterprise Server 15 SP4
* SUSE Linux Enterprise High Preformanc Computing 15 SP4
* SUSE Linux Enterprise Server for SAP Applications 15 SP4
* SUSE Linux Enterprise Desktop 15 SP4
* SUSE Manager Server 4.3
* SUSE Manager Proxy 4.3
* SUSE Manager Retail Branch Server 4.3

## Installation of SUSE Manager

Choose SUSE Manager Server 4.3, accept the EULA, enter your registration information and continue.
One fo the question the installer will ask is if you want to update repositories during the install,
by default I accept this and move on to the the Extension and Module Selection, here I won't 
modify anything and just hit next unless there is something specific the client needs/wants like
maybe Python 3... next the installer will contact the registration server and pull any updates if
you selected that option.

The next part is to select Add On Products, select next and move on to the System Role and choosing
what kind of install, single disk or multiple disks, this is all depending on your setup. When the
next screen comes up, the main thing to remember is the `/var/spacewalk` partition, this is where
SUMA will store all the products so you will want this to be quite large or at minimum using LVM so 
it can be resized if need be.

*The size of the `/var/spacewalk` should be considered by the number of products you will be mirroring,
each product will require between 10-25GB of space, so for example SLES 15 may need 10GB, then you
will need an additional 10GB for SP1, another 10GB for SP2 and so forth so you can see this can get 
very large very quickly*

Once you have got that, just click through the installer screens and let it install the OS.

## Setup of SUSE Manager

*Ensure hostname is set, `yast susemanager_setup` will fail if the <fqdn> is not setup correctly.*

&emsp;Step 1: run `yast susemanager_setup`
&emsp;Step 2: choose either from scratch or migrate, for this we will setup from scratch
&emsp;Step 3: set the administrator email address
&emsp;Step 4: certificate setup
&emsp;Step 5: setup the database user/password (after this it will run the setup)
&emsp;Step 6: visit the URL that is presented (usually the https://<fqdn>) and setup your administrator account
        and continue the setup and configuration of SUMA

## Configuration of SUSE Manager
Step 1: setup the organization and set the administrator user/password

Your SUMA server is now ready to be used, from here there are several ways to go about setting up and
using SUMA.
