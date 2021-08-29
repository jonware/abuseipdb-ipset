#!/bin/bash
# Script for blocking IPs which are listed on the AbuseIPDB blacklist
#   via ipsets.
#
# - THIS SCRIPT DOES NOT BLOCK ANYTHING -
# This script only updates ipsets with applicable data from
# abuseipdb.com. Actually blocking the ips in that ipset is left
# up to the user (so that you may do so however you prefer).
#
# Additionally, this script does not persist the ipsets through
# a restart. This is because most distros now provide a method of
# doing so and any attempt to do so in this script would create
# redundant/conflicting functionality.
#
# Exit Codes:
#   0 - success
#   1 - failure - no changes made
#   2 - failure - possible changes made, inconsistent state
#
# Loosely based on badips-ipset.sh by Jeremy Cliff Armstrong:
# https://gist.github.com/JadedDragoon/a516eb778b4b33b6b4decd1b15f9a26a
#
#===============================================================================
# MIT License
#
# Original work Copyright (c) 2020 Jeremy Cliff Armstrong
# Modifications Copyright (c) 2021 Jonathan Ware
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.
#===============================================================================
 
# Location of ipset binary
ipset_bin=/sbin/ipset

# API key for AbuseIPDB.com
key=

# Minimum Confidence Level (%)
confidence=90

# This is how long (in seconds) an ip will remain in the ipset after it
#   stops showing up in the AbuseIPDB blacklist. It should be longer than
#   the time between executions of this script (double, at least) and long
#   enough when combined with age above that occasional offenders don't get
#   removed from the ipset prematurely.
#
# IMPORTANT: this script should be executed more often than this setting.
# NOTE: IPs returned by AbuseIPDB which are already in the ipset will
#   have their timeouts reset to this value (if it is greater than the
#   existing timeout)
timeout=604800      # REQUIRED! - default is 7 days

# Name of ipset to use
ipset_v4=abuseipdb_v4        # REQUIRED!
ipset_v6=abuseipdb_v6

##################
## BEGIN SCRIPT ##
##################

# required parameters
if [[ ! ${ipset_v4} || ! ${ipset_v6} || ! ${timeout} || ! ${ipset_bin} || ! ${key} || ! ${confidence} ]]
then
    echo "$0: Required parameter is missing! Edit this file for further info." >&2
    exit 1
fi



### Query abuseipdb.com
# Get the blacklist and store in an array
_blacklist=( $(curl -sS -G https://api.abuseipdb.com/api/v2/blacklist \
  -d confidenceMinimum=$confidence \
  -d plaintext \
  -H "Key: $key" \
  -H "Accept: application/json") )  || { echo "$0: Unable to download blacklist." >&2; exit 1; }


### Setup our ipsets, creating them if they don't exist ###
if ! ${ipset_bin} list ${ipset_v4} -name 2>/dev/null >/dev/null
then
    ${ipset_bin} create ${ipset_v4} hash:ip timeout ${timeout} -exist || { echo "$0: Unable to create ipset: ${ipset_v4}" >&2; exit 2; }
fi

if ! ${ipset_bin} list ${ipset_v6} -name 2>/dev/null >/dev/null
then
    ${ipset_bin} create ${ipset_v6} hash:ip family inet6 timeout ${timeout} -exist || { echo "$0: Unable to create ipset: ${ipset_v6}" >&2; exit 2; }
fi


# Add all retrieved ips to $_ipset, updating the timeout on duplicates
for _ip in "${_blacklist[@]}"
do
    if [ "$_ip" != "${_ip#*[0-9].[0-9]}" ]; then
        # add/update IPv4 ipset
        ${ipset_bin} add ${ipset_v4} "${_ip}" timeout ${timeout} -exist || { echo "$0: Unable to add ${_ip} to ${ipset_v4}, exiting early." >&2; exit 2; }
        
    elif [ "$_ip" != "${1#*:[0-9a-fA-F]}" ]; then
        # add/update IPv6 ipset
        ${ipset_bin} add ${ipset_v6} "${_ip}" timeout ${timeout} -exist || { echo "$0: Unable to add ${_ip} to ${ipset_v6}, exiting early." >&2; exit 2; }
    else
        echo "Unrecognised IP format '$_ip'"
    fi
done

exit 0
