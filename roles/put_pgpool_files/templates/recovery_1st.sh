#!/bin/bash

# Do base backup by rsync in streaming replication

MASTER_NODE_PGDATA=$1
DEST_NODE_HOST=$2
DEST_NODE_PGDATA=$3

#===============================================================================
#  PREPARE
#===============================================================================
source /usr/local/etc/config_for_pgpool-II_script

SCRIPT_LOG="$PGPOOL_LOG_DIR/recovery.log"
exec >>$SCRIPT_LOG 2>&1

PGSETTINGS_DIR=/etc/postgresql/9.3/main
DB=postgres
RECOVERY_USER=postgres
RECOVERY_PASS=postgres

#===============================================================================
#  MAIN SCRIPT
#===============================================================================
# Get the node number of master
MASTER_NODE_NUM=$(get_master_node_num; echo $?)
MASTER_NODE_HOST=${BACKEND_HOST_ARR[$MASTER_NODE_NUM]}
MASTER_NODE_PORT=${BACKEND_PORT_ARR[$MASTER_NODE_NUM]}
MASTER_NODE_ARCHIVE_DIR=${BACKEND_ARCHIVE_DIR_ARR[$MASTER_NODE_NUM]}

# Get the node number of destination
DEST_NODE_NUM=$(get_dest_node_num $DEST_NODE_HOST; echo $?)
DEST_NODE_HOST=${BACKEND_HOST_ARR[$DEST_NODE_NUM]}
DEST_NODE_PORT=${BACKEND_PORT_ARR[$DEST_NODE_NUM]}
DEST_NODE_ARCHIVE_DIR=${BACKEND_ARCHIVE_DIR_ARR[$DEST_NODE_NUM]}

echo "----------------------------------------------------------------------"
date
echo "----------------------------------------------------------------------"
echo "recovery node: $DEST_NODE_NUM"
echo "from node: $MASTER_NODE_NUM"
echo ""

# ---------------------------------------------------------------------
# start base backup
# ---------------------------------------------------------------------
echo "1. pg_start_backup"

{% if synchronous_standby_names %}
cat >>$MASTER_NODE_PGDATA/postgresql.conf <<-EOT
synchronous_standby_names = ''
EOT
$PG_CTL -D $MASTER_NODE_PGDATA reload
{% endif %}

{% if repli_mode == 'stream' %}
$PSQL -p $MASTER_NODE_PORT -U $PG_SUPER_USER \
	-c "SELECT pg_start_backup('Streaming Replication', true)" $DB
{% elif repli_mode == 'native' %}
$PSQL -p $MASTER_NODE_PORT -U $PG_SUPER_USER \
	-c "SELECT pg_start_backup('Native Replication', true)" $DB
{% endif %}

# ---------------------------------------------------------------------
# rsync db cluster
# ---------------------------------------------------------------------
echo "2. rsync: `whoami`@localhost:$MASTER_NODE_PGDATA -> $PG_SUPER_USER@$DEST_NODE_HOST:$DEST_NODE_PGDATA"

rsync -C -a -c --delete \
	--exclude postmaster.pid --exclude postmaster.opts --exclude pg_log \
	--exclude recovery.conf --exclude recovery.done --exclude pg_xlog \
	$MASTER_NODE_PGDATA/ \
	$PG_SUPER_USER@$DEST_NODE_HOST:$DEST_NODE_PGDATA/

ssh $PG_SUPER_USER@$DEST_NODE_HOST -T "if ! [ -e $DEST_NODE_PGDATA/pg_xlog ]; then mkdir $DEST_NODE_PGDATA/pg_xlog; fi"

# port
if [ "${MASTER_NODE_PORT}" != "${DEST_NODE_PORT}" ]; then
    echo "Replace port" >> ${SCRIPT_LOG}
    ssh ${PG_SUPER_USER}@${DEST_NODE_HOST} -T "
        sed -i \"s|^port[ ]*=[ ]*${MASTER_NODE_PORT}|port = ${DEST_NODE_PORT}|\" ${DEST_NODE_PGDATA}/postgresql.conf
    "
fi

# archive_command
if [ "${MASTER_NODE_ARCHDIR}" != "${DEST_NODE_ARCHDIR}" ]; then
    echo "Replace archive_command" >> ${SCRIPT_LOG}
    ssh ${PG_SUPER_USER}@${DEST_NODE_HOST} -T "
        sed -i \"s|${MASTER_NODE_ARCHIVE_DIR}|${DEST_NODE_ARCHIVE_DIR}|\" ${DEST_NODE_PGDATA}/postgresql.conf
    "
fi

# ---------------------------------------------------------------------
# recovery.conf
# ---------------------------------------------------------------------
echo "3. create recovery.conf"

{% if repli_mode == 'stream' %}
cat >recovery.conf <<-EOT
standby_mode             = 'on'
{% if synchronous_standby_names %}
primary_conninfo         = 'host=$MASTER_NODE_HOST port=$MASTER_NODE_PORT user=$RECOVERY_USER password=$RECOVERY_PASS application_name=$DEST_NODE_HOST'
{% else %}
primary_conninfo         = 'host=$MASTER_NODE_HOST port=$MASTER_NODE_PORT user=$RECOVERY_USER password=$RECOVERY_PASS'
{% endif %}
recovery_target_timeline = 'latest'
restore_command          = 'scp $PG_SUPER_USER@$MASTER_NODE_HOST:$MASTER_NODE_ARCHIVE_DIR/%f %p'
EOT
{% elif repli_mode == 'native' %}
cat >recovery.conf <<-EOT
standby_mode             = 'on'
restore_command          = 'scp $PG_SUPER_USER@$MASTER_NODE_HOST:$MASTER_NODE_ARCHIVE_DIR/%f %p'
EOT
{% endif %}
scp recovery.conf $PG_SUPER_USER@$DEST_NODE_HOST:$DEST_NODE_PGDATA/
rm -f recovery.conf

# ---------------------------------------------------------------------
# stop base backup
# ---------------------------------------------------------------------
echo "5. pg_stop_backup"

$PSQL -p $MASTER_NODE_PORT -U $PG_SUPER_USER -c "SELECT pg_stop_backup()" $DB

{% if synchronous_standby_names %}
sed -i -e '$d' $MASTER_NODE_PGDATA/postgresql.conf
$PG_CTL -D $MASTER_NODE_PGDATA reload
{% endif %}

echo ""
exit 0
