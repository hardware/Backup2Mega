Backup2Mega
===========

Backup, secure and send your system files using Megatools and GnuPG.


Requirements
------------

* Linux
* Rsync
* Megatools and a Mega account
* GnuPG ( create your gpg keypair before )

Installation
------------

Install megatools :

```
yaourt -S megatools
```

Configuration
-------------

Create a new configuration file (.megarc) with your Mega credentials :

```
[Login]
Username = ...
Password = ...
```

Create a ".gpg-passwd" file and put in your secret key passphrase :

```
echo "PASSPHRASE" > .gpg-passwd
```

And set permissions for both files :

```
chmod 600 .megarc .gpg-passwd
```

Add this two lines to your gpg configuration file (~/.gnupg/gpg.conf) :

```
default-key YOUR_GPG_KEY_ID
default-recipient YOUR_GPG_KEY_EMAIL_ADDRESS
```

Instructions
------------

Create a new scheduled task by adding a new entry to your crontab file ( crontab -e ) :

```
0 06 * * * /path/to/backup.sh
```
