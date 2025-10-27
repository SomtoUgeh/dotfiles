#!/bin/bash

# Script to enable Touch ID for sudo commands on macOS

echo "This script will enable Touch ID for sudo commands"
echo "You'll need to enter your password once"

# Copy the template file to create sudo_local
sudo cp /etc/pam.d/sudo_local.template /etc/pam.d/sudo_local

# Uncomment the Touch ID line
sudo sed -i '' 's/^#auth       sufficient     pam_tid.so/auth       sufficient     pam_tid.so/' /etc/pam.d/sudo_local

echo "Touch ID for sudo has been enabled!"
echo "Try running 'sudo ls' to test it"