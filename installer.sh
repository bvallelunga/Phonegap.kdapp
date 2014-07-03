#!/bin/bash
OUT="/tmp/_Phonegapinstaller.out/$1"
mkdir -p $OUT
touch $OUT/"0-Starting Install"

#Install Node
if [ ! -d "/usr/bin/node" ]; then
  touch $OUT/"30-Installing Node.js"
  apt-add-repository -y ppa:chris-lea/node.js > /dev/null
  apt-get update > /dev/null
  apt-get install -y nodejs > /dev/null
fi

#Install Phonegap
touch $OUT/"60-Installing PhoneGap CLI"
npm install -g phonegap --silent

#Create PhoneGap folder
mkdir -p ~/PhoneGap

#Check If Demo Project Exists
if [ ! -d "~/PhoneGap/hello" ]; then

  #Create Demo Project
  touch $OUT/"90-Creating PhoneGap Project"
  /usr/bin/phonegap create ~/PhoneGap/hello com.$2.hello HelloWorld

fi

#Finished Install
touch $OUT/"100-PhoneGap installation completed."