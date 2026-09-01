#!/bin/bash

mkdir -p result_file

cd result_file

touch result.log
touch process.log

echo "This is my result file" > result.log

read -p "Enter your name: " name
read -p "Enter your roll number: " roll_no

current_date=$(date)
hostname=$(hostname)
username=$(whoami)
disk_usage=$(df -h)
processes=$(ps)

echo "===== System Information ====="

echo "Name: $name"
echo "Roll Number: $roll_no"
echo "Date: $current_date"
echo "Hostname: $hostname"
echo "Username: $username"

echo " Disk Usage "
echo "$disk_usage"

echo " Running Processes "
echo "$processes"

echo "$processes" > process.log

echo "Hi I am $name" >> result.log
echo "My roll number is $roll_no" >> result.log
echo "Today is $current_date" >> result.log