#!/usr/bin/bash
#
# Clay.sh -- Currencylayer.com API Access
# v0.2.1 - 2019/jul/24   by mountaineerbr

## Some defaults
# Get your own personal API KEY
#APIKEY=""
# Dev key:
#APIKEY="6f72de44bee2e5411640f522437e9a64"
# Spare Key:
APIKEY="35324a150b81290d9fb15e434ed3d264"
# somabal@emailate.com -- hellodear


## Manual and help
## Usage: $ clay.sh [amount] [from currency] [to currency]
HELP_LINES="NAME
 	\033[01;36mClay.sh -- Currencylayer.com API Access\033[00m


SYNOPSIS
	clay.sh \e[0;35;40m[-h|-j|-l]\033[00m

	clay.sh \e[0;35;40m[-s|-t]\033[00m \e[0;33;40m[AMOUNT]\033[00m \e[0;32;40m[FROM_CURRENCY]\033[00m \
\e[0;31;40m[TO_CURRENCY]\033[00m

DESCRIPTION
	Free plans should get currency updates idaily only.
	It supports very few cyrpto currencies.
	
	This programme fetches updated currency rates from the internet	and can
	convert any amount of one supported currency into another.

	Default precision is 16. Trailing zeroes are trimmed by default.

	Usage example:
		
		(1)

		\e[1;30;40m$ \e[1;34;40mclay.sh 0.5 djf cny -s3\033[00m


OPTIONS
	 	
		-h 	Show this help.

		-j 	Fetch JSON file and send to STOUT.

		-l 	List supported currencies.

		-s 	Set scale ( decimal plates ).

		-t 	Print JSON timestamp.


BUGS
 	This programme is distributed without support or bug corrections.
	Licensed under GPLv3 and above.
		"

# Check if there is any argument
if ! [[ ${*} =~ [a-zA-Z]+ ]]; then
	printf "Run with -h for help.\n"
	exit
fi
# Parse options
while getopts ":lhjs:t" opt; do
  case ${opt} in
  	l ) ## List available currencies
		curl -s https://currencylayer.com/site_downloads/cl-currencies-table.txt |  sed -e 's/<[^>]*>//g'
		exit
		;;
	h ) # Show Help
		echo -e "${HELP_LINES}"
		exit 0
		;;
	j ) # Print JSON
		PJSON=1
		;;
	s ) # Decimal plates
		SCL=${OPTARG}
		;;
	t ) # Print Timestamp with result
		TIMEST=1
		;;
	\? )
		printf "%s\n" "Invalid Option: -$OPTARG" 1>&2
		exit 1
		;;
  esac
done
shift $((OPTIND -1))


## Set default scale if no custom scale
SCLDEFAULTS=16
if [[ -z ${SCL} ]]; then
	SCL=${SCLDEFAULTS}
fi


# Set equation arquments
if [[ -z ${2} ]]; then
	set -- USD ${1^^}
fi

if ! [[ ${1} =~ [0-9] ]]; then
	set -- 1 "${@:1:2}"
fi

if [[ -z ${3} ]]; then
set -- "${@:1:2}" "USD"
fi

## Get JSON once
CLJSON=$(curl -s http://www.apilayer.net/api/live?access_key=${APIKEY}&callback=CALLBACK_FUNCTION)

# Print JSON?
if [[ -n ${PJSON} ]]; then
	printf "%s\n" "${CLJSON}"
	exit 0
fi


## Get currency rates
if ! [[ ${2^^} = USD && ${3^^} = USD ]]; then
	FROMCURRENCY=$(printf "%s\n" "${CLJSON}" | jq ".quotes.USD${2^^}")
	TOCURRENCY=$(printf "%s\n" "${CLJSON}" | jq ".quotes.USD${3^^}")
elif [[ ${2^^} = USD ]]; then
	FROMCURRENCY=1
	TOCURRENCY=$(printf "%s\n" "${CLJSON}" | jq ".quotes.USD${3^^}")
elif [[ ${3^^} = USD ]]; then
	FROMCURRENCY=$(printf "%s\n" "${CLJSON}" | jq ".quotes.USD${2^^}")
	TOCURRENCY=1
fi

## Transform "e" to "*10^" in rates
if printf "%s\n" "${FROMCURRENCY}" | grep "e" &> /dev/null; then
	FROMCURRENCY=$(printf "%s\n" "${FROMCURRENCY}" | sed -E 's/([+-]?[0-9.]+)[eE]\+?(-?)([0-9]+)/(\1*10^\2\3)/g')
	if [[ ${SCL} < 6 ]]; then
		SCL=8
		printf "%s\n" "Scale changed to 8."
	fi
fi
if printf "%s\n" "${TOCURRENCY}" | grep "e" &> /dev/null; then
	TOCURRENCY=$(printf "%s\n" "${TOCURRENCY}" | sed -E 's/([+-]?[0-9.]+)[eE]\+?(-?)([0-9]+)/(\1*10^\2\3)/g') 
	if [[ ${SCL} < 6 ]]; then
		SCL=8
		printf "%s\n" "Scale changed to 8."
	fi
fi

## Print JSON timestamp ?
if [[ -n ${TIMEST} ]]; then
	JSONTIME=$(printf "%s\n" "${CLJSON}" | jq ".timestamp")
	date -d@"$JSONTIME" "+## %FT%T%Z"
fi

## Make equation and print result
printf "define trunc(x){auto os;os=scale;for(scale=0;scale<=os;scale++)if(x==x/1){x/=1;scale=os;return x}}; scale=%s; trunc((%s*%s)/%s)\n" "${SCL}" "${1}" "${TOCURRENCY}" "${FROMCURRENCY}" | bc -lq
