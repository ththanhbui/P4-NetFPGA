#!/bin/bash

# Print script commands.
# set -x
# Exit on errors.
set -e

source ~/part-ii-proj/P4-NetFPGA/tools/settings.sh

# Generate the IP cores
cd $SUME_FOLDER && make

# 4. Run the P4-SDNet compiler to generate the resulting HDL and an initial simulation framework
cd $P4_PROJECT_DIR && make

# 5. Run the SDNet simulation
cd $P4_PROJECT_DIR/nf_sume_sdnet_ip/SimpleSumeSwitch
./vivado_sim.bash

cd $SUME_FOLDER && make

# 6. Generate the scripts that can be used in the NetFPGA SUME simulations to configure the table entries.
cd $P4_PROJECT_DIR && make config_writes

# 7. Wrap SDNet output in wrapper module and install as a SUME library core:
cd $P4_PROJECT_DIR
make uninstall_sdnet && make install_sdnet

# 8. Set up the SUME simulation. 
cd $NF_DESIGN_DIR/test/sim_switch_default && make

# 9. Run the SUME simulation:
cd $SUME_FOLDER
./tools/scripts/nf_test.py sim --major switch --minor default