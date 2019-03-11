#!/bin/bash

# Print script commands.
# set -x
# Exit on errors.
set -e

source ~/part-ii-proj/P4-NetFPGA/tools/settings.sh

# 4. Run the P4-SDNet compiler to generate the resulting HDL and an initial simulation framework
cd $P4_PROJECT_DIR && make

# 5. Run the SDNet simulation
cd $P4_PROJECT_DIR/nf_sume_sdnet_ip/SimpleSumeSwitch
./vivado_sim.bash