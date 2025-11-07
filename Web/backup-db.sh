#! /bin/sh
#
# backup-db.sh
#

outdir=${1:-$HOME}

timestamp=$(date +%Y%m%d-%H%M%S)

mysql_outfile="$outdir/mysql-$timestamp.sql.gz"
which mysqldump && \
    echo "MySQL detected. Dumping to $mysql_outfile." && \
    echo "mysql: Use gunzip -c ${mysql_outfile} | mysql to restore" && \
    mysqldump --all-databases | gzip > $mysql_outfile && \
    echo "MySQL dump completed."

pg_outfile="$outdir/postgres-$timestamp.sql.gz"
which pg_dumpall && \
    echo "PostgreSQL detected. Dumping to $pg_outfile." && \
    echo "postgres: Use psql -f <(gunzip -c ${pg_outfile}) to restore" && \
    pg_dumpall | gzip > $pg_outfile && \
    echo "PostgreSQL dump completed."

mongo_outfile="$outdir/mongo-$timestamp.archive"
which mongodump && \
    echo "MongoDB detected. Dumping to $mongo_outfile." && \
    echo "Use mongorestore --archive=${mongo_outfile} --gzip to restore" && \
    mongodump --archive="$mongo_outfile" --gzip && \
    echo "MongoDB dump completed."
