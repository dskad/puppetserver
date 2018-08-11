#!/bin/bash
set -eo pipefail

usage () {
cat << EOF
Usage:
 $0 [options]

Options
 -n, --new-key                Generate new ssh keypair
 -k, --key-dir <directory>    Custom output directory (default: /etc/puppetlabs/ssh)
 -c, --key-comment <comment>  Add custom comment to generated key  (default user@host)
 -f, --force                  Overwrite existing keys
 -p, --print-pub-key          Print public key of generated keypair
 -h, --help                   Show usage information

$0 will not overwrite existing keys. To regenerate a new key pair, delete the original keys first
EOF
exit 0
}

OPTS=`getopt --options nk:c:fph --longoptions new-key,key-dir:,key-comments:,force,print-pub-key,help -n 'options' -- "$@"`
eval set -- "$OPTS"

NEW_KEY=false
KEY_DIR="/etc/puppetlabs/ssh"
FORCE=false
PRINT_PUB_KEY=false
HELP=false
if [[ $# -eq 0 ]]; then HELP=true; fi

while true; do
  case "$1" in
    -n|--new-key)
      NEW_KEY=true
      shift ;;
    -k|--key-dir)
      KEY_DIR="$2"
      shift 2 ;;
    -c|--key-comment)
      KEY_COMMENT="$2"
      shift 2 ;;
    -f|--force)
      FORCE=true
      shift ;;
    -p|--print-pub-key)
      PRINT_PUB_KEY=true
      shift ;;
    -h|--help)
      HELP=true
      shift ;;
    --) shift ; break ;;
    *) break ;;
  esac
done

if [[ $HELP = "true" ]]; then
  usage
  exit
fi

if [[ $FORCE = "true" ]]; then
  rm -f $KEY_DIR/{id_rsa,id_rsa.pup}
fi

if [[ $NEW_KEY = true ]]; then
  if [[ ! -f $KEY_DIR/id_rsa ]]; then
    mkdir -p $KEY_DIR
    ssh-keygen -b 4096 -f $KEY_DIR/id_rsa -t rsa -N "" ${KEY_COMMENT:+-C} $KEY_COMMENT
  else
    echo "${KEY_DIR}/id_rsa already exists"
  fi
fi

if [[ $PRINT_PUB_KEY = "true" ]]; then
  cat $KEY_DIR/id_rsa.pub
fi

