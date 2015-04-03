#!/usr/bin/env bash
set -e
shopt -s globstar nullglob

. /helpers/rsyslog.sh
link_rsyslog

#
# We need to store keys in a private location... create that location
#
__PRIVATE_KEY_DIR="/etc/opendkim/$RANDOM"
mkdir -p "${__PRIVATE_KEY_DIR}"

if [ -z "${OPENDKIM_SOCKET}" ]; then
  export OPENDKIM_SOCKET=inet:8891
fi

if [ -z "${OPENDKIM_SELECTOR}" ]; then
  export OPENDKIM_SELECTOR=mail
fi

if has_rsyslog; then
  export OPENDKIM_SYSLOG=yes
else
  export OPENDKIM_SYSLOG=no
fi

# Run the config file through the template
if [ ! -f /etc/opendkim.conf ]; then
  /usr/local/bin/mo /etc/opendkim.conf.mo > /etc/opendkim.conf
fi
rm /etc/opendkim.conf.mo

# Set the default key
if [ "${KEY}" ]; then
  export KEY__DEFAULT__="${KEY}"
fi

# If no keys are set, and the /keys directory exists, use that as KEYS_DIR
if [ -z "${!KEY_*}" ] && [ -d /keys ]; then
  export KEY_DIR=/keys
fi

# If the user specified a key directory, then look through that directory and
# add each key
if [ -n "${KEY_DIR}" ]; then
  if [ -d "${KEY_DIR}" ]; then
    i=0
    for key_file in ${KEY_DIR}/*; do
      eval "export KEY__DIR__$i=${key_file}"
      i=$(($i+1))
    done
  else
    echo "You specified a key directory (KEY_DIR=${KEY_DIR}), but that directory does not exist. Did you forget to mount it?" >&2
    exit 1
  fi

  unset KEY_DIR
fi

if [ "${1}" = "genkey" ]; then
  if [ ! -d /keys ]; then
    echo "You must mount a volume to the /keys directory to generate keys" >&2
    exit 1
  fi

  echo
  echo "Generating an OpenDKIM key"
  read -p "Domain: " domain
  read -p "Selector (mail): " selector
  read -p "Bits (1024): " bits

  if [ -z "${domain}" ]; then
    echo "You must specify a domain" >&2
    exit 1
  fi

  if [ -z "${selector}" ]; then selector=mail; fi
  if [ -z "${bits}" ]; then bits=1024; fi

  opendkim-genkey --directory=/keys --bits="${bits}" --domain="${domain}" --selector="${selector}"
  mv /keys/"${selector}.private" /keys/"${selector}._domainkey.${domain}.key"

  # extract the TXT value to print it out in one line
  echo
  echo "Create a TXT entry for \"${selector}._domainkey.${domain}\" with the value:"
  echo
  sed -e :a -e '$!N; s/\n/ /; ta' /keys/"${selector}.txt" | \
    sed -r -e 's/^[^"]+"([^"]+)"[^"]+"([^"]+)".*$/\1\2/' > /keys/"${selector}._domainkey.${domain}.txt"
  cat /keys/"${selector}._domainkey.${domain}.txt"
else
  for var in ${!KEY_*}; do
    echo "Adding key ${var}=${!var}"

    value="${!var}"
    domain=""
    selector=""
    user_pattern=""

    IFS=":" read -a fields <<< "${value}"

    # If there is only one field, infer the domain from the key name
    # if there is one field, then "fields" will not be an array
    if [ "${#fields[@]}" -eq "${#value[@]}" ]; then
      filename="${value}"
    elif [ "${#fields[@]}" -eq 2 ]; then
      # If there two fields, the first is the key path and the second is the
      # domain

      filename="${fields[0]}"
      domain="${fields[1]}"
    elif [ "${#fields[@]}" -eq 3 ]; then
      # If there three fields, the first is the key path and the second is the
      # domain and the third is the selector
      filename="${fields[0]}"
      domain="${fields[1]}"
      selector="${fields[2]}"
    elif [ "${#fields[@]}" -eq 4 ]; then
      # If there four fields, the first is the key path and the second is the
      # user_pattern, the third is the domain, and the fourth is the selector
      filename="${fields[0]}"
      domain="${fields[1]}"
      selector="${fields[2]}"
      user_pattern="${fields[3]}"
    fi

    # error out if the key doesn't exist
    if [ ! -f "${filename}" ]; then
      echo "The key file ${filename} does not exist" >&2
      exit 1
    fi

    # remove the key suffix if it's present
    key_basename="$(basename "${filename}")"
    if [[ "${key_basename}" =~ \.key$ ]]; then
      key_basename="${key_basename%.key}"
    fi

    # If the key_basename contains the selector, parse it out
    if [[ "${key_basename}" =~ ^([^.]+)\._domainkey\.(.+)$ ]]; then
      if [ -z "${selector}" ]; then
        selector="${BASH_REMATCH[1]}"
      fi

      if [ -z "${domain}" ]; then
        domain="${BASH_REMATCH[2]}"
      fi
    else
      if [ -z "${domain}" ] && [[ "${key_basename}" =~ .+\..+ ]]; then
        domain="${key_basename}"
      fi
    fi

    # Use the default selector if none is specified for this key
    if [ -z "${selector}" ]; then
      selector="${OPENDKIM_SELECTOR}"
    fi

    # If the user pattern isn't set, use this key for all users from the domain
    if [ -z "${user_pattern}" ]; then
      user_pattern="*@${domain}"
    fi

    # Raise some errors if fields are missing
    if [ -z "${domain}" ]; then
      echo "You did not specify a domain for the key ${filename} and one could not be determined from \"${value}\"" >&2
      exit 1
    fi

    if [ -z "${selector}" ]; then
      echo "You did not specify a selector for the key ${filename} and one could not be determined from \"${value}\"" >&2
      exit 1
    fi

    if [ -z "${user_pattern}" ]; then
      echo "You did not specify a signing pattern for the key ${filename} and one could not be determined from \"${value}\"" >&2
      exit 1
    fi

    # Move the private key to a secure location so that we don't get errors about the key
    # being readable and writable by other users
    filename="${filename#/}"
    mkdir -p "${__PRIVATE_KEY_DIR}/${filename}"
    cp "${filename}" "${__PRIVATE_KEY_DIR}/${filename}/key"
    filename="${__PRIVATE_KEY_DIR}/${filename}/key"

    # If we have all the fields we need, add an entry to the key and signing tables
    if [ -n "${domain}" ] && [ -n "${selector}" ] && [ -n "${user_pattern}" ]; then
      echo "${selector}._domainkey.${domain} ${domain}:${selector}:${filename}" >> /etc/opendkim/KeyTable
      echo "${user_pattern} ${selector}._domainkey.${domain}" >> /etc/opendkim/SigningTable
    fi
  done

  # Ensure the private key directory and all its contents are owned by the opendkim user/group and not readable/writable by anyone else
  chown -R opendkim:opendkim "${__PRIVATE_KEY_DIR}"
  chmod -R 600 "${__PRIVATE_KEY_DIR}"
  find "${__PRIVATE_KEY_DIR}" -type d -exec chmod +x {} \;

  exec "${@}"
fi
