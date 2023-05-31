#!/bin/sh

# Forked from benkulbertis/cloudflare-update-record.sh
# CHANGE THESE

# Global API Key (Deprecated + Dangerous)
# Note: Please be caution as the Global API key can have unlimited access to **all** domain and features in your account.
auth_email="Youruser@gmail.com"            # The email used to login 'https://dash.cloudflare.com'
auth_key="Your Global API Key"   # Top right corner, "My profile" > "Global API Key"

# API Token (Recommended)
#####                                                                             #####
# WARNING: If you put any value inside the API Token variable,                        #
#            the script will automatically use the token and omit the Global API key, #
#            regardless if the Global API key is defined or not.                      #
#####                                                                             #####
auth_token=""

# Domain and DNS record for synchronization
zone_identifier="Overview" # Can be found in the "Overview" tab of your domain
record_name="record_name"                     # Which record you want to be synced

# DO NOT CHANGE LINES BELOW

# SCRIPT START
echo "Check Initiated"

# Check for current external network IP
ip=$(curl -6k https://6.ipw.cn)
if [ ! -z "$ip" ]; then
  echo "  > Fetched current external network IP: $ip"
else
  echo "Network error, cannot fetch external network IP." >&2
  exit 1
fi

header_auth_paramheader="-H 'X-Auth-Email: $auth_email' -H 'X-Auth-Key: $auth_key'"

# Seek for the record
seek_current_dns_value_cmd="curl -s -k  -X GET 'https://api.cloudflare.com/client/v4/zones/$zone_identifier/dns_records?name=$record_name&type=AAAA' $header_auth_paramheader -H 'Content-Type: application/json'"
record=$(eval "$seek_current_dns_value_cmd")

# Set existing IP address from the fetched record
old_ip=$(echo "$record" | sed 's/.*"content":"//;s/".*//')

# Can't do anything without the record
if [ -z "$record" ]; then
  echo "Network error, cannot fetch DNS record." >&2
  exit 1
elif echo "$record" | grep -q '"count":0'; then
  echo "Record does not exist, perhaps create one first?" >&2
  exit 1
fi

# Set the record identifier from result
record_identifier=$(echo "$record" | sed 's/.*"id":"//;s/".*//')

# Compare if they're the same
if [ "$ip" = "$old_ip" ]; then
  echo "Update for AAAA record '$record_name ($record_identifier)' cancelled."
  echo "  Reason: IP has not changed."
  exit 0
else
  echo "  > Different IP addresses detected, synchronizing..."
fi

# The secret sauce for executing the update
json_data_v4="{\"id\":\"$zone_identifier\",\"type\":\"AAAA\",\"proxied\":false,\"name\":\"$record_name\",\"content\":\"$ip\",\"ttl\":120}"
update_cmd="curl -s -k -X PUT 'https://api.cloudflare.com/client/v4/zones/$zone_identifier/dns_records/$record_identifier' $header_auth_paramheader -H 'Content-Type: application/json'"

# Execution result
update=$(eval "$update_cmd --data '$json_data_v4'")

# The moment of truth
case "$update" in
*'"success":true'*)
  echo "Update for AAAA record '$record_name ($record_identifier)' succeeded."
  echo "  - Old value: $old_ip"
  echo "  + New value: $ip"
  ;;
*)
  echo "Update for AAAA record '$record_name ($record_identifier)' failed."
  echo "DUMPING RESULTS:"
  echo "$update" >&2
  exit 1
  ;;
esac
