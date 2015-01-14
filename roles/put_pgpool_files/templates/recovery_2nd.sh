#!/bin/bash

# Force to flush current value of sequences to xlog

MASTER_NODE_PGDATA=$1
DEST_HOST=$2
DEST_NODE_PGDATA=$3

#===============================================================================
#  PREPARE
#===============================================================================
source /usr/local/etc/config_for_pgpool-II_script

SCRIPT_LOG="$PGPOOL_LOG_DIR/recovery.log"
exec >>$SCRIPT_LOG 2>&1

DB=postgres
RECOVERY_USER=postgres
RECOVERY_PASS=postgres

function doSQL()
{
    local _DB=$1
    local _SQL=$2

    $PSQL -p $MASTER_NODE_PORT -U $RECOVERY_PASS -d $_DB -t -c "$_SQL"
}    # ----------  end of doSQL  ----------

#===============================================================================
#  MAIN SCRIPT
#===============================================================================
# Get the node number of master
MASTER_NODE_NUM=$(get_master_node_num; echo $?)
MASTER_NODE_HOST=${BACKEND_HOST_ARR[$MASTER_NODE_NUM]}
MASTER_NODE_PORT=${BACKEND_PORT_ARR[$MASTER_NODE_NUM]}
MASTER_NODE_ARCHIVE_DIR=${BACKEND_ARCHIVE_DIR_ARR[$MASTER_NODE_NUM]}

echo "----------------------------------------------------------------------"
date
echo "----------------------------------------------------------------------"
echo "recovery node: $DEST_NODE_NUM"
echo "from node: $MASTER_NODE_NUM"
echo "recovery 2nd stage"
echo ""

# ---------------------------------------------------------------------
# Get dbnames
# ---------------------------------------------------------------------
doSQL template1 'SELECT datname FROM pg_database WHERE NOT datistemplate AND datallowconn'

# ---------------------------------------------------------------------
# Force to flush current value of sequences to xlog
# ---------------------------------------------------------------------
{% if synchronous_standby_names %}
cat >>$MASTER_NODE_PGDATA/postgresql.conf <<-EOT
synchronous_standby_names = ''
EOT
$PG_CTL -D $MASTER_NODE_PGDATA reload
{% endif %}
while read i
do
  if [ "${i}" != "" ]; then
    doSQL ${i} "SELECT setval(oid, nextval(oid)) FROM pg_class WHERE relkind = 'S'"
  fi
done
doSQL template1 "SELECT pgpool_switch_xlog('$MASTER_NODE_ARCHIVE_DIR')"
{% if synchronous_standby_names %}
sed -i -e '$d' $MASTER_NODE_PGDATA/postgresql.conf
$PG_CTL -D $MASTER_NODE_PGDATA reload
{% endif %}
