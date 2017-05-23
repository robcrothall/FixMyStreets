#!/bin/bash
# Backup script to be executed daily by cron
cd ~fms/fixmystreet/backup
mydate=`TZ='Africa/Johannesburg' date +'%Y%m%d%H%M%S'`;
#echo $mydate;
mkdir $mydate;
cd $mydate;
#pwd
myfile="psql$mydate.sql";
#echo $myfile
pg_dump -U fms -f $myfile fixmystreet
mkdir conf;
cp -pr ~fms/fixmystreet/conf/general.yml conf
mkdir wcobrands
cp -pr ~fms/fixmystreet/web/cobrands/fixmystreets/* wcobrands
mkdir tweb
cp -pr ~fms/fixmystreet/templates/web/fixmystreets/* tweb
mkdir temail
cp -pr ~fms/fixmystreet/templates/email/fixmystreets/* temail
#ls -lr
cd ~fms/fixmystreet/
ls -Ral ~fms/fixmystreet/backup/$mydate/ | mutt -s "Backup of FixMyStreets" -- fms
echo "Backup completed on $mydate"
