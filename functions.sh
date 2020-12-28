#!/bin/bash

convertsecs2hms() {
 ((h=${1}/3600))
 ((m=(${1}%3600)/60))
 ((s=${1}%60))
 # printf "%02d:%02d:%02d\n" $h $m $s
 # PRETTY OUTPUT: uncomment below printf and comment out above printf if you want prettier output
 printf "%02dh %02dm %02ds\n" $h $m $s
}
