#!/bin/bash

exec >/dev/null 2>&1
BUCKET_NAME=bf-portalcontent
DC_DIR=/var/www/apps/devportal
source ${DC_DIR}/env_info
umask 006
s3cmd sync ${DC_DIR}/shared/files/ s3://${BUCKET_NAME}/env/${DEPLOY_ENV}/files/
s3cmd sync s3://${BUCKET_NAME}/env/${DEPLOY_ENV}/files/ ${DC_DIR}/shared/files/
sudo chown -R deploy:apache ${DC_DIR}/shared/files
find ${DC_DIR}/shared/files -type f -exec chmod 660 {} \;
find ${DC_DIR}/shared/files -type d -exec chmod ug+rwx {} \; 

