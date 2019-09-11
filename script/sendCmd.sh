#!/usr/bin/env bash

##########################
#interface setup commands
########################## 
#sudo ip link set can0 type can bitrate 500000
#sudo ip link set up can0
#sudo ip link add dev vcan0 type vcan
#sudo ip link set up vcan0

#############################
# test env variables
#############################
IF="vcan0"       # default interface
#TIME_INT="0.01"  # time interval for sending packets
TIME_INT="0.01"  # time interval for sending packets
PACKET_INT="10"   # $PACKET_INT packets need to be sent for increasement

#############################
# cmd specific default byte 
#############################
b3_brake="00"
b1_acc="00" #observed min: 0x00,  max 0x2b
b6_acc="00" #sync with b1_acc
b7_acc="14" #observed idle (P mode) value 0x14, 0x15
let inc_acc_b2=0  #accumulator for incremental value

# $1 - interface: can0/vcan0
# $2 - AID
# $3 - Data
function sendSingleCmd(){
  cansend $1 $2#$3
  echo "cansend $1 $2#$3"
}

#$1 - cmd
#$@ - 
function sendCmd(){
  echo "send cmd argument(s): $@"
  if [ $1 = 'can0' ]; then
      IF=$1;
  fi
  cmd=$2
  shift 2;
  while true; do
    if [ "$cmd" = 'ACC' ]; then
        cmdAccelerate $@
    elif [ "$cmd" = 'acc' ]; then
        cmdAccelerate $@
    elif [ "$cmd" = 'BRK' ]; then
        cmdBrake $@
    elif [ "$cmd" = 'brk' ]; then
        cmdBrake $@
    else
      echo "else"
    fi
    sleep $TIME_INT
  done
}

# $1 - expected b1 b6
# cmd "sendCmd.sh vcan0 acc 11" - need manually transfer 0b -> 11
function cmdAccelerate(){
  # init
  b1="00" # 00
  b2="00" # keep looping from 00~0F 
  b3="00" # ?
  b4="40" #?
  b5="00"
  b6=$b1  # sync with b1
  b7="0c" # 14
  b8="00" # 00 or 01
  b1_target=$1  # target hex value
  b1_target_dec=$(bc<<<"obase=10; ibase=16; $b1_target")
#  b7_vAcc=$2  # target hex value
#  b7_vAcc_dec=$(bc<<<"obase=10; ibase=16; $b7_vAcc")
  #  if [ $b1_acc = $b1_vAcc ] && [ $b7_acc = $b7_vAcc ]; then
  if [ $b1_acc = $b1_target ]; then
      data="$b1_acc$b2$b3$b4$b5$b1_acc$b7_acc$b8"
      sendSingleCmd $IF 140 $data
  else
    for ((b=0; b<=$b1_target_dec; b++)){
       b1_acc=$(printf "%02x" $b)
       #echo "b1_acc => $b1_acc"   
       for((j=0; j< $PACKET_INT; j++,inc_acc_b2++)){
            if (( inc_acc_b2 >= 16 )); then
                let inc_acc_b2=0;
            fi
            b2=$(printf "%02x" $inc_acc_b2)
            data="$b1_acc$b2$b3$b4$b5$b1_acc$b7$b8"
            sleep $TIME_INT
            sendSingleCmd $IF 140 $data
       }
    }
  fi   
}

# $1 - target brake value captured maximum value: 0x22
function cmdBrake(){
  b1="00"
  b2="00"
  b3="00" # observed maximum value: 0x22 34d
  b4="00"
  vBrake=$1  # target hex value
  vBrake_dec=$(bc<<<"obase=10; ibase=16; $1")
  
  if [ $b3_brake = $vBrake ]; then
      data="$b1$b2$b3_brake$b4"
      sendSingleCmd $IF 0d1 $data
  else
    for ((b=0; b<=$vBrake_dec; b++)){
        b3_brake=$(printf "%02x" $b)
        data="$b1$b2$b3_brake$b4"
        for((i=0; i < $PACKET_INT; i++)){
             sleep $TIME_INT
             sendSingleCmd $IF 0d1 $data
        }
    }
  fi
}

sendCmd $@
