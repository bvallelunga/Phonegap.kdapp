#!/bin/bash
OUT="/tmp/_Phonegapinstaller.out/$1"
mkdir -p $OUT

#Gains sudo access so the password isn't asked multiple times
touch $OUT/"20-Asking for sudo password"
sudo echo "Starting Installer"

#Install Node
if [ ! -d "/usr/bin/node" ]; then
  touch $OUT/"40-Installing Node.js"
  sudo apt-add-repository -y ppa:chris-lea/node.js > /dev/null
  sudo apt-get update > /dev/null
  sudo apt-get install -y nodejs > /dev/null
fi

#Install Phonegap
touch $OUT/"60-Asking for sudo password"
sudo npm install -g phonegap --silent

#Create PhoneGap folder
mkdir -p ~/PhoneGap

#Check If Demo Project Exists
if [ ! -d "~/PhoneGap/hello" ]; then

  #Create Demo Project
  touch $OUT/"80-Creating PhoneGap Project"
  /usr/bin/phonegap create ~/PhoneGap/hello com.$2.hello HelloWorld

fi

#Finished Install
touch $OUT/"100-PhoneGap installation completed."