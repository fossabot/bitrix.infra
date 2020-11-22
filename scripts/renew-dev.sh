#!/usr/bin/env sh

# This script recreates dev site from current prod one with deleting old dev in the process

PROD_LOCATION=/home/admin/web/favor-group.ru/public_html
DEV_LOCATION=/home/admin/web/dev.favor-group.ru/public_html

# MySQL variables
PROD_DB=admin_favorgroup
DEV_DB=dev_favor_group_ru
DEV_USER=dev_favor_group_ru
DEV_PASSWORD=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1)

# read MYSQL_ROOT_PASSWORD
. ./private/environment/percona.env

# create temp file to store mysql login and password for the time of the script
# location for it should be the directory which is passed inside the container
mysql_config_file=$(
  echo 'mkstemp(template)' |
    m4 -D template="./private/percona-data/deleteme_XXXXXX"
) || exit

mysql_config_inside_container="/var/lib/mysql/${mysql_config_file##*/}"

echo "[client]\nuser = root\npassword = ${MYSQL_ROOT_PASSWORD}" > ${mysql_config_file}

#docker exec percona-server /bin/mysql --defaults-extra-file=${mysql_config_inside_container} -e "drop database if exists ${DEV_DB};"
docker exec -u0 percona-server /bin/mysql --defaults-extra-file=${mysql_config_inside_container} -e "drop user if exists '${DEV_USER}'@'%';"

# prepare new dev database and user
docker exec -u0 percona-server /bin/mysql --defaults-extra-file=${mysql_config_inside_container} -e "create database ${DEV_DB};"
docker exec -u0 percona-server /bin/mysql --defaults-extra-file=${mysql_config_inside_container} -e "create user '${DEV_USER}'@'%' identified by '${DEV_PASSWORD}';"
docker exec -u0 percona-server /bin/mysql --defaults-extra-file=${mysql_config_inside_container} -e "grant all on ${DEV_DB}.* to '${DEV_USER}'@'%';"
docker exec -u0 percona-server /bin/mysql --defaults-extra-file=${mysql_config_inside_container} -e 'flush privileges;'

# create and load database dump
docker exec -u0 percona-server /bin/mysqldump --defaults-extra-file=${mysql_config_inside_container} --no-tablespaces ${PROD_DB} >prod-dump.sql
echo "[client]\nuser = ${DEV_USER}\npassword = ${DEV_PASSWORD}" > ${mysql_config_file}
cat prod-dump.sql | docker exec -u0 -i percona-server /bin/mysql --defaults-extra-file=${mysql_config_inside_container} ${DEV_DB}

# copy files
# --archive preserves file permissions and so on
# --delete deletes files from destination if they are not present in the source
# --no-inc-recursive calculates file size for progress bar at the beginning
# / in the end of src location avoid creating additional directory level at destination
rsync --archive --no-inc-recursive --delete --info=progress2 ${PROD_LOCATION}/ ${DEV_LOCATION}

# change settings in files to reflect dev site
sed -i "s/.*\$DBName.*/\$DBName = '${DEV_DB}';/" ${DEV_LOCATION}/bitrix/php_interface/dbconn.php
sed -i "s/.*\$DBLogin.*/\$DBLogin = '${DEV_USER}';/" ${DEV_LOCATION}/bitrix/php_interface/dbconn.php
sed -i "s/.*\$DBPassword.*/\$DBPassword = '${DEV_PASSWORD}';/" ${DEV_LOCATION}/bitrix/php_interface/dbconn.php
sed -i "s/.*BX_CACHE_SID.*/define('BX_CACHE_SID', 'dev');/" ${DEV_LOCATION}/bitrix/php_interface/dbconn.php
sed -i "s/.*BX_TEMPORARY_FILES_DIRECTORY.*/define('BX_TEMPORARY_FILES_DIRECTORY', '/tmp/dev.favor-group.ru');/" ${DEV_LOCATION}/bitrix/php_interface/dbconn.php
sed -i "s/.*'sid'.*/'sid' => 'dev'/" ${DEV_LOCATION}/bitrix/.settings_extra.php
sed -i "s/.*'database' =>.*/'database' => '${DEV_DB}',/" ${DEV_LOCATION}/bitrix/.settings.php
sed -i "s/.*'login' =>.*/'login' => '${DEV_USER}',/" ${DEV_LOCATION}/bitrix/.settings.php
sed -i "s/.*'password' =>.*/'password' => '${DEV_PASSWORD}',/" ${DEV_LOCATION}/bitrix/.settings.php

rm -f prod-dump.sql

# clean up tmp file with credentials
rm -f -- "${mysql_config_file}"

# TODO:
# установка для разработки
# фильтр доменов?
# закрыть публичную часть
# поменять url

