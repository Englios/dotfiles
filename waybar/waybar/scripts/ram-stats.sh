#!/bin/bash

# RAM usage
total=$(free -g | awk '/^Mem:/ {print $2}')
used=$(free -g | awk '/^Mem:/ {print $3}')
echo "${used}GB / ${total}GB"
