# Netlify-DDNS
This is a Bash script to update a Netlify subdomain A or AAAA record with the current external IP.A simple dynamic DNS script that integrates with Netlify via their provided API.
# Usage
v4ddns.sh ACCESS_TOKEN DOMAIN SUBDOMAIN TTL [CACHED_IP_FILE]

or

v6ddns.sh ACCESS_TOKEN DOMAIN SUBDOMAIN TTL [CACHED_IP_FILE]
# Example
The example below would update the local.example.com A record to the current external IP with a TTL of 5 minutes. The last parameter for the script is optional and is used to cache the Netlify IP to reduce API calls. netlify-ddns.sh aCcEsStOKeN example.com local 3600 /home/johnsmith/cached-ip-file.txt

# Prerequisites
curl

bash

jq
# Related
I would like to express my gratitude to @skylerwlewis here

skylerwlewis/netlify-ddns  @   https://github.com/skylerwlewis/netlify-ddns
