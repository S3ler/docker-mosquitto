#!/bin/bash
# This script creates the table layout of the database given in mos_db.conf

IPAddress=$(sudo docker inspect mysql-mosq | grep IPAddress | tail -n1 | cut -d '"' -f 4)
mysql -uroot -pmypassword -h${IPAddress} -P3306 < mosq_db.conf

