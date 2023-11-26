check_command() {
  if ! command -v $1 &> /dev/null; then
    echo "$1 not installed, please install: $1"
  fi
}

check_command kubectl
check_command helm
check_command eksctl
