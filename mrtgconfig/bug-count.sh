#! /bin/sh
MYSQL_AUTH=`cat /usr/local/sakaiconfig/mysql_auth_bugs`
SAKAIDB=`cat /usr/local/sakaiconfig/mysql_db_bugs`
echo `mysql $MYSQL_AUTH -e "select count(BUG_ID) from SAKAI_BUGS where time_to_sec(timediff(now(),BUG_DATE)) < 300;" -N $SAKAIDB`
echo 0
