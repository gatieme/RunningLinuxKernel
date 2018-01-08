#!/bin/bash

cmd=$(which tmux) # tmux path
session=codefun   # session name

if [ -z $cmd ]; then
	echo "You need to install tmux."
	exit 1
fi

$cmd has -t $session

if [ $? != 0 ]; then
	$cmd new -d -n vim -s $session "vim"
	#$cmd splitw -v -p 20 -t $session "pry"
	#$cmd neww -n mutt -t $session "mutt"
	#$cmd neww -n irssi -t $session "irssi"
	#$cmd neww -n cmus -t $session "cmus"
	#$cmd neww -n zsh -t $session "zsh"
	$cmd splitw -h -p 50 -t $session "zsh"
	$cmd selectw -t $session:1
fi

$cmd att -t $session

exit 0
