#
# Copyright (c) 2017 Stephen Ibanez
# All rights reserved.
#
# This software was developed by Stanford University and the University of Cambridge Computer Laboratory 
# under National Science Foundation under Grant No. CNS-0855268,
# the University of Cambridge Computer Laboratory under EPSRC INTERNET Project EP/H040536/1 and
# by the University of Cambridge Computer Laboratory under DARPA/AFRL contract FA8750-11-C-0249 ("MRC2"), 
# as part of the DARPA MRC research programme.
#
# @NETFPGA_LICENSE_HEADER_START@
#
# Licensed to NetFPGA C.I.C. (NetFPGA) under one or more contributor
# license agreements.  See the NOTICE file distributed with this work for
# additional information regarding copyright ownership.  NetFPGA licenses this
# file to you under the NetFPGA Hardware-Software License, Version 1.0 (the
# "License"); you may not use this file except in compliance with the
# License.  You may obtain a copy of the License at:
#
#   http://www.netfpga-cic.org
#
# Unless required by applicable law or agreed to in writing, Work distributed
# under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
# CONDITIONS OF ANY KIND, either express or implied.  See the License for the
# specific language governing permissions and limitations under the License.
#
# @NETFPGA_LICENSE_HEADER_END@
#


extern_data = {
"reg_rw" : {"hdl_template_file": "externs/reg_rw/hdl/EXTERN_reg_rw_template.v",
            "cpp_template_file": "externs/reg_rw/cpp/EXTERN_reg_rw_template.hpp",
            "replacements": {"@EXTERN_NAME@" : "extern_name",
                             "@MODULE_NAME@" : "module_name",
                             "@PREFIX_NAME@" : "prefix_name",
                             "@ADDR_WIDTH@" : "addr_width",
#                             "@NUM_CYCLES@" : "max_cycles",
                             "@INDEX_WIDTH@" : "input_width(index)",
                             "@REG_WIDTH@" : "input_width(newVal)"}
},

"reg_raw" : {"template_file": "externs/EXTERN_reg_raw_template.v",
             "replacements": {"@EXTERN_NAME@" : "extern_name",
                              "@MODULE_NAME@" : "module_name",
                              "@PREFIX_NAME@" : "prefix_name",
                              "@ADDR_WIDTH@" : "addr_width",
#                              "@NUM_CYCLES@" : "max_cycles",
                              "@INDEX_WIDTH@" : "input_width(index)",
                              "@REG_WIDTH@" : "input_width(newVal)"}
},

"reg_praw": {"template_file": "externs/EXTERN_reg_praw_template.v",
             "replacements": {"@EXTERN_NAME@" : "extern_name",
                              "@MODULE_NAME@" : "module_name",
                              "@PREFIX_NAME@" : "prefix_name",
                              "@ADDR_WIDTH@" : "addr_width",
#                              "@NUM_CYCLES@" : "max_cycles",
                              "@INDEX_WIDTH@" : "input_width(index)",
                              "@REG_WIDTH@" : "input_width(newVal)"}
},

"reg_ifElseRaw": {"template_file": "externs/EXTERN_reg_ifElseRaw_template.v",
                  "replacements": {"@EXTERN_NAME@" : "extern_name",
                                   "@MODULE_NAME@" : "module_name",
                                   "@PREFIX_NAME@" : "prefix_name",
                                   "@ADDR_WIDTH@" : "addr_width",
#                                   "@NUM_CYCLES@" : "max_cycles",
                                   "@INDEX_WIDTH@" : "input_width(index_1)",
                                   "@REG_WIDTH@" : "output_width(result)"}
},

"reg_sub": {"template_file": "externs/EXTERN_reg_sub_template.v",
            "replacements": {"@EXTERN_NAME@" : "extern_name",
                             "@MODULE_NAME@" : "module_name",
                             "@PREFIX_NAME@" : "prefix_name",
                             "@ADDR_WIDTH@" : "addr_width",
#                             "@NUM_CYCLES@" : "max_cycles",
                             "@INDEX_WIDTH@" : "input_width(index_1)",
                             "@REG_WIDTH@" : "output_width(result)"}
},

"lrc": {"template_file": "externs/EXTERN_lrc_template.v",
        "replacements": {"@DATA_WIDTH@": "input_width(in_data)",
                         "@RESULT_WIDTH@": "output_width(result)",
                         "@MODULE_NAME@": "module_name",
                         "@EXTERN_NAME@": "extern_name"}
},

"timestamp": {"template_file": "externs/EXTERN_timestamp_template.v",
              "replacements": {"@TIMER_WIDTH@": "output_width(result)",
                               "@MODULE_NAME@": "module_name",
                               "@EXTERN_NAME@": "extern_name"}
},

"ip_chksum": {"template_file": "externs/EXTERN_ip_chksum_template.v",
              "replacements": {"@MODULE_NAME@": "module_name",
                               "@EXTERN_NAME@": "extern_name"}
}

}


