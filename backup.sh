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
logger "###################################################################"
logger " "
logger "       DEMARRAGE DE LA PROCEDURE DE SAUVEGARDE DU SYSTEME          "
logger " "
logger "###################################################################"
logger " "

logger " -> Sauvegarde des répertoires importants"
rsync $OPTS /home          $BACKUP_FOLDER 2> $ERROR_FILE
rsync $OPTS /etc           $BACKUP_FOLDER 2> $ERROR_FILE
rsync $OPTS /var/lib/mysql $BACKUP_FOLDER 2> $ERROR_FILE
rsync $OPTS /var/named     $BACKUP_FOLDER 2> $ERROR_FILE
rsync $OPTS /var/ossec     $BACKUP_FOLDER 2> $ERROR_FILE
rsync $OPTS /srv/http/www  $BACKUP_FOLDER 2> $ERROR_FILE

# Si une erreur est survenue lors de la sauvegarde
if [ -s $ERROR_FILE ]; then
    logger $ERROR
    exit 0
fi

logger " -> Compression des répertoires"
tar --warning=none -czPf $ARCHIVE $BACKUP_FOLDER 2> $ERROR_FILE

# Si une erreur est survenue lors de la compression
if [ -s $ERROR_FILE ]; then
    logger $ERROR
    exit 0
fi

logger " -> Chiffrement du backup"
gpg --yes --batch --no-tty --passphrase-file=./.gpg-passwd --encrypt $ARCHIVE

logger " -> Suppression de l'archive"
rm -rf $ARCHIVE

# Upload de l'archive chiffrée et de la signature numérique
uploadToMega() {
    megaput --no-ask-password --no-progress --path $REMOTE_FOLDER $ARCHIVE.gpg 2> $ERROR_FILE
}

# Essaye d'uploader la sauvegarde ( 5 tentatives maximum )
# Plusieurs tentatives permet d'éviter avec un peu de chance les erreurs du type :
# HTTP POST failed => status 500 : Server Too Busy
logger " -> Upload de la sauvegarde vers un serveur distant"
uploadToMega

nbAttempt=1

# Tant que l'upload ne s'est pas effectué correctement, on essaye ( 4 fois max )
while [ -s $ERROR_FILE ]; do
    if [ "$nbAttempt" -lt 5 ]; then
        logger " -> Echec de l'upload... Tentative $nbAttempt"
        uploadToMega

        # Si le fichier est vide, on arrête la boucle
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

logger " -> Upload effectué avec succès !"

# Récupération de l'espace disque restant sur le serveur distant
FREE_SPACE=`megadf --no-ask-password --free --mb` > /dev/null 2>&1

logger " -> Suppression des repertoires non-compressés"
rm -rf $BACKUP_FOLDER

logger " -> System backup completed successfully, remaining free space on the remote server : $FREE_SPACE MiB."
logger " "
logger "###################################################################"
logger " "
