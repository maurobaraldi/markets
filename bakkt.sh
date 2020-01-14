#!/bin/bash
#
# v0.1.11  jan/2020  by castaway

HELP="WARRANTY
	Licensed under the GNU Public License v3 or better and is distributed 
	without support or bug corrections.

	If you found this script useful, consider giving me a nickle! =)

		bc1qlxm5dfjl58whg6tvtszg5pfna9mn2cr2nulnjr


SINOPSIS
	bakkt.sh [-hV]


	Bakkt price ticker and contract volume from <https://www.bakkt.com/> 
	at the terminal. The default option is to get intraday/last weekday 
	prices and volume.

	Market data delayed a minimum of 15 minutes. 

	Required software: Bash, JQ and cURL or Wget.


OPTIONS
	-j 	Debug; print JSON.

	-h 	Show this help.

	-v 	Print this script version.
	"

# Parse options
while getopts ":jhv" opt; do
	case ${opt} in
		j ) # Print JSON
			PJSON=1
			;;
		h ) # Help
	      		echo -e "${HELP}"
	      		exit 0
	      		;;
		v ) # Version of Script
	      		grep -m1 '# v' "${0}"
	      		exit 0
	      		;;
		\? )
	     		printf "Invalid option: -%s\n" "${OPTARG}" 1>&2
	     		exit 1
	     		;;
  	esac
done
shift $((OPTIND -1))

#Check for JQ
if ! command -v jq &>/dev/null; then
	printf "JQ is required.\n" 1>&2
	exit 1
fi

# Test if cURL or Wget is available
if command -v curl &>/dev/null; then
	YOURAPP="curl -sL"
elif command -v wget &>/dev/null; then
	YOURAPP="wget -qO-"
else
	printf "Package cURL or Wget is needed.\n" 1>&2
	exit 1
fi

#Some defaults
CONTRACTURL="https://www.bakkt.com/api/bakkt/marketdata/contractslist/product/23808/hub/26066"

# Contracts opt -- Default option
DATA0="$(${YOURAPP} "${CONTRACTURL}")"

# Print JSON?
if [[ -n ${PJSON} ]]; then
	printf "%s\n" "${DATA0}"
	exit
fi

printf "Bakkt Contract List\n"
jq -r 'reverse[]|"",
	"Market_ID: \(.marketId // empty)",
	"Strip____: \(.marketStrip // empty)",
	"Last_time: \(.lastTime // empty)",
	"End_date_: \(.endDate // empty)",
	"LastPrice: \(.lastPrice // empty)",
	"Change(%): \(.change // empty)",
	"Volume___: \(.volume // empty)"' <<< "${DATA0}"

exit

# Dead code

