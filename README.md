# abuseipdb-ipset.sh

This is a simple script to retrieve IPs listed in the AbuseIPDB database and store these in an ipset.  Firewall rules can then be added to block the IPs using these IPsets.

## Configuration

The following parameters within the script are configurable.  **All are required**
* **ipset_bin** - path to ipset binary (e.g. /sbin/ipset)
* **key** - abuseipdb API key.  See https://www.abuseipdb.com/api
* **confidence** - Minimum AbuseIPDB confidence score for blacklisted IPs
* **timeout** - Time (s) after which IP is removed from the IPset when it longer appears on the blacklist.  Default is 604800s (7 days).  This should be longer than the interval between script executions (double at least)
* **ipset_v4** - IPSet name for IPv4 addresses
* **ipset_v6** - IPSet name for IPv6 addresses