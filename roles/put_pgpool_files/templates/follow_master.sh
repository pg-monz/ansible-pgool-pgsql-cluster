#! /bin/bash
#
# Copyright (C) 2014 SRA OSS, Inc. Japan
# Executes this command after master failover
# Special values:
#   %d = node id
#   %h = host name
#   %p = port number
#   %D = database cluster path
#   %m = new master node id
#   %H = hostname of the new master node
#   %M = old master node id
#   %P = old primary node id
#   %r = new master port number
#   %R = new master database cluster path
#   %% = '%' character

# ---------------------------------------------------------------------
# prepare
# ---------------------------------------------------------------------
source /usr/local/etc/config_for_pgpool-II_script

SCRIPT_LOG="$PGPOOL_LOG_DIR/follow_master.log"
exec >>$SCRIPT_LOG 2>&1

FAILED_NODE_ID=$1
FAILED_NODE_HOST=$2
FAILED_NODE_PORT=$3
FAILED_NODE_PGDATA=$4
NEW_MASTER_NODE_ID=$5
NEW_MASTER_NODE_HOST=$6
OLD_MASTER_NODE_ID=$7
OLD_PRIMARY_NODE_ID=$8
NEW_MASTER_NODE_PORT=$9
NEW_MASTER_NODE_PGDATA=${10}

echo "----------------------------------------------------------------------"
date
echo "----------------------------------------------------------------------"
echo ""

echo "
[ node which failed ]
FAILED_NODE_ID           $FAILED_NODE_ID
FAILED_NODE_HOST         $FAILED_NODE_HOST
FAILED_NODE_PORT         $FAILED_NODE_PORT
FAILED_NODE_PGDATA       $FAILED_NODE_PGDATA

[ before failover ]
OLD_PRIMARY_NODE_ID      $OLD_PRIMARY_NODE_ID
OLD_MASTER_NODE_ID       $OLD_MASTER_NODE_ID

[ after faiover ]
NEW_MASTER_NODE_ID       $NEW_MASTER_NODE_ID
NEW_MASTER_NODE_HOST     $NEW_MASTER_NODE_HOST
NEW_MASTER_NODE_PORT     $NEW_MASTER_NODE_PORT
NEW_MASTER_NODE_PGDATA   $NEW_MASTER_NODE_PGDATA
"

# ---------------------------------------------------------------------
# stop and recovery standby node
# ---------------------------------------------------------------------
$PSQL 'connect_timeout=10' -h $FAILED_NODE_HOST -p $FAILED_NODE_PORT -c '\q'
if [ $? -eq 0 ]; then
	ssh $PG_SUPER_USER@$FAILED_NODE_HOST "$PG_CTL -m i stop -D $FAILED_NODE_PGDATA"
	echo "Standby node: $FAILED_NODE_ID stopped."

	sleep 10

	echo "recovery node: $FAILED_NODE_ID"
	echo "from node : $NEW_MASTER_NODE_ID"
	pcp_recovery_node 1 localhost $PCP_PORT $PCP_SUPER_USER $PCP_PASSWORD $FAILED_NODE_ID
fi

echo ""
