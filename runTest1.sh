#!/bin/bash

# install required packages
apt-get update -y && apt-get install -y --no-install-recommends wget ca-certificates

# prepare test input files
mkdir /tmp/testfiles
wget -O /tmp/testfiles/test_case_candidates.txt https://github.com/phnmnl/container-fingerid/raw/develop/testfiles/2500_47.4328704_175.0237_.txt


# perform test
/usr/local/bin/fingerID.r input=/tmp/testfiles/2500_47.4328704_175.0237_.txt database=all tryOffline=T output=/tmp/testfiles/output.txt

# check output
if [ ! -f /tmp/testfiles/output.txt ]; then 
   echo "Error: Output file /tmp/testfiles/output.txt not found"
   exit 1 
fi
