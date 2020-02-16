#!/bin/bash
# v0.2.44  feb/2020

#if you have got a BlockChair api key for higher limit:
#CHAIRKEY="?key=MYSECRETKEY"

# DEFAULTS
# Pay attention to rate limits
#time between new queries
SLEEPTIME=10

#log file
RECFILE="${HOME}/addresses.log"

#curl/wget timeout to estabilish connection
TIMEOUT=20

# Help -- run with -h
HELP="SYNOPSIS

	${0} [-abcdghv] [-sNUM] [-o\"FILE_PATH\"]


	This script uses Vanitygen to generate an address and its private key.
	It then checks for at least one received transaction at the public ad-
	dress. If a transaction is detected, even if the balance is currently 
	zero (current balance is not checked), a copy of the generated private 
	key and its public address will be printed in the screen and logged 
	to ${RECFILE}.
	You can change the log base name and path with option \"-o\".

	The fastest way of brute forcing a bitcoin address collision is to have 
	your own full-node set up. However, that may not be feasible size-wise.
	Also, it may be easier to use internet APIs than to learn how to build 
	a full-node.

	Defaults to Blockchain.info API, but you can choose which servers to 
	query. Beware of rate limits for each server!

	Required packages are: Bash, cURL or Wget, Tee and Vanitygen (OpenSSL 
	and Pcre are required dependencies of Vanitygen).


COLLISION PROBABILITIES

	How to find a collision (ref 1)

		try 2^130 randomly chosen inputs
		99.8% chance that two of them will collide
	

	Number Of Unique Addresses Used (ref 2)
	
		456,579 (2019/10/17)


	If you find a wallet with balance, send the owner the smallest signal 
	that wallet security was breached. Also, unless it is one of Satoshi 
	addresses, you ought not to keep the bitcoins.


	A nice page about cryptographic hash functions is (3). Check those jokes!


	References:
		(1) <youtube.com/watch?v=fOMVZXLjKYo>
		(2) <blockchain.com/en/charts/n-unique-addresses>
		(3) <valerieaurora.org/hash.html>


RATE LIMITS
	Blockchain.info, from Twitter 2013:
	
	\"Developers: API request limits increased to 28,000 requests per 8 hour
	period and 600 requests per 5 minute period.\"


	Blockchair.com API docs and message from server:
	
	\"Since the introduction of our API more than two years ago it has been
	free to use in both non-commercial and commercial cases with a limit of 
	30 requests per minute.\"

	\"Code 402: Current limits are 30 requests per minute and 1800 per hour.\"

	\"Limit of 1440 queries per day.\"


	BTC.com API docs:
	
	\"Developer accounts are limited to 432,000 API requests per 24 hours, 
	at a rate of 300 request per minute. When you reach the rate limit you 
	will get an error response with the 429 status code. We will send you a
	notification when you're getting close to the rate limit, so you can up-
	grade in time or contact us to request an extension. If you don't back-
	off when 429 responses are being returned you can get banned.\"


	Blockcypher.com API docs:
	
	\"Classic requests, up to 3 requests/sec and 200 requests/hr.\"


	Error 429 may not be a problem. Perhaps error 430 is.


WARRANTY
	Licensed under the GNU Public License v3 or better.
 	This programme is distributed without support or bug corrections.


USAGE EXAMPLES
	(1) Use defaults, sleep time between queries is nought and check
	    response from server.

		$ searchbtc.sh -s0 -g


	(2) Use BTC.com and Blockchain.info APIs and sleep 20 seconds
	    between queries:
		
		$ searchbtc.sh -ab -s20


	(3) Use all servers, default sleep time:

		$ searchbtc.sh -abcd


OPTIONS
	-a 		Use BTC.com API.
	
	-b 		Use Blockchain.info APIs; defaults if no server opt is
			given.

	-c 		Use Blockchair.com API.
	
	-d 		Use Blocypher.com API.

	-h 		Show this help.

	-o [FILE_PATH] 	File path to record positive match results; 
			defaults=\"${RECFILE}\"

	-s [NUM] 	Sleep time (seconds) between new queries; value of zero
			is possible, although api servers may block you quickly;
			defaults=${SLEEPTIME}.

	-v 		Verbose, log all addresses tested to file and print 
			debug messages on screen to stderr.

	-V 		Print script version."

#functions

#Which function
whichf() {
	[[ "${PASS}" = 1 ]] && printf "Blockchain.info\n" 
	[[ "${PASS}" = 2 ]] && printf "Blockchair.com\n"
	[[ "${PASS}" = 3 ]] && printf "BTC.com\n"
	[[ "${PASS}" = 4 ]] && printf "Blockcypher.com\n"
	#test "${PASS}" = "" && printf " "
}

#Functions
PASS=0
queryf() {
	# Choose resquest server
	if [[ -n "${BINFOOPT}" ]] && [[ "${PASS}" -eq "0" ]] ; then
		# Binfo.com
		QUERY="$(${MYAPP} "https://blockchain.info/balance?active=$address")"
		PASS=1
	elif [[ -n "${CHAIROPT}" ]] && [[ "${PASS}" -le "1" ]]; then
		# Blockchair.com
		QUERY="$(${MYAPP} "https://api.blockchair.com/bitcoin/dashboards/address/${address}${CHAIRKEY}")"
		PASS=2
	elif [[ -n "${BTCOPT}" ]] && [[ "${PASS}" -le "2" ]]; then
		# BTC.com
		# OBS : BTC.com returns null if no tx in address
		QUERY="$(${MYAPP} "https://chain.api.btc.com/v3/address/${address}")"
		PASS=3
	elif [[ -n "${CYPHEROPT}" ]] && [[ "${PASS}" -le "3" ]]; then
		#Blockcypher.com
		QUERY="$(${MYAPP} "https://api.blockcypher.com/v1/btc/main/addrs/${address}/balance")"
		PASS=4
	else
		PASS=0
		queryf
	fi
}

#Get RECEIVED TOTAL (not really balance)
SA=1
getbal() {
	# Test for rate limit error
	if grep -i -e "Please try again shortly" -e "Quota exceeded" -e "Servlet Limit" -e "rate limit" -e "exceeded" -e "limited" -e "not found" -e "429 Too Many Requests" -e "Error 402" -e "Error 429" -e "too many requests" -e "banned" -e "Maximum concurrent requests" -e "Please try again shor" -e 'Internal Server Error' -e "\"error\":" -e "upgrade your plan" -e "extend your limits" <<< "${QUERY}" 1>&2; then
		printf "\nLimit warning or error: %s\n" "$(whichf)" 1>&2
		printf "Skipped: %s\n" "${SA}" 1>&2
		#Debug Verbose
		if [[ -n "${DEBUG}" ]]; then
			printf "Addr: %s\n" "${address}" 1>&2
			printf "Processing: PASS %s\n" "${PASS}" 1>&2
			date 1>&2
			printf "%s\n" "${QUERY}" 1>&2
		fi
		
		#continue...
	elif grep -i -e "Invalid API token" -e "invalid api" -e "wrong api" -e "wrong key" <<< "${QUERY}" 1>&2; then
		printf "Invalid API token?\n" 1>&2
		exit 1
	fi

	# Choose processing between 
	if [[ "${PASS}" -eq "1" ]]; then
		# Binfo.com
		jq -er '.[].total_received' <<< "${QUERY}" 2>/dev/null || return 1
	elif [[ "${PASS}" -eq "2" ]]; then
		# Blockchair.com
		jq -er '.data[].address.received' <<< "${QUERY}" 2>/dev/null || return 1
	elif [[ "${PASS}" -eq "3" ]]; then
		# BTC.com
		# OBS : BTC.com returns null if no tx in address
		# Option -e deactivated
		jq -r '.data.received' <<< "${QUERY}" 2>/dev/null || return 1
	elif [[ "${PASS}" -eq "4" ]]; then
		#Blockcypher.com
		jq -er '.total_received' <<< "${QUERY}" 2>/dev/null || return 1
	fi
}

#parse opt

# Parse options
while getopts ":cbadghs:vVo:" opt; do
	case ${opt} in
		a ) # Use BTC.com
			BTCOPT=1
			;;
		b ) # Use Blockchain.info
			BINFOOPT=1
			;;
		c ) # Use Blockchair.com
			CHAIROPT=1
			;;
		d ) # Use Blockcypher.com
			CYPHEROPT=1
			;;
		h ) # Help
			head "${0}" | grep -e '# v'
			printf '%s\n' "${HELP}"
			exit 0
			;;
		o ) # Record file path
			RECFILE="${OPTARG}"
			;;
		V ) # Version of Script
			head "${0}" | grep -e '# v'
			exit 0
			;;
		s ) # Sleep time
			SLEEPTIME="${OPTARG}"
			;;
		v|g ) # verbose and debug
			DEBUG=1
			;;
		\? )
			printf 'Invalid option: -%s\n' "${OPTARG}" 1>&2
			exit 1
			;;
	 esac
