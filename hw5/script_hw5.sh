#!/usr/bin/env bash
set -e

cd "$(dirname "$0")"
remote="team@111.88.128.31"

ssh "$remote" 'mkdir -p /home/team/hw5'
scp flow.py create_table.sql "$remote:/home/team/hw5/"

ssh -tt "$remote" \
  'sudo mkdir -p /home/hadoop/hw5 &&
   sudo cp /home/team/hw5/{flow.py,create_table.sql} /home/hadoop/hw5/ &&
   sudo chown -R hadoop:hadoop /home/hadoop/hw5 &&
   sudo apt install -y python3-venv &&
   sudo -iu hadoop bash -c "cd ~/hw5 &&
     python3 -m venv venv &&
     source venv/bin/activate &&
     pip install prefect"'

output=$(ssh -tt "$remote" \
  'sudo -iu hadoop bash -c "cd ~/hw5 && source venv/bin/activate && python flow.py"')
printf '%s\n' "$output"

application_id=$(printf '%s\n' "$output" | grep -oE 'application_[0-9]+_[0-9]+' | head -n 1)
ssh -tt "$remote" "sudo -iu hadoop yarn application -status $application_id"
