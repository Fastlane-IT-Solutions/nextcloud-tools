#!/bin/bash
function merge_user {
	dataset=$1
	old=$(echo $dataset | cut -d';' -f1)
	new=$(echo $dataset | cut -d';' -f2)
	echo  "Merging user with uid $old into user with uid $new"
}

# If no parameter is given, assume that we get data from STDIN (e.g. pipe) in csv format old_uid;new_uid (semicolon separated)
if [[ $# -eq 0 ]]
then
	cat | while read pipe
	do
		merge_user $pipe
	done 
fi

if [[ $# -ge 1 ]]
then
	while [ "$1" != "" ]; 
	do
	   case $1 in
	    -f | --file )
	        shift
	        if [ -f "$1" ]
	        then
			cat $1 | while read dataset
			do
				merge_user $dataset
			done
	        else
	           echo "$0: $1 is not a valid input file" >&2
	           exit
	        fi
	        ;;
	    -h | --help ) 
	         echo "Usage: my_test [OPTIONS] [old_uid new_uid]"
	         echo "OPTION includes:"
		 echo "		-f | --file - provide a csv source file to read the uid values from. Format: old_uid;new_uid (semicolon separated)"
	         echo "		-h | --help - displays this help message"
		 echo "		the command requires the source file (-f) argument or old uid and new uid in csv format old_uid;new_uid (semicolon separated)"
		 echo "	  	Examples:"
		 echo "		- main.sh -f my_file.csv"
		 echo "		- main.sh old_uid;new_uid"
		 echo "		- echo old_uid;new_uid | main.sh"
	         exit
	      ;;
	    * ) 
	        echo "Invalid option: $1"
	        
	        exit
	       ;;
	  esac
	  shift
	done
fi
