#!/bin/bash

NEXTCLOUDDIR="/var/www/nextcloud"
HTTP_USER="www-data"
TIME_PERIOD="1 year"
OUTPUT="plain"
ACTION="display"
CLEANUP="false"
USERLIMIT=1000

#### Begin of function definitions
function check_dependencies {
	if ! command -v jq &> /dev/null
	then
		echo "jq is not installed, but a dependency for this script"
		echo "Please install jq"
		exit 1
	fi
}
function calc {
	# Get todays date and generate timestamp
	today=`date -d now`
	today_ts=`date -d "$today" +%s`

	# Generate timestamp from last_seen
	last_ts=`date -d $last +%s`

	# Calculate date of oldest desired login day and generate timestamp
	oldest=`date -d "$today -$TIME_PERIOD"`
	oldest_ts=`date -d "$oldest" +%s`
}
function help_text {
	echo "Usage: main.sh [OPTIONS]"
	echo "OPTIONS includes:"
	echo "		-a | --action	- Select what to do to users [display,disable,delete]		Default: display"
	echo "		-c | --cleanup - Automatically disable users with either no used storage or that have never logged in"
	echo "		-d | --dir	- Define Nextcloud directory. Must be in double quotes		Default: /var/www/nextcloud"
	echo "		-h | --help	- Show this help text"
	echo "		-o | --output	- Select output format [plain,csv,quiet]			Default: plain"
	echo "		-q | --quiet	- Disable output (same as -o quiet)"
	echo "		-t | --time	- Define maximum time since last login (e.g. 1 year)		Default: 1 year"
	echo "				  Valid time formats are: "
	echo "				  	X second(s)"
	echo "				  	X minute(s)"
	echo "				  	X hour(s)"
	echo "				  	X day(s)"
	echo "				  	X week(s)"
	echo "				  	X month(s)"
	echo "				  	X year(s)"
	echo "		-u | --user	- Define the user who's executing the web server		Default: www-data"
	exit 1
}
function check_params {
	if [[ $# -ge 1 ]]
	then
		while [ "$1" != "" ];
		do
			case $1 in
                -a | --action )
	        		shift
					case $1 in
						display)
							ACTION=display
							;;
						disable)
							ACTION=disable
							;;
						delete)
							ACTION=delete
							;;
						*)
							echo "Invalid action. Valid options are: display,disable,delete"
							exit 1
							;;
					esac
					;;
				-c | --cleanup )
					CLEANUP=true
					;;
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
                -o | --output )
                    shift
					case $1 in
						plain)
							OUTPUT=plain
							;;
						csv)
							OUTPUT=csv
							;;
						quiet)
							OUTPUT=quiet
							;;
						*)
							echo "$1: invalid output format. Valid options are: plain,csv,quiet"
							exit 1
							;;
					esac
					;;
	      	    -q | --quiet )
		        		OUTPUT=quiet
		       			;;
	      	    -t | --time )
		        		shift
					if [[ "$1 $2" =~ ^[0-9]{1,}[[:space:]](second|minute|hour|day|week|month|year)(s)?$ ]]
					then
		        		TIME_PERIOD="$1 $2"
						shift
					else
						echo "Invalid time format: $@"
						help_text
					fi
		        		;;
	      	    -u | --user )
		        		shift
		        		HTTP_USER=$1
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

	if [[ $CLEANUP == "true" ]]
	then
		if [[ $last_ts -eq 0 || $used_storage -eq 0 ]]
		then
			if [[ $last_ts -eq 0 ]]
			then
				last=never
			fi
			ACTION="disable"
		fi
	fi

	case $ACTION in
		display)
			case $OUTPUT in
				plain)
					MESSAGE="User $uid was last seen on: $last, uses $used_storage bytes of storage and has $shares shares"
					print_result
					;;
				csv)
					MESSAGE="$uid;$last;$shares"
					print_result
					;;
			esac
			;;
		disable)
			`sudo -u $HTTP_USER php ${NEXTCLOUDDIR}/occ user:disable $uid -q`
			MESSAGE="Disabled user with uid $uid. Last login: $last. Opened Shares: $shares"
			print_result
			;;
		delete)
			`sudo -u $HTTP_USER php ${NEXTCLOUDDIR}/occ user:delete $uid -q`
			MESSAGE="Deleted user with uid $uid. Last login: $last. Opened Shares: $shares"
			print_result
			;;
	esac
}

function get_users {
	sudo -u $HTTP_USER php ${NEXTCLOUDDIR}/occ user:list -i -l $USERLIMIT --output=json | jq -r '.[] | "\(.user_id);\(.last_seen)"'
}
function occ_run {
	sudo -u $HTTP_USER php ${NEXTCLOUDDIR}/occ user:info $uid --output=json | jq -r "\"\(.user_id);\(.last_seen);\(.storage.used)\""
}
function check_input {
	if [[ -z $uid && $last && $used_storage ]]
	then
		echo "Got wrong or no input data from occ command"
		exit 1
	fi
}

function eval_config {
	DBTYPE=$(sudo -u $HTTP_USER php ${NEXTCLOUDDIR}/occ config:system:get dbtype)
	DBNAME=$(sudo -u $HTTP_USER php ${NEXTCLOUDDIR}/occ config:system:get dbname)
	DBHOST=$(sudo -u $HTTP_USER php ${NEXTCLOUDDIR}/occ config:system:get dbhost)
	DBPORT=$(sudo -u $HTTP_USER php ${NEXTCLOUDDIR}/occ config:system:get dbport)
	DBUSER=$(sudo -u $HTTP_USER php ${NEXTCLOUDDIR}/occ config:system:get dbuser)
	DBPASS=$(sudo -u $HTTP_USER php ${NEXTCLOUDDIR}/occ config:system:get dbpassword)
	DBTP=$(sudo -u $HTTP_USER php ${NEXTCLOUDDIR}/occ config:system:get dbtableprefix)
}

function db_query {
	case $DBTYPE in
		mysql)
			DBCLI=mysql
			if [[ $DBPORT == "" ]]
			then
				DBPORT=3306
			fi
			mysql -h $DBHOST -P $DBPORT -u $DBUSER -p$DBPASS -D $DBNAME -Bs -e "${QUERY}"
			;;
		pgsql)
			DBCLI=psql
			if [[ $DBPORT == "" ]]
			then
				DBPORT=5432
			fi
			DBQUERY=""
			;;
		sqlite3)
			DBCLI=sqlite3
			DBQUERY=""
			;;
	esac

	if ! command -v $DBCLI &> /dev/null
	then
		echo "Database client tool ($DBCLI) not found"
		echo "Please install $DBCLI client tools"
		exit 1
	fi


}
#### End of function definitions


# Check if dependencies are met
check_dependencies

# Load and check given parameters if there are any
check_params $@

# Read database configuration from config.php
eval_config

# Get users with last_seen value
get_users | while IFS=\; read uid last
	do
		occ_run | while IFS=\; read uid last used_storage
		do
				check_input
				calc

				if [[ $last_ts -le $oldest_ts ]]
					then
						QUERY="select count(*) from ${DBTP}share where uid_initiator = '$uid'"
						db_query | while read shares
						do
							#echo "User \"$uid\" has $shares shares"
							perform_action
						done

					fi
			done
	done