#!/bin/bash

NEXTCLOUDDIR="/var/www/nextcloud"
HTTP_USER="www-data"
TIME_PERIOD="1 year"
OUTPUT="plain"
ACTION="display"
ROW="detectedOn"

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
	echo "		-a | --action	- Select what to do to users [display,disable,delete]		Default: display"
	echo "		-d | --dir	- Define Nextcloud directory. Must be in double quotes		Default: /var/www/nextcloud"
	echo "		-h | --help	- Show this help text"
	echo "		-o | --output	- Select output format [plain,csv,quiet]			Default: plain"
	echo "		-q | --quiet	- Disable output (same as -o quiet)"
	echo "		-r | --row	- Define which date row to evaluate. [login,detected]		Default: detected"
	echo "				  login: evaluates last login date"
	echo "				  detected: evaluates the date on which the user was marked as remnant"
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
	      	    	  	-r | --row ) 
		        		shift
					case $1 in
						login)
							ROW=lastLogin
							;;
						detected)
							ROW=detectedOn
							;;
						*)
							echo "$1: invalid date row. Valid options are: login,detected"
							exit 1
							;;
					esac
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
function check_input {
	if [[ -z $uid && $last ]]
	then
		echo "Got wrong or no input data from occ command"
		exit 1
	fi
}

# Check if dependencies are met
check_dependencies

# Load and check given parameters if there are any
check_params $@

# Read user_id and last_seen from occ command
occ_run | while IFS=\; read uid last
do
	if [[ "$last" == "-" ]]
	then
		last="1970-01-01"
	fi

	check_input
	# call calculate function
	calc

	if [ $last_ts -le $oldest_ts ]
	then
		perform_action	
	fi

	# DEBUG
#	echo "today: $today"
#	echo "today_ts: $today_ts"
#	echo "last_ts: $last_ts"
#	echo "oldest: $oldest"
#	echo "oldest_ts: $oldest_ts"
done
