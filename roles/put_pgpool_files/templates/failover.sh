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

SCRIPT_LOG="$PGPOOL_LOG_DIR/failover.log"
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
# Do promote only when the primary node failes
# ---------------------------------------------------------------------
if [ "$FAILED_NODE_ID" == "$OLD_PRIMARY_NODE_ID" ]; then
	if [ "$NEW_MASTER_NODE_ID" -ge 3 ]; then
		echo "Node $NEW_MASTER_NODE_ID should not promote to the primary node. This script doesn't anything."
	else
		PROMOTE_COMMAND="$PG_CTL -D $NEW_MASTER_NODE_PGDATA promote"

		echo "The primary node (node $OLD_PRIMARY_NODE_ID) dies."
		echo "Node $NEW_MASTER_NODE_ID takes over the primary."

		echo "Execute: $PROMOTE_COMMAND"
		ssh $PG_SUPER_USER@$NEW_MASTER_NODE_HOST -T "$PROMOTE_COMMAND"
	fi
else
	echo "Node $FAILED_NODE_ID dies, but it's not the primary node. This script doesn't anything."
fi

echo ""