done
shift $((OPTIND -1))

# Use only Blockchain.com by defaults
if [[ -z "${BTCOPT}${BINFOOPT}${CHAIROPT}${CYPHEROPT}" ]]; then
	BINFOOPT=1
fi

# Must have vanitygen
if ! command -v vanitygen >/dev/null; then
	printf "Vanitygen is required.\n" 1>&2
	exit 1
fi
# Must have cURL or Wget
if command -v curl >/dev/null; then
	MYAPP="curl -sLb non-existing --retry 1 --connect-timeout ${TIMEOUT}"
elif command -v wget >dev/null; then
	MYAPP="wget  -t1 -T${TIMEOUT} -qO-"
else
	printf "cURL or Wget is required.\n" 1>&2
	exit 1
fi
if ! command -v jq >/dev/null; then
	printf "JQ is required.\n" 1>&2
	exit 1
fi

# Heading
date 
# Loop
# Start count
while :; do
	#addr counter
	((N++))

	#status
	printf "\rAddrs: %07d" "${N}" 1>&2
	
	#generate one addr
	VANITY="$(vanitygen -q 1)"

	#verbose, debug opt logfile
	[[ -n "${DEBUG}" ]] && printf '%s\n' "${VANITY}" | sed  -Ee 's/(\r|\t|\s)//g' -e '/^Pattern/d' -e 's/^Privkey://' -e 's/^Address://' >> "${RECFILE}.all"

	#get address and query for received amount from api
	address="$(grep -e "Address:" <<< "${VANITY}" | cut -d' ' -f2)"
	queryf
	
	# If JQ detects an error, skip address and sleep
	if ! REC="$(getbal)" >/dev/null; then
		((SA++))
		sleep 300
		continue
	fi

	# Get received amount for further processing
	if [[ -n "${REC}" ]] && [[ "${REC}" != "0" ]] && [[ ! "${REC}" =~ null ]] ; then
		{ date
		  printf 'Check this address\n'
		  printf "%s\n" "${VANITY}" | sed  -Ee 's/(\r|\t|\s)//g' -e '/^Pattern/d'
		  printf "Received? %s\n" "${REC}"
		  printf "Addrs checked: %s\n" "${N}"
		  printf 'PASS %s\n' "${PASS}"
		} | tee -a "${RECFILE}" "${RECFILE}.all"
	fi

	#wait a little for next loop iteration
	sleep "${SLEEPTIME}"
done

#Dead code

