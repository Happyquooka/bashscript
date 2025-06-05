# bashscript


After setup.sh run following.

sudo nano /etc/postgresql/12/main/pg_hba.conf

sudo service postgresql restart

sudo su

sudo -i -u postgres

psql

-- ALTER USER postgres WITH PASSWORD 'password';



CREATE ROLE admin WITH LOGIN SUPERUSER PASSWORD 'admin';
