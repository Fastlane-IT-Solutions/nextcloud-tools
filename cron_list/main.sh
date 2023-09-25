#!/bin/bash

NEXTCLOUDDIR="/var/www/nextcloud"
CONFIGFILE="$NEXTCLOUDDIR/config/config.php"
function check_dependencies {
	if ! command -v grep &> /dev/null
	then
		echo "grep is not installed, but a dependency for this script"
		echo "Please install grep"
		exit 1
	fi
}
function calc {
	# Get todays date and generate timestamp
	today=`date +%Y-%m-%d`
	today_ts=`date -d $today +%s`

	# Generate timestamp from last_seen
	last_ts=`date -d $last +%s`

	# Calculate date of oldest desired login day and generate timestamp
	oldest=`date -d "$today -$TIME_PERIOD" +%Y-%m-%d`
	oldest_ts=`date -d $oldest +%s`
}
function help_text {
	echo "Usage: main.sh [OPTIONS]"
	echo "OPTIONS includes:"
	echo "		-d | --dir	- Define Nextcloud directory. Must be in double quotes		Default: /var/www/nextcloud"
	exit 1
}
function check_params {
	if [[ $# -ge 1 ]]
	then
		while [ "$1" != "" ]; 
		do
			case $1 in
	      			-d | --dir ) 
					shift
					if [ -d "$1" ]
		        		then
						if  [[ "$1" =~ \/$ ]]
						then
							NEXTCLOUDDIR=${1::-1}
						fi
						NEXTCLOUDDIR=$1
		        		else
		           			echo "$1: directory does not exist" >&2
		           			exit 1
		        		fi
					;;
		    		-h | --help )
					help_text
					;;
		    		* ) 
		        		echo "Invalid option: $1"
		        		help_text
					;;
		  	esac
			shift
		done
	fi
}
function print_result {
	if [[ "$OUTPUT" != "quiet" ]]
	then
		echo $MESSAGE
	fi

}
function perform_action {
	case $ACTION in
		display)
			case $OUTPUT in
				plain)
					MESSAGE="Remnant user $uid is too old. Last login: $last"
					print_result
					;;
				csv)
					MESSAGE="$uid;$last"
					print_result	
					;;
			esac
			;;
		disable)
			`sudo -u $HTTP_USER php ${NEXTCLOUDDIR}/occ user:disable $uid -q`
			MESSAGE="Disabled user with uid $uid. Last logged in: $last"
			print_result
			;;
		delete)
			`sudo -u $HTTP_USER php ${NEXTCLOUDDIR}/occ user:delete $uid -q`
			MESSAGE="Deleted user with uid $uid. Last logged in: $last"
			print_result
			;;
	esac
}
function occ_run {
	sudo -u $HTTP_USER php ${NEXTCLOUDDIR}/occ ldap:show-remnants --short-date --json | jq ".[] | \"\(.ocName);\(.$ROW)\"" | sed 's#"##g'
}
function read_config {
	dbhost=`php -r 'require("$CONFIGFILE"); echo $CONFIG[dbhost];'`
	dbuser=`php -r 'require("$CONFIGFILE"); echo $CONFIG[dbuser];'`
	dbpassword=`php -r 'require("$CONFIGFILE"); echo $CONFIG[dbpassword];'`
	dbname=`php -r 'require("$CONFIGFILE"); echo $CONFIG[dbname];'`
	dbtype=`php -r 'require("$CONFIGFILE"); echo $CONFIG[dbtype];'`
	#dbport=`php -r 'require("$CONFIGFILE"); echo $CONFIG[dbport];'`
	dbtableprefix=`php -r 'require("$CONFIGFILE"); echo $CONFIG[dbtableprefix];'`
}

# Check if dependencies are met
check_dependencies

# Load and check given parameters if there are any
check_params $@

# Read needed configuration values from config.php
read_config

#### Read user_id and last_seen from occ command
case dbtype in
	mysql)
		BINARY="mysql -h $dbhost -u $$dbuser -p$dbpassword -D $dbname -B -e 'SELECT * FROM $dbtableprefix_jobs'"
		;;
	pgsql)
		BINARY="psql"
		;;
	*)
		echo "Unsupported DB type"
		exit 1
		;;
esac

