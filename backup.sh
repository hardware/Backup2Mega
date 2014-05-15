#!/bin/bash

CDAY=$(date +%d%m%Y-%H%M)
BACKUP_FOLDER=/var/backup/backup-$CDAY
ERROR_FILE=$BACKUP_FOLDER/errors.log
ARCHIVE=/var/backup/backup-$CDAY.tar.gz
REMOTE_FOLDER=/Root/ServerBackup
OPTS="-a --force --ignore-errors"
ERROR="An error occurred during the backup process, check the following file ( $ERROR_FILE ) for more informations."

if [ -e $BACKUP_FOLDER ]; then
    rm -rf $BACKUP_FOLDER
fi

mkdir $BACKUP_FOLDER;

logger " "
logger "#########################################################"
logger " "
logger "       STARTING THE SYSTEM FILES BACKUP PROCESS          "
logger " "
logger "#########################################################"
logger " "

logger " -> Backup important directories"
rsync $OPTS /home          $BACKUP_FOLDER 2> $ERROR_FILE
rsync $OPTS /etc           $BACKUP_FOLDER 2> $ERROR_FILE
rsync $OPTS /var/lib/mysql $BACKUP_FOLDER 2> $ERROR_FILE
rsync $OPTS /var/named     $BACKUP_FOLDER 2> $ERROR_FILE
rsync $OPTS /var/ossec     $BACKUP_FOLDER 2> $ERROR_FILE
rsync $OPTS /srv/http/www  $BACKUP_FOLDER 2> $ERROR_FILE

# If an error occurred during the file-copying process
if [ -s $ERROR_FILE ]; then
    logger $ERROR
    exit 0
fi

logger " -> Compressing files"
tar --warning=none -czPf $ARCHIVE $BACKUP_FOLDER 2> $ERROR_FILE

# If an error occurred during compression
if [ -s $ERROR_FILE ]; then
    logger $ERROR
    exit 0
fi

logger " -> Encrypting backup"
gpg --yes --batch --no-tty --passphrase-file=./.gpg-passwd --encrypt $ARCHIVE

rm -rf $ARCHIVE

# Upload the encrypted archive
uploadToMega() {
    megaput --no-ask-password --no-progress --path $REMOTE_FOLDER $ARCHIVE.gpg 2> $ERROR_FILE
}

# Try to upload the backup (up to 5 attempts)
# Several attempts avoids errors like :
# HTTP POST failed => status 500 : Server Too Busy
logger " -> Upload the backup to a remote server"
uploadToMega

nbAttempt=1

# if upload was not done properly, it retries (max 4 times)
while [ -s $ERROR_FILE ]; do
    if [ "$nbAttempt" -lt 5 ]; then
        logger " -> Upload failed... Attempt $nbAttempt"
        uploadToMega

        # If the file is empty, the loop is stopped
        if [ ! -s $ERROR_FILE ]; then
            break
        fi

        let "nbAttempt += 1"
        sleep 30
    else
        logger $ERROR
        exit 0
    fi
done

logger " -> Upload performed correctly"

# Get the remaining disk space on the remote server
FREE_SPACE=`megadf --no-ask-password --free --mb` > /dev/null 2>&1

logger " -> Deleting uncompressed folder"
rm -rf $BACKUP_FOLDER

logger " -> System backup completed successfully, remaining free space on the remote server : $FREE_SPACE MiB."
logger " "
logger "###################################################################"
logger " "
