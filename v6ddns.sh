#!/bin/bash
#
# This is a Bash script to update a Netlify subdomain A record with the current external IP.
#
# Source Repo: https://github.com/skylerwlewis/netlify-ddns
#	This Repo:	https://github.com/woshichenghaibo/Netlify-DDNS
# Gist: https://gist.github.com/skylerwlewis/ba052db5fe26424255674931d43fc030
#
# Usage:
# v6ddns.sh <ACCESS_TOKEN> <DOMAIN> <SUBDOMAIN> <TTL> [<CACHED_IP_FILE>]
#
# The example below would update the local.example.com A record to the current external IP with a TTL of 5 minutes.
# The last parameter for the script is optional and is used to cache the Netlify IP to reduce API calls.
#
# Example:
# bash /root/v6ddns.sh nfp_MYRPpKEvWKQiHopTBCuhajUert8mfBKD06f7 def.com abc 3600 /root/v6-ip-file.txt
#
if [ "$#" -lt 4 ] || [ "$#" -gt 5 ]; then
  echo "Wrong number of parameters passed"
  echo "Usage:"
  echo "$0 <ACCESS_TOKEN> <DOMAIN> <SUBDOMAIN> <TTL> [<CACHED_IP_FILE>]"
  exit
fi

ACCESS_TOKEN="$1"
DOMAIN="$2"
SUBDOMAIN="$3"
TTL="$4"

if [ "$#" -ge 5 ]; then
  CACHED_IP_FILE="$5"
fi

NETLIFY_API="https://api.netlify.com/api/v1"
IP_PATTERN="([0-9a-fA-F]{1,4}:){7}[0-9a-fA-F]{1,4}"
EXTERNAL_IP=$(curl -s 6.ipw.cn)
echo "$EXTERNAL_IP"
if [[ ! $EXTERNAL_IP =~ $IP_PATTERN ]]; then
  echo "There was a problem resolving the external IP, response was \"$EXTERNAL_IP\""
  exit
fi

if [ -n "$CACHED_IP_FILE" ]; then 
  if [[ -f "$CACHED_IP_FILE" ]]; then
    if [[ $(< "$CACHED_IP_FILE") = "$EXTERNAL_IP" ]]; then
      exit
    fi
  fi
fi

DNS_ZONES_RESPONSE=`curl -s -w "\n%{http_code}" "$NETLIFY_API/dns_zones?access_token=$ACCESS_TOKEN" --header "Content-Type:application/json"`
DNS_ZONES_RESPONSE_CODE=$(tail -n1 <<< "$DNS_ZONES_RESPONSE")
DNS_ZONES_CONTENT=$(sed '$ d' <<< "$DNS_ZONES_RESPONSE")
if [[ $DNS_ZONES_RESPONSE_CODE != 200 ]]; then
  echo "There was a problem retrieving the DNS zones, response code was $DNS_ZONES_RESPONSE_CODE, response body was:"
  echo "$DNS_ZONES_CONTENT"
  exit
fi

ZONE_ID=`echo $DNS_ZONES_CONTENT | jq ".[]  | select(.name == \"$DOMAIN\") | .id" --raw-output`

DNS_RECORDS_RESPONSE=`curl -s -w "\n%{http_code}" "$NETLIFY_API/dns_zones/$ZONE_ID/dns_records?access_token=$ACCESS_TOKEN" --header "Content-Type:application/json"`
DNS_RECORDS_RESPONSE_CODE=$(tail -n1 <<< "$DNS_RECORDS_RESPONSE")
DNS_RECORDS_CONTENT=$(sed '$ d' <<< "$DNS_RECORDS_RESPONSE")
if [[ $DNS_RECORDS_RESPONSE_CODE != 200 ]]; then
  echo "There was a problem retrieving the DNS records for zone \"$ZONE_ID\", response code was $DNS_RECORDS_RESPONSE_CODE, response body was:"
  echo "$DNS_RECORDS_CONTENT"
  exit
fi

HOSTNAME="$SUBDOMAIN.$DOMAIN"
RECORD=`echo $DNS_RECORDS_CONTENT | jq ".[]  | select(.hostname == \"$HOSTNAME\")" --raw-output`
RECORD_VALUE=`echo $RECORD | jq ".value" --raw-output`

if [ -n "$CACHED_IP_FILE" ]; then 
  echo "$RECORD_VALUE" > "$CACHED_IP_FILE"
fi

if [[ "$RECORD_VALUE" != "$EXTERNAL_IP" ]]; then

  echo "Current external IP is $EXTERNAL_IP, current $HOSTNAME value is $RECORD_VALUE"

  if [[ $RECORD_VALUE =~ $IP_PATTERN ]]; then
    echo "Deleting current entry for $HOSTNAME"
    RECORD_ID=`echo $RECORD | jq ".id" --raw-output`
    DELETE_RESPONSE_CODE=`curl -X DELETE -s -w "%{http_code}" "$NETLIFY_API/dns_zones/$ZONE_ID/dns_records/$RECORD_ID?access_token=$ACCESS_TOKEN" --header "Content-Type:application/json"`

    if [[ $DELETE_RESPONSE_CODE != 204 ]]; then
      echo "There was a problem deleting the existing $HOSTNAME entry, response code was $DELETE_RESPONSE_CODE"
      exit
    fi
  fi

  echo "Creating new entry for $HOSTNAME with value $EXTERNAL_IP"
  CREATE_BODY=`jq -n --arg hostname "$HOSTNAME" --arg externalIp "$EXTERNAL_IP" --arg ttl $TTL '
  {
      "type": "AAAA",
      "hostname": $hostname,
      "value": $externalIp,
      "ttl": $ttl|tonumber
  }'`

  CREATE_RESPONSE=`curl -s -w "\n%{http_code}" --data "$CREATE_BODY" "$NETLIFY_API/dns_zones/$ZONE_ID/dns_records?access_token=$ACCESS_TOKEN" --header "Content-Type:application/json"`
  CREATE_RESPONSE_CODE=$(tail -n1 <<< "$CREATE_RESPONSE")
  CREATE_CONTENT=$(sed '$ d' <<< "$CREATE_RESPONSE")
  if [[ $CREATE_RESPONSE_CODE != 201 ]]; then
    echo "There was a problem creating the new entry, response code was $CREATE_RESPONSE_CODE, response body was:"
    echo "$CREATE_CONTENT"
    exit
  fi
fi
