#!/bin/bash

# Print script commands.
# set -x
# Exit on errors.
set -e

source ~/home/ico/Projects/part-ii-proj/P4-NetFPGA/tools/settings.sh

cd $P4_PROJECT_DIR && make

cd $P4_PROJECT_DIR/nf_sume_sdnet_ip/SimpleSumeSwitch

./vivado_sim.bash

cd $P4_PROJECT_DIR