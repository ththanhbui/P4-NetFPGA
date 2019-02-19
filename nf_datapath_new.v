
module nf_datapath #(
    //Slave AXI parameters
    parameter C_S_AXI_DATA_WIDTH    = 32,
    parameter C_S_AXI_ADDR_WIDTH    = 32,
     parameter C_BASEADDR            = 32'h00000000,

    // Master AXI Stream Data Width
    parameter C_M_AXIS_DATA_WIDTH=64,
    parameter C_S_AXIS_DATA_WIDTH=64,
    parameter C_M_AXIS_TUSER_WIDTH=128,
    parameter C_S_AXIS_TUSER_WIDTH=128,
    parameter NUM_QUEUES=5,
    parameter NUM_OUTPUT_QUEUES = 8
)
(
    //Datapath clock
    input                                     axis_aclk,
    input                                     axis_resetn,
    //Registers clock
    input                                     axi_aclk,
    input                                     axi_resetn,

    // Slave AXI Ports
    input      [C_S_AXI_ADDR_WIDTH-1 : 0]     S0_AXI_AWADDR,
    input                                     S0_AXI_AWVALID,
    input      [C_S_AXI_DATA_WIDTH-1 : 0]     S0_AXI_WDATA,
    input      [C_S_AXI_DATA_WIDTH/8-1 : 0]   S0_AXI_WSTRB,
    input                                     S0_AXI_WVALID,
    input                                     S0_AXI_BREADY,
    input      [C_S_AXI_ADDR_WIDTH-1 : 0]     S0_AXI_ARADDR,
    input                                     S0_AXI_ARVALID,
    input                                     S0_AXI_RREADY,
    output                                    S0_AXI_ARREADY,
    output     [C_S_AXI_DATA_WIDTH-1 : 0]     S0_AXI_RDATA,
    output     [1 : 0]                        S0_AXI_RRESP,
    output                                    S0_AXI_RVALID,
    output                                    S0_AXI_WREADY,
    output     [1 :0]                         S0_AXI_BRESP,
    output                                    S0_AXI_BVALID,
    output                                    S0_AXI_AWREADY,

    input      [C_S_AXI_ADDR_WIDTH-1 : 0]     S1_AXI_AWADDR,
    input                                     S1_AXI_AWVALID,
    input      [C_S_AXI_DATA_WIDTH-1 : 0]     S1_AXI_WDATA,
    input      [C_S_AXI_DATA_WIDTH/8-1 : 0]   S1_AXI_WSTRB,
    input                                     S1_AXI_WVALID,
    input                                     S1_AXI_BREADY,
    input      [C_S_AXI_ADDR_WIDTH-1 : 0]     S1_AXI_ARADDR,
    input                                     S1_AXI_ARVALID,
    input                                     S1_AXI_RREADY,
    output                                    S1_AXI_ARREADY,
    output     [C_S_AXI_DATA_WIDTH-1 : 0]     S1_AXI_RDATA,
    output     [1 : 0]                        S1_AXI_RRESP,
    output                                    S1_AXI_RVALID,
    output                                    S1_AXI_WREADY,
    output     [1 :0]                         S1_AXI_BRESP,
    output                                    S1_AXI_BVALID,
    output                                    S1_AXI_AWREADY,

    input      [C_S_AXI_ADDR_WIDTH-1 : 0]     S2_AXI_AWADDR,
    input                                     S2_AXI_AWVALID,
    input      [C_S_AXI_DATA_WIDTH-1 : 0]     S2_AXI_WDATA,
    input      [C_S_AXI_DATA_WIDTH/8-1 : 0]   S2_AXI_WSTRB,
    input                                     S2_AXI_WVALID,
    input                                     S2_AXI_BREADY,
    input      [C_S_AXI_ADDR_WIDTH-1 : 0]     S2_AXI_ARADDR,
    input                                     S2_AXI_ARVALID,
    input                                     S2_AXI_RREADY,
    output                                    S2_AXI_ARREADY,
    output     [C_S_AXI_DATA_WIDTH-1 : 0]     S2_AXI_RDATA,
    output     [1 : 0]                        S2_AXI_RRESP,
    output                                    S2_AXI_RVALID,
    output                                    S2_AXI_WREADY,
    output     [1 :0]                         S2_AXI_BRESP,
    output                                    S2_AXI_BVALID,
    output                                    S2_AXI_AWREADY,


    // Slave Stream Ports (interface from Rx queues)
    input [C_S_AXIS_DATA_WIDTH - 1:0]         s_axis_0_tdata,
    input [((C_S_AXIS_DATA_WIDTH / 8)) - 1:0] s_axis_0_tkeep,
    input [C_S_AXIS_TUSER_WIDTH-1:0]          s_axis_0_tuser,
    input                                     s_axis_0_tvalid,
    output                                    s_axis_0_tready,
    input                                     s_axis_0_tlast,
    input [C_S_AXIS_DATA_WIDTH - 1:0]         s_axis_1_tdata,
    input [((C_S_AXIS_DATA_WIDTH / 8)) - 1:0] s_axis_1_tkeep,
    input [C_S_AXIS_TUSER_WIDTH-1:0]          s_axis_1_tuser,
    input                                     s_axis_1_tvalid,
    output                                    s_axis_1_tready,
    input                                     s_axis_1_tlast,
    input [C_S_AXIS_DATA_WIDTH - 1:0]         s_axis_2_tdata,
    input [((C_S_AXIS_DATA_WIDTH / 8)) - 1:0] s_axis_2_tkeep,
    input [C_S_AXIS_TUSER_WIDTH-1:0]          s_axis_2_tuser,
    input                                     s_axis_2_tvalid,
    output                                    s_axis_2_tready,
    input                                     s_axis_2_tlast,
    input [C_S_AXIS_DATA_WIDTH - 1:0]         s_axis_3_tdata,
    input [((C_S_AXIS_DATA_WIDTH / 8)) - 1:0] s_axis_3_tkeep,
    input [C_S_AXIS_TUSER_WIDTH-1:0]          s_axis_3_tuser,
    input                                     s_axis_3_tvalid,
    output                                    s_axis_3_tready,
    input                                     s_axis_3_tlast,
    input [C_S_AXIS_DATA_WIDTH - 1:0]         s_axis_4_tdata,
    input [((C_S_AXIS_DATA_WIDTH / 8)) - 1:0] s_axis_4_tkeep,
    input [C_S_AXIS_TUSER_WIDTH-1:0]          s_axis_4_tuser,
    input                                     s_axis_4_tvalid,
    output                                    s_axis_4_tready,
    input                                     s_axis_4_tlast,


    // Master Stream Ports (interface to TX queues)
    output [C_M_AXIS_DATA_WIDTH - 1:0]         m_axis_0_tdata,
    output [((C_M_AXIS_DATA_WIDTH / 8)) - 1:0] m_axis_0_tkeep,
    output [C_M_AXIS_TUSER_WIDTH-1:0]          m_axis_0_tuser,
    output                                     m_axis_0_tvalid,
    input                                      m_axis_0_tready,
    output                                     m_axis_0_tlast,
    output [C_M_AXIS_DATA_WIDTH - 1:0]         m_axis_1_tdata,
    output [((C_M_AXIS_DATA_WIDTH / 8)) - 1:0] m_axis_1_tkeep,
    output [C_M_AXIS_TUSER_WIDTH-1:0]          m_axis_1_tuser,
    output                                     m_axis_1_tvalid,
    input                                      m_axis_1_tready,
    output                                     m_axis_1_tlast,
    output [C_M_AXIS_DATA_WIDTH - 1:0]         m_axis_2_tdata,
    output [((C_M_AXIS_DATA_WIDTH / 8)) - 1:0] m_axis_2_tkeep,
    output [C_M_AXIS_TUSER_WIDTH-1:0]          m_axis_2_tuser,
    output                                     m_axis_2_tvalid,
    input                                      m_axis_2_tready,
    output                                     m_axis_2_tlast,
    output [C_M_AXIS_DATA_WIDTH - 1:0]         m_axis_3_tdata,
    output [((C_M_AXIS_DATA_WIDTH / 8)) - 1:0] m_axis_3_tkeep,
    output [C_M_AXIS_TUSER_WIDTH-1:0]          m_axis_3_tuser,
    output                                     m_axis_3_tvalid,
    input                                      m_axis_3_tready,
    output                                     m_axis_3_tlast,
    output [C_M_AXIS_DATA_WIDTH - 1:0]         m_axis_4_tdata,
    output [((C_M_AXIS_DATA_WIDTH / 8)) - 1:0] m_axis_4_tkeep,
    output [C_M_AXIS_TUSER_WIDTH-1:0]          m_axis_4_tuser,
    output                                     m_axis_4_tvalid,
    input                                      m_axis_4_tready,
    output                                     m_axis_4_tlast


    );

    wire lowrst;
    assign lowrst = ~ axis_resetn;

    initial begin
        $dumpfile("/root/dump_datapath_withAXIregsAndLUT.vcd");
        $dumpvars;
    end






        wire [C_M_AXIS_DATA_WIDTH - 1:0]         opl0_to_buf0_axis_tdata;
        wire [((C_M_AXIS_DATA_WIDTH / 8)) - 1:0] opl0_to_buf0_axis_tkeep;
        wire [C_M_AXIS_TUSER_WIDTH-1:0]          opl0_to_buf0_axis_tuser;
        wire                                     opl0_to_buf0_axis_tvalid;
        wire                                     opl0_to_buf0_axis_tready;
        wire                                     opl0_to_buf0_axis_tlast;
    
wire orch_to_opl0_request;
wire orch_to_opl0_reply;
wire [47:0] opl0_to_orch_dst_mac;
wire [47:0] opl0_to_orch_src_mac;
wire [NUM_OUTPUT_QUEUES-1:0] opl0_to_orch_src_port;
wire [NUM_OUTPUT_QUEUES-1:0] opl0_to_orch_dst_port;
wire opl0_to_orch_lookup_req;
wire orch_to_opl0_done;
wire orch_to_opl0_hit;
wire orch_to_opl0_miss;



        wire [C_M_AXIS_DATA_WIDTH - 1:0]         buf0_to_oa0_axis_tdata;
        wire [((C_M_AXIS_DATA_WIDTH / 8)) - 1:0] buf0_to_oa0_axis_tkeep;
        wire [C_M_AXIS_TUSER_WIDTH-1:0]          buf0_to_oa0_axis_tuser;
        wire                                     buf0_to_oa0_axis_tvalid;
        wire                                     buf0_to_oa0_axis_tready;
        wire                                     buf0_to_oa0_axis_tlast;
    



        wire [C_M_AXIS_DATA_WIDTH - 1:0]         buf0_to_oa1_axis_tdata;
        wire [((C_M_AXIS_DATA_WIDTH / 8)) - 1:0] buf0_to_oa1_axis_tkeep;
        wire [C_M_AXIS_TUSER_WIDTH-1:0]          buf0_to_oa1_axis_tuser;
        wire                                     buf0_to_oa1_axis_tvalid;
        wire                                     buf0_to_oa1_axis_tready;
        wire                                     buf0_to_oa1_axis_tlast;
    



        wire [C_M_AXIS_DATA_WIDTH - 1:0]         buf0_to_oa2_axis_tdata;
        wire [((C_M_AXIS_DATA_WIDTH / 8)) - 1:0] buf0_to_oa2_axis_tkeep;
        wire [C_M_AXIS_TUSER_WIDTH-1:0]          buf0_to_oa2_axis_tuser;
        wire                                     buf0_to_oa2_axis_tvalid;
        wire                                     buf0_to_oa2_axis_tready;
        wire                                     buf0_to_oa2_axis_tlast;
    



        wire [C_M_AXIS_DATA_WIDTH - 1:0]         buf0_to_oa3_axis_tdata;
        wire [((C_M_AXIS_DATA_WIDTH / 8)) - 1:0] buf0_to_oa3_axis_tkeep;
        wire [C_M_AXIS_TUSER_WIDTH-1:0]          buf0_to_oa3_axis_tuser;
        wire                                     buf0_to_oa3_axis_tvalid;
        wire                                     buf0_to_oa3_axis_tready;
        wire                                     buf0_to_oa3_axis_tlast;
    





        wire [C_M_AXIS_DATA_WIDTH - 1:0]         opl1_to_buf1_axis_tdata;
        wire [((C_M_AXIS_DATA_WIDTH / 8)) - 1:0] opl1_to_buf1_axis_tkeep;
        wire [C_M_AXIS_TUSER_WIDTH-1:0]          opl1_to_buf1_axis_tuser;
        wire                                     opl1_to_buf1_axis_tvalid;
        wire                                     opl1_to_buf1_axis_tready;
        wire                                     opl1_to_buf1_axis_tlast;
    
wire orch_to_opl1_request;
wire orch_to_opl1_reply;
wire [47:0] opl1_to_orch_dst_mac;
wire [47:0] opl1_to_orch_src_mac;
wire [NUM_OUTPUT_QUEUES-1:0] opl1_to_orch_src_port;
wire [NUM_OUTPUT_QUEUES-1:0] opl1_to_orch_dst_port;
wire opl1_to_orch_lookup_req;
wire orch_to_opl1_done;
wire orch_to_opl1_hit;
wire orch_to_opl1_miss;



        wire [C_M_AXIS_DATA_WIDTH - 1:0]         buf1_to_oa0_axis_tdata;
        wire [((C_M_AXIS_DATA_WIDTH / 8)) - 1:0] buf1_to_oa0_axis_tkeep;
        wire [C_M_AXIS_TUSER_WIDTH-1:0]          buf1_to_oa0_axis_tuser;
        wire                                     buf1_to_oa0_axis_tvalid;
        wire                                     buf1_to_oa0_axis_tready;
        wire                                     buf1_to_oa0_axis_tlast;
    



        wire [C_M_AXIS_DATA_WIDTH - 1:0]         buf1_to_oa1_axis_tdata;
        wire [((C_M_AXIS_DATA_WIDTH / 8)) - 1:0] buf1_to_oa1_axis_tkeep;
        wire [C_M_AXIS_TUSER_WIDTH-1:0]          buf1_to_oa1_axis_tuser;
        wire                                     buf1_to_oa1_axis_tvalid;
        wire                                     buf1_to_oa1_axis_tready;
        wire                                     buf1_to_oa1_axis_tlast;
    



        wire [C_M_AXIS_DATA_WIDTH - 1:0]         buf1_to_oa2_axis_tdata;
        wire [((C_M_AXIS_DATA_WIDTH / 8)) - 1:0] buf1_to_oa2_axis_tkeep;
        wire [C_M_AXIS_TUSER_WIDTH-1:0]          buf1_to_oa2_axis_tuser;
        wire                                     buf1_to_oa2_axis_tvalid;
        wire                                     buf1_to_oa2_axis_tready;
        wire                                     buf1_to_oa2_axis_tlast;
    



        wire [C_M_AXIS_DATA_WIDTH - 1:0]         buf1_to_oa3_axis_tdata;
        wire [((C_M_AXIS_DATA_WIDTH / 8)) - 1:0] buf1_to_oa3_axis_tkeep;
        wire [C_M_AXIS_TUSER_WIDTH-1:0]          buf1_to_oa3_axis_tuser;
        wire                                     buf1_to_oa3_axis_tvalid;
        wire                                     buf1_to_oa3_axis_tready;
        wire                                     buf1_to_oa3_axis_tlast;
    





        wire [C_M_AXIS_DATA_WIDTH - 1:0]         opl2_to_buf2_axis_tdata;
        wire [((C_M_AXIS_DATA_WIDTH / 8)) - 1:0] opl2_to_buf2_axis_tkeep;
        wire [C_M_AXIS_TUSER_WIDTH-1:0]          opl2_to_buf2_axis_tuser;
        wire                                     opl2_to_buf2_axis_tvalid;
        wire                                     opl2_to_buf2_axis_tready;
        wire                                     opl2_to_buf2_axis_tlast;
    
wire orch_to_opl2_request;
wire orch_to_opl2_reply;
wire [47:0] opl2_to_orch_dst_mac;
wire [47:0] opl2_to_orch_src_mac;
wire [NUM_OUTPUT_QUEUES-1:0] opl2_to_orch_src_port;
wire [NUM_OUTPUT_QUEUES-1:0] opl2_to_orch_dst_port;
wire opl2_to_orch_lookup_req;
wire orch_to_opl2_done;
wire orch_to_opl2_hit;
wire orch_to_opl2_miss;



        wire [C_M_AXIS_DATA_WIDTH - 1:0]         buf2_to_oa0_axis_tdata;
        wire [((C_M_AXIS_DATA_WIDTH / 8)) - 1:0] buf2_to_oa0_axis_tkeep;
        wire [C_M_AXIS_TUSER_WIDTH-1:0]          buf2_to_oa0_axis_tuser;
        wire                                     buf2_to_oa0_axis_tvalid;
        wire                                     buf2_to_oa0_axis_tready;
        wire                                     buf2_to_oa0_axis_tlast;
    



        wire [C_M_AXIS_DATA_WIDTH - 1:0]         buf2_to_oa1_axis_tdata;
        wire [((C_M_AXIS_DATA_WIDTH / 8)) - 1:0] buf2_to_oa1_axis_tkeep;
        wire [C_M_AXIS_TUSER_WIDTH-1:0]          buf2_to_oa1_axis_tuser;
        wire                                     buf2_to_oa1_axis_tvalid;
        wire                                     buf2_to_oa1_axis_tready;
        wire                                     buf2_to_oa1_axis_tlast;
    



        wire [C_M_AXIS_DATA_WIDTH - 1:0]         buf2_to_oa2_axis_tdata;
        wire [((C_M_AXIS_DATA_WIDTH / 8)) - 1:0] buf2_to_oa2_axis_tkeep;
        wire [C_M_AXIS_TUSER_WIDTH-1:0]          buf2_to_oa2_axis_tuser;
        wire                                     buf2_to_oa2_axis_tvalid;
        wire                                     buf2_to_oa2_axis_tready;
        wire                                     buf2_to_oa2_axis_tlast;
    



        wire [C_M_AXIS_DATA_WIDTH - 1:0]         buf2_to_oa3_axis_tdata;
        wire [((C_M_AXIS_DATA_WIDTH / 8)) - 1:0] buf2_to_oa3_axis_tkeep;
        wire [C_M_AXIS_TUSER_WIDTH-1:0]          buf2_to_oa3_axis_tuser;
        wire                                     buf2_to_oa3_axis_tvalid;
        wire                                     buf2_to_oa3_axis_tready;
        wire                                     buf2_to_oa3_axis_tlast;
    





        wire [C_M_AXIS_DATA_WIDTH - 1:0]         opl3_to_buf3_axis_tdata;
        wire [((C_M_AXIS_DATA_WIDTH / 8)) - 1:0] opl3_to_buf3_axis_tkeep;
        wire [C_M_AXIS_TUSER_WIDTH-1:0]          opl3_to_buf3_axis_tuser;
        wire                                     opl3_to_buf3_axis_tvalid;
        wire                                     opl3_to_buf3_axis_tready;
        wire                                     opl3_to_buf3_axis_tlast;
    
wire orch_to_opl3_request;
wire orch_to_opl3_reply;
wire [47:0] opl3_to_orch_dst_mac;
wire [47:0] opl3_to_orch_src_mac;
wire [NUM_OUTPUT_QUEUES-1:0] opl3_to_orch_src_port;
wire [NUM_OUTPUT_QUEUES-1:0] opl3_to_orch_dst_port;
wire opl3_to_orch_lookup_req;
wire orch_to_opl3_done;
wire orch_to_opl3_hit;
wire orch_to_opl3_miss;



        wire [C_M_AXIS_DATA_WIDTH - 1:0]         buf3_to_oa0_axis_tdata;
        wire [((C_M_AXIS_DATA_WIDTH / 8)) - 1:0] buf3_to_oa0_axis_tkeep;
        wire [C_M_AXIS_TUSER_WIDTH-1:0]          buf3_to_oa0_axis_tuser;
        wire                                     buf3_to_oa0_axis_tvalid;
        wire                                     buf3_to_oa0_axis_tready;
        wire                                     buf3_to_oa0_axis_tlast;
    



        wire [C_M_AXIS_DATA_WIDTH - 1:0]         buf3_to_oa1_axis_tdata;
        wire [((C_M_AXIS_DATA_WIDTH / 8)) - 1:0] buf3_to_oa1_axis_tkeep;
        wire [C_M_AXIS_TUSER_WIDTH-1:0]          buf3_to_oa1_axis_tuser;
        wire                                     buf3_to_oa1_axis_tvalid;
        wire                                     buf3_to_oa1_axis_tready;
        wire                                     buf3_to_oa1_axis_tlast;
    



        wire [C_M_AXIS_DATA_WIDTH - 1:0]         buf3_to_oa2_axis_tdata;
        wire [((C_M_AXIS_DATA_WIDTH / 8)) - 1:0] buf3_to_oa2_axis_tkeep;
        wire [C_M_AXIS_TUSER_WIDTH-1:0]          buf3_to_oa2_axis_tuser;
        wire                                     buf3_to_oa2_axis_tvalid;
        wire                                     buf3_to_oa2_axis_tready;
        wire                                     buf3_to_oa2_axis_tlast;
    



        wire [C_M_AXIS_DATA_WIDTH - 1:0]         buf3_to_oa3_axis_tdata;
        wire [((C_M_AXIS_DATA_WIDTH / 8)) - 1:0] buf3_to_oa3_axis_tkeep;
        wire [C_M_AXIS_TUSER_WIDTH-1:0]          buf3_to_oa3_axis_tuser;
        wire                                     buf3_to_oa3_axis_tvalid;
        wire                                     buf3_to_oa3_axis_tready;
        wire                                     buf3_to_oa3_axis_tlast;
    







wire [47:0]                         orch_dst_mac_lut;
wire [47:0]                         orch_src_mac_lut;
wire [NUM_OUTPUT_QUEUES-1:0]        orch_src_port_lut;
wire [NUM_OUTPUT_QUEUES-1:0]        orch_dst_port_lut;
wire                                orch_lookup_req_lut;
wire                                orch_lookup_done;
wire                                orch_lookup_hit;
wire                                orch_lookup_miss;


Orchestrator orchestrator(
    // clock
    .clk(axis_aclk),
    // asynchronous reset: active low
    .reset(lowrst),

    .dst_mac_0(opl0_to_orch_dst_mac),
    .src_mac_0(opl0_to_orch_src_mac),
    .src_port_0(opl0_to_orch_src_port),
    .lookup_req_0(opl0_to_orch_lookup_req),
    .dst_ports_0(opl0_to_orch_dst_port),
    .request_0(orch_to_opl0_request),
    .reply_0(orch_to_opl0_reply),
    .done_0(orch_to_opl0_done),
    .hit_0(orch_to_opl0_hit),
    .miss_0(orch_to_opl0_miss),


    .dst_mac_1(opl1_to_orch_dst_mac),
    .src_mac_1(opl1_to_orch_src_mac),
    .src_port_1(opl1_to_orch_src_port),
    .lookup_req_1(opl1_to_orch_lookup_req),
    .dst_ports_1(opl1_to_orch_dst_port),
    .request_1(orch_to_opl1_request),
    .reply_1(orch_to_opl1_reply),
    .done_1(orch_to_opl1_done),
    .hit_1(orch_to_opl1_hit),
    .miss_1(orch_to_opl1_miss),


    .dst_mac_2(opl2_to_orch_dst_mac),
    .src_mac_2(opl2_to_orch_src_mac),
    .src_port_2(opl2_to_orch_src_port),
    .lookup_req_2(opl2_to_orch_lookup_req),
    .dst_ports_2(opl2_to_orch_dst_port),
    .request_2(orch_to_opl2_request),
    .reply_2(orch_to_opl2_reply),
    .done_2(orch_to_opl2_done),
    .hit_2(orch_to_opl2_hit),
    .miss_2(orch_to_opl2_miss),


    .dst_mac_3(opl3_to_orch_dst_mac),
    .src_mac_3(opl3_to_orch_src_mac),
    .src_port_3(opl3_to_orch_src_port),
    .lookup_req_3(opl3_to_orch_lookup_req),
    .dst_ports_3(opl3_to_orch_dst_port),
    .request_3(orch_to_opl3_request),
    .reply_3(orch_to_opl3_reply),
    .done_3(orch_to_opl3_done),
    .hit_3(orch_to_opl3_hit),
    .miss_3(orch_to_opl3_miss),


    .dst_mac_lut(orch_dst_mac_lut),
    .src_mac_lut(orch_src_mac_lut),
    .src_port_lut(orch_src_port_lut),
    .lookup_req_lut(orch_lookup_req_lut),
    .dst_ports_lut(orch_dst_port_lut),
    .done_lut(orch_lookup_done),
    .hit_lut(orch_lookup_hit),
    .miss_lut(orch_lookup_miss)

);

mac_cam_lut tcam
     // --- lookup and learn port
     (.dst_mac      (orch_dst_mac_lut),
      .src_mac      (orch_src_mac_lut),
      .src_port     (orch_src_port_lut),
      .lookup_req   (orch_lookup_req_lut),
      .dst_ports    (orch_dst_port_lut),

      .lookup_done  (orch_lookup_done),
      .lut_hit      (orch_lookup_hit),
      .lut_miss     (orch_lookup_miss),

      // --- Misc
      .clk          (axis_aclk),
      .reset        (lowrst)
);






         reg [10:0] bcast_0 = ~0;

          OPL output_port_lookup_0(
            // clock
            .clk(axis_aclk),
            // asynchronous reset: active low
            .rst(lowrst),

            .I_DATA(s_axis_0_tdata),
            .I_KEEP(s_axis_0_tkeep),
            .I_USER(s_axis_0_tuser),
            .I_VALID(s_axis_0_tvalid),
            .I_READY(opl0_to_buf0_axis_tready),
            .I_LAST(s_axis_0_tlast),
            .TCAM_I_PORTS(opl0_to_orch_dst_port),
            .TCAM_DONE(orch_to_opl0_done),
            .TCAM_MISS(orch_to_opl0_miss),
            .TCAM_HIT(orch_to_opl0_hit),

            .O_DATA(opl0_to_buf0_axis_tdata),
            .O_KEEP(opl0_to_buf0_axis_tkeep),
            .O_USER(opl0_to_buf0_axis_tuser),
            .O_VALID(opl0_to_buf0_axis_tvalid),
            .O_READY(s_axis_0_tready),
            .O_LAST(opl0_to_buf0_axis_tlast),
            .TCAM_O_DST_MAC(opl0_to_orch_dst_mac),
            .TCAM_O_SRC_MAC(opl0_to_orch_src_mac),
            .TCAM_O_SRC_PORT(opl0_to_orch_src_port),
            .TCAM_O_LOOKUP_REQ(opl0_to_orch_lookup_req),

            .REQ_ENB(orch_to_opl0_request),
            .RPY_ENB(orch_to_opl0_reply)
            );

    


          //Output queues
           output_queues_ip bram_output_queues_0 (
          .axis_aclk(axis_aclk),
          .axis_resetn(axis_resetn),
          .s_axis_tdata   (opl0_to_buf0_axis_tdata),
          .s_axis_tkeep   (opl0_to_buf0_axis_tkeep),
          .s_axis_tuser   (opl0_to_buf0_axis_tuser),
          .s_axis_tvalid  (opl0_to_buf0_axis_tvalid),
          .s_axis_tready  (opl0_to_buf0_axis_tready),
          .s_axis_tlast   (opl0_to_buf0_axis_tlast),
          .m_axis_0_tdata (buf0_to_oa0_axis_tdata),
          .m_axis_0_tkeep (buf0_to_oa0_axis_tkeep),
          .m_axis_0_tuser (buf0_to_oa0_axis_tuser),
          .m_axis_0_tvalid(buf0_to_oa0_axis_tvalid),
          .m_axis_0_tready(buf0_to_oa0_axis_tready),
          .m_axis_0_tlast (buf0_to_oa0_axis_tlast),
          .m_axis_1_tdata (buf0_to_oa1_axis_tdata),
          .m_axis_1_tkeep (buf0_to_oa1_axis_tkeep),
          .m_axis_1_tuser (buf0_to_oa1_axis_tuser),
          .m_axis_1_tvalid(buf0_to_oa1_axis_tvalid),
          .m_axis_1_tready(buf0_to_oa1_axis_tready),
          .m_axis_1_tlast (buf0_to_oa1_axis_tlast),
          .m_axis_2_tdata (buf0_to_oa2_axis_tdata),
          .m_axis_2_tkeep (buf0_to_oa2_axis_tkeep),
          .m_axis_2_tuser (buf0_to_oa2_axis_tuser),
          .m_axis_2_tvalid(buf0_to_oa2_axis_tvalid),
          .m_axis_2_tready(buf0_to_oa2_axis_tready),
          .m_axis_2_tlast (buf0_to_oa2_axis_tlast),
          .m_axis_3_tdata (buf0_to_oa3_axis_tdata),
          .m_axis_3_tkeep (buf0_to_oa3_axis_tkeep),
          .m_axis_3_tuser (buf0_to_oa3_axis_tuser),
          .m_axis_3_tvalid(buf0_to_oa3_axis_tvalid),
          .m_axis_3_tready(buf0_to_oa3_axis_tready),
          .m_axis_3_tlast (buf0_to_oa3_axis_tlast),

          .bytes_stored(),
          .pkt_stored(),
          .bytes_removed_0(),
          .bytes_removed_1(),
          .bytes_removed_2(),
          .bytes_removed_3(),
          .bytes_removed_4(),
          .pkt_removed_0(),
          .pkt_removed_1(),
          .pkt_removed_2(),
          .pkt_removed_3(),
          .pkt_removed_4(),
          .bytes_dropped(),
          .pkt_dropped(),

        .S_AXI_ACLK (axi_aclk),
        .S_AXI_ARESETN(axi_resetn),
    
        .S_AXI_AWADDR(S1_AXI_AWADDR),
        .S_AXI_AWVALID(S1_AXI_AWVALID),
        .S_AXI_WDATA(S1_AXI_WDATA),
        .S_AXI_WSTRB(S1_AXI_WSTRB),
        .S_AXI_WVALID(S1_AXI_WVALID),
        .S_AXI_BREADY(S1_AXI_BREADY),
        .S_AXI_ARADDR(S1_AXI_ARADDR),
        .S_AXI_ARVALID(S1_AXI_ARVALID),
        .S_AXI_RREADY(S1_AXI_RREADY),
        .S_AXI_ARREADY(S1_AXI_ARREADY),
        .S_AXI_RDATA(S1_AXI_RDATA),
        .S_AXI_RRESP(S1_AXI_RRESP),
        .S_AXI_RVALID(S1_AXI_RVALID),
        .S_AXI_WREADY(S1_AXI_WREADY),
        .S_AXI_BRESP(S1_AXI_BRESP),
        .S_AXI_BVALID(S1_AXI_BVALID),
        .S_AXI_AWREADY(S1_AXI_AWREADY)
    );
        


      //Input Arbiter
      input_arbiter_ip
     input_arbiter_0 (
          .axis_aclk(axis_aclk),
          .axis_resetn(axis_resetn),
          .m_axis_tdata (m_axis_0_tdata),
          .m_axis_tkeep (m_axis_0_tkeep),
          .m_axis_tuser (m_axis_0_tuser),
          .m_axis_tvalid(m_axis_0_tvalid),
          .m_axis_tready(m_axis_0_tready),
          .m_axis_tlast (m_axis_0_tlast),
          .s_axis_0_tdata (buf0_to_oa0_axis_tdata),
          .s_axis_0_tkeep (buf0_to_oa0_axis_tkeep),
          .s_axis_0_tuser (buf0_to_oa0_axis_tuser),
          .s_axis_0_tvalid(buf0_to_oa0_axis_tvalid),
          .s_axis_0_tready(buf0_to_oa0_axis_tready),
          .s_axis_0_tlast (buf0_to_oa0_axis_tlast),
          .s_axis_1_tdata (buf1_to_oa0_axis_tdata),
          .s_axis_1_tkeep (buf1_to_oa0_axis_tkeep),
          .s_axis_1_tuser (buf1_to_oa0_axis_tuser),
          .s_axis_1_tvalid(buf1_to_oa0_axis_tvalid),
          .s_axis_1_tready(buf1_to_oa0_axis_tready),
          .s_axis_1_tlast (buf1_to_oa0_axis_tlast),
          .s_axis_2_tdata (buf2_to_oa0_axis_tdata),
          .s_axis_2_tkeep (buf2_to_oa0_axis_tkeep),
          .s_axis_2_tuser (buf2_to_oa0_axis_tuser),
          .s_axis_2_tvalid(buf2_to_oa0_axis_tvalid),
          .s_axis_2_tready(buf2_to_oa0_axis_tready),
          .s_axis_2_tlast (buf2_to_oa0_axis_tlast),
          .s_axis_3_tdata (buf3_to_oa0_axis_tdata),
          .s_axis_3_tkeep (buf3_to_oa0_axis_tkeep),
          .s_axis_3_tuser (buf3_to_oa0_axis_tuser),
          .s_axis_3_tvalid(buf3_to_oa0_axis_tvalid),
          .s_axis_3_tready(buf3_to_oa0_axis_tready),
          .s_axis_3_tlast (buf3_to_oa0_axis_tlast),

          .S_AXI_ACLK (axi_aclk),
          .S_AXI_ARESETN(axi_resetn),
          .pkt_fwd(),
    
      .S_AXI_AWADDR(S0_AXI_AWADDR),
      .S_AXI_AWVALID(S0_AXI_AWVALID),
      .S_AXI_WDATA(S0_AXI_WDATA),
      .S_AXI_WSTRB(S0_AXI_WSTRB),
      .S_AXI_WVALID(S0_AXI_WVALID),
      .S_AXI_BREADY(S0_AXI_BREADY),
      .S_AXI_ARADDR(S0_AXI_ARADDR),
      .S_AXI_ARVALID(S0_AXI_ARVALID),
      .S_AXI_RREADY(S0_AXI_RREADY),
      .S_AXI_ARREADY(S0_AXI_ARREADY),
      .S_AXI_RDATA(S0_AXI_RDATA),
      .S_AXI_RRESP(S0_AXI_RRESP),
      .S_AXI_RVALID(S0_AXI_RVALID),
      .S_AXI_WREADY(S0_AXI_WREADY),
      .S_AXI_BRESP(S0_AXI_BRESP),
      .S_AXI_BVALID(S0_AXI_BVALID),
      .S_AXI_AWREADY(S0_AXI_AWREADY)
    );
        





         reg [10:0] bcast_1 = ~0;

          OPL output_port_lookup_1(
            // clock
            .clk(axis_aclk),
            // asynchronous reset: active low
            .rst(lowrst),

            .I_DATA(s_axis_1_tdata),
            .I_KEEP(s_axis_1_tkeep),
            .I_USER(s_axis_1_tuser),
            .I_VALID(s_axis_1_tvalid),
            .I_READY(opl1_to_buf1_axis_tready),
            .I_LAST(s_axis_1_tlast),
            .TCAM_I_PORTS(opl1_to_orch_dst_port),
            .TCAM_DONE(orch_to_opl1_done),
            .TCAM_MISS(orch_to_opl1_miss),
            .TCAM_HIT(orch_to_opl1_hit),

            .O_DATA(opl1_to_buf1_axis_tdata),
            .O_KEEP(opl1_to_buf1_axis_tkeep),
            .O_USER(opl1_to_buf1_axis_tuser),
            .O_VALID(opl1_to_buf1_axis_tvalid),
            .O_READY(s_axis_1_tready),
            .O_LAST(opl1_to_buf1_axis_tlast),
            .TCAM_O_DST_MAC(opl1_to_orch_dst_mac),
            .TCAM_O_SRC_MAC(opl1_to_orch_src_mac),
            .TCAM_O_SRC_PORT(opl1_to_orch_src_port),
            .TCAM_O_LOOKUP_REQ(opl1_to_orch_lookup_req),

            .REQ_ENB(orch_to_opl1_request),
            .RPY_ENB(orch_to_opl1_reply)
            );

    


          //Output queues
           output_queues_ip bram_output_queues_1 (
          .axis_aclk(axis_aclk),
          .axis_resetn(axis_resetn),
          .s_axis_tdata   (opl1_to_buf1_axis_tdata),
          .s_axis_tkeep   (opl1_to_buf1_axis_tkeep),
          .s_axis_tuser   (opl1_to_buf1_axis_tuser),
          .s_axis_tvalid  (opl1_to_buf1_axis_tvalid),
          .s_axis_tready  (opl1_to_buf1_axis_tready),
          .s_axis_tlast   (opl1_to_buf1_axis_tlast),
          .m_axis_0_tdata (buf1_to_oa0_axis_tdata),
          .m_axis_0_tkeep (buf1_to_oa0_axis_tkeep),
          .m_axis_0_tuser (buf1_to_oa0_axis_tuser),
          .m_axis_0_tvalid(buf1_to_oa0_axis_tvalid),
          .m_axis_0_tready(buf1_to_oa0_axis_tready),
          .m_axis_0_tlast (buf1_to_oa0_axis_tlast),
          .m_axis_1_tdata (buf1_to_oa1_axis_tdata),
          .m_axis_1_tkeep (buf1_to_oa1_axis_tkeep),
          .m_axis_1_tuser (buf1_to_oa1_axis_tuser),
          .m_axis_1_tvalid(buf1_to_oa1_axis_tvalid),
          .m_axis_1_tready(buf1_to_oa1_axis_tready),
          .m_axis_1_tlast (buf1_to_oa1_axis_tlast),
          .m_axis_2_tdata (buf1_to_oa2_axis_tdata),
          .m_axis_2_tkeep (buf1_to_oa2_axis_tkeep),
          .m_axis_2_tuser (buf1_to_oa2_axis_tuser),
          .m_axis_2_tvalid(buf1_to_oa2_axis_tvalid),
          .m_axis_2_tready(buf1_to_oa2_axis_tready),
          .m_axis_2_tlast (buf1_to_oa2_axis_tlast),
          .m_axis_3_tdata (buf1_to_oa3_axis_tdata),
          .m_axis_3_tkeep (buf1_to_oa3_axis_tkeep),
          .m_axis_3_tuser (buf1_to_oa3_axis_tuser),
          .m_axis_3_tvalid(buf1_to_oa3_axis_tvalid),
          .m_axis_3_tready(buf1_to_oa3_axis_tready),
          .m_axis_3_tlast (buf1_to_oa3_axis_tlast),

          .bytes_stored(),
          .pkt_stored(),
          .bytes_removed_0(),
          .bytes_removed_1(),
          .bytes_removed_2(),
          .bytes_removed_3(),
          .bytes_removed_4(),
          .pkt_removed_0(),
          .pkt_removed_1(),
          .pkt_removed_2(),
          .pkt_removed_3(),
          .pkt_removed_4(),
          .bytes_dropped(),
          .pkt_dropped(),

        .S_AXI_ACLK (axi_aclk),
        .S_AXI_ARESETN(axi_resetn),
    
      .S_AXI_AWADDR(),
      .S_AXI_AWVALID(),
      .S_AXI_WDATA(),
      .S_AXI_WSTRB(),
      .S_AXI_WVALID(),
      .S_AXI_BREADY(),
      .S_AXI_ARADDR(),
      .S_AXI_ARVALID(),
      .S_AXI_RREADY(),
      .S_AXI_ARREADY(),
      .S_AXI_RDATA(),
      .S_AXI_RRESP(),
      .S_AXI_RVALID(),
      .S_AXI_WREADY(),
      .S_AXI_BRESP(),
      .S_AXI_BVALID(),
      .S_AXI_AWREADY()
    );
        


      //Input Arbiter
      input_arbiter_ip
     input_arbiter_1 (
          .axis_aclk(axis_aclk),
          .axis_resetn(axis_resetn),
          .m_axis_tdata (m_axis_1_tdata),
          .m_axis_tkeep (m_axis_1_tkeep),
          .m_axis_tuser (m_axis_1_tuser),
          .m_axis_tvalid(m_axis_1_tvalid),
          .m_axis_tready(m_axis_1_tready),
          .m_axis_tlast (m_axis_1_tlast),
          .s_axis_0_tdata (buf0_to_oa1_axis_tdata),
          .s_axis_0_tkeep (buf0_to_oa1_axis_tkeep),
          .s_axis_0_tuser (buf0_to_oa1_axis_tuser),
          .s_axis_0_tvalid(buf0_to_oa1_axis_tvalid),
          .s_axis_0_tready(buf0_to_oa1_axis_tready),
          .s_axis_0_tlast (buf0_to_oa1_axis_tlast),
          .s_axis_1_tdata (buf1_to_oa1_axis_tdata),
          .s_axis_1_tkeep (buf1_to_oa1_axis_tkeep),
          .s_axis_1_tuser (buf1_to_oa1_axis_tuser),
          .s_axis_1_tvalid(buf1_to_oa1_axis_tvalid),
          .s_axis_1_tready(buf1_to_oa1_axis_tready),
          .s_axis_1_tlast (buf1_to_oa1_axis_tlast),
          .s_axis_2_tdata (buf2_to_oa1_axis_tdata),
          .s_axis_2_tkeep (buf2_to_oa1_axis_tkeep),
          .s_axis_2_tuser (buf2_to_oa1_axis_tuser),
          .s_axis_2_tvalid(buf2_to_oa1_axis_tvalid),
          .s_axis_2_tready(buf2_to_oa1_axis_tready),
          .s_axis_2_tlast (buf2_to_oa1_axis_tlast),
          .s_axis_3_tdata (buf3_to_oa1_axis_tdata),
          .s_axis_3_tkeep (buf3_to_oa1_axis_tkeep),
          .s_axis_3_tuser (buf3_to_oa1_axis_tuser),
          .s_axis_3_tvalid(buf3_to_oa1_axis_tvalid),
          .s_axis_3_tready(buf3_to_oa1_axis_tready),
          .s_axis_3_tlast (buf3_to_oa1_axis_tlast),

          .S_AXI_ACLK (axi_aclk),
          .S_AXI_ARESETN(axi_resetn),
          .pkt_fwd(),
    
        .S_AXI_AWADDR(),
        .S_AXI_AWVALID(),
        .S_AXI_WDATA(),
        .S_AXI_WSTRB(),
        .S_AXI_WVALID(),
        .S_AXI_BREADY(),
        .S_AXI_ARADDR(),
        .S_AXI_ARVALID(),
        .S_AXI_RREADY(),
        .S_AXI_ARREADY(),
        .S_AXI_RDATA(),
        .S_AXI_RRESP(),
        .S_AXI_RVALID(),
        .S_AXI_WREADY(),
        .S_AXI_BRESP(),
        .S_AXI_BVALID(),
        .S_AXI_AWREADY()
    );
        





         reg [10:0] bcast_2 = ~0;

          OPL output_port_lookup_2(
            // clock
            .clk(axis_aclk),
            // asynchronous reset: active low
            .rst(lowrst),

            .I_DATA(s_axis_2_tdata),
            .I_KEEP(s_axis_2_tkeep),
            .I_USER(s_axis_2_tuser),
            .I_VALID(s_axis_2_tvalid),
            .I_READY(opl2_to_buf2_axis_tready),
            .I_LAST(s_axis_2_tlast),
            .TCAM_I_PORTS(opl2_to_orch_dst_port),
            .TCAM_DONE(orch_to_opl2_done),
            .TCAM_MISS(orch_to_opl2_miss),
            .TCAM_HIT(orch_to_opl2_hit),

            .O_DATA(opl2_to_buf2_axis_tdata),
            .O_KEEP(opl2_to_buf2_axis_tkeep),
            .O_USER(opl2_to_buf2_axis_tuser),
            .O_VALID(opl2_to_buf2_axis_tvalid),
            .O_READY(s_axis_2_tready),
            .O_LAST(opl2_to_buf2_axis_tlast),
            .TCAM_O_DST_MAC(opl2_to_orch_dst_mac),
            .TCAM_O_SRC_MAC(opl2_to_orch_src_mac),
            .TCAM_O_SRC_PORT(opl2_to_orch_src_port),
            .TCAM_O_LOOKUP_REQ(opl2_to_orch_lookup_req),

            .REQ_ENB(orch_to_opl2_request),
            .RPY_ENB(orch_to_opl2_reply)
            );

    


          //Output queues
           output_queues_ip bram_output_queues_2 (
          .axis_aclk(axis_aclk),
          .axis_resetn(axis_resetn),
          .s_axis_tdata   (opl2_to_buf2_axis_tdata),
          .s_axis_tkeep   (opl2_to_buf2_axis_tkeep),
          .s_axis_tuser   (opl2_to_buf2_axis_tuser),
          .s_axis_tvalid  (opl2_to_buf2_axis_tvalid),
          .s_axis_tready  (opl2_to_buf2_axis_tready),
          .s_axis_tlast   (opl2_to_buf2_axis_tlast),
          .m_axis_0_tdata (buf2_to_oa0_axis_tdata),
          .m_axis_0_tkeep (buf2_to_oa0_axis_tkeep),
          .m_axis_0_tuser (buf2_to_oa0_axis_tuser),
          .m_axis_0_tvalid(buf2_to_oa0_axis_tvalid),
          .m_axis_0_tready(buf2_to_oa0_axis_tready),
          .m_axis_0_tlast (buf2_to_oa0_axis_tlast),
          .m_axis_1_tdata (buf2_to_oa1_axis_tdata),
          .m_axis_1_tkeep (buf2_to_oa1_axis_tkeep),
          .m_axis_1_tuser (buf2_to_oa1_axis_tuser),
          .m_axis_1_tvalid(buf2_to_oa1_axis_tvalid),
          .m_axis_1_tready(buf2_to_oa1_axis_tready),
          .m_axis_1_tlast (buf2_to_oa1_axis_tlast),
          .m_axis_2_tdata (buf2_to_oa2_axis_tdata),
          .m_axis_2_tkeep (buf2_to_oa2_axis_tkeep),
          .m_axis_2_tuser (buf2_to_oa2_axis_tuser),
          .m_axis_2_tvalid(buf2_to_oa2_axis_tvalid),
          .m_axis_2_tready(buf2_to_oa2_axis_tready),
          .m_axis_2_tlast (buf2_to_oa2_axis_tlast),
          .m_axis_3_tdata (buf2_to_oa3_axis_tdata),
          .m_axis_3_tkeep (buf2_to_oa3_axis_tkeep),
          .m_axis_3_tuser (buf2_to_oa3_axis_tuser),
          .m_axis_3_tvalid(buf2_to_oa3_axis_tvalid),
          .m_axis_3_tready(buf2_to_oa3_axis_tready),
          .m_axis_3_tlast (buf2_to_oa3_axis_tlast),

          .bytes_stored(),
          .pkt_stored(),
          .bytes_removed_0(),
          .bytes_removed_1(),
          .bytes_removed_2(),
          .bytes_removed_3(),
          .bytes_removed_4(),
          .pkt_removed_0(),
          .pkt_removed_1(),
          .pkt_removed_2(),
          .pkt_removed_3(),
          .pkt_removed_4(),
          .bytes_dropped(),
          .pkt_dropped(),

        .S_AXI_ACLK (axi_aclk),
        .S_AXI_ARESETN(axi_resetn),
    
      .S_AXI_AWADDR(),
      .S_AXI_AWVALID(),
      .S_AXI_WDATA(),
      .S_AXI_WSTRB(),
      .S_AXI_WVALID(),
      .S_AXI_BREADY(),
      .S_AXI_ARADDR(),
      .S_AXI_ARVALID(),
      .S_AXI_RREADY(),
      .S_AXI_ARREADY(),
      .S_AXI_RDATA(),
      .S_AXI_RRESP(),
      .S_AXI_RVALID(),
      .S_AXI_WREADY(),
      .S_AXI_BRESP(),
      .S_AXI_BVALID(),
      .S_AXI_AWREADY()
    );
        


      //Input Arbiter
      input_arbiter_ip
     input_arbiter_2 (
          .axis_aclk(axis_aclk),
          .axis_resetn(axis_resetn),
          .m_axis_tdata (m_axis_2_tdata),
          .m_axis_tkeep (m_axis_2_tkeep),
          .m_axis_tuser (m_axis_2_tuser),
          .m_axis_tvalid(m_axis_2_tvalid),
          .m_axis_tready(m_axis_2_tready),
          .m_axis_tlast (m_axis_2_tlast),
          .s_axis_0_tdata (buf0_to_oa2_axis_tdata),
          .s_axis_0_tkeep (buf0_to_oa2_axis_tkeep),
          .s_axis_0_tuser (buf0_to_oa2_axis_tuser),
          .s_axis_0_tvalid(buf0_to_oa2_axis_tvalid),
          .s_axis_0_tready(buf0_to_oa2_axis_tready),
          .s_axis_0_tlast (buf0_to_oa2_axis_tlast),
          .s_axis_1_tdata (buf1_to_oa2_axis_tdata),
          .s_axis_1_tkeep (buf1_to_oa2_axis_tkeep),
          .s_axis_1_tuser (buf1_to_oa2_axis_tuser),
          .s_axis_1_tvalid(buf1_to_oa2_axis_tvalid),
          .s_axis_1_tready(buf1_to_oa2_axis_tready),
          .s_axis_1_tlast (buf1_to_oa2_axis_tlast),
          .s_axis_2_tdata (buf2_to_oa2_axis_tdata),
          .s_axis_2_tkeep (buf2_to_oa2_axis_tkeep),
          .s_axis_2_tuser (buf2_to_oa2_axis_tuser),
          .s_axis_2_tvalid(buf2_to_oa2_axis_tvalid),
          .s_axis_2_tready(buf2_to_oa2_axis_tready),
          .s_axis_2_tlast (buf2_to_oa2_axis_tlast),
          .s_axis_3_tdata (buf3_to_oa2_axis_tdata),
          .s_axis_3_tkeep (buf3_to_oa2_axis_tkeep),
          .s_axis_3_tuser (buf3_to_oa2_axis_tuser),
          .s_axis_3_tvalid(buf3_to_oa2_axis_tvalid),
          .s_axis_3_tready(buf3_to_oa2_axis_tready),
          .s_axis_3_tlast (buf3_to_oa2_axis_tlast),

          .S_AXI_ACLK (axi_aclk),
          .S_AXI_ARESETN(axi_resetn),
          .pkt_fwd(),
    
        .S_AXI_AWADDR(),
        .S_AXI_AWVALID(),
        .S_AXI_WDATA(),
        .S_AXI_WSTRB(),
        .S_AXI_WVALID(),
        .S_AXI_BREADY(),
        .S_AXI_ARADDR(),
        .S_AXI_ARVALID(),
        .S_AXI_RREADY(),
        .S_AXI_ARREADY(),
        .S_AXI_RDATA(),
        .S_AXI_RRESP(),
        .S_AXI_RVALID(),
        .S_AXI_WREADY(),
        .S_AXI_BRESP(),
        .S_AXI_BVALID(),
        .S_AXI_AWREADY()
    );
        





         reg [10:0] bcast_3 = ~0;

          OPL output_port_lookup_3(
            // clock
            .clk(axis_aclk),
            // asynchronous reset: active low
            .rst(lowrst),

            .I_DATA(s_axis_3_tdata),
            .I_KEEP(s_axis_3_tkeep),
            .I_USER(s_axis_3_tuser),
            .I_VALID(s_axis_3_tvalid),
            .I_READY(opl3_to_buf3_axis_tready),
            .I_LAST(s_axis_3_tlast),
            .TCAM_I_PORTS(opl3_to_orch_dst_port),
            .TCAM_DONE(orch_to_opl3_done),
            .TCAM_MISS(orch_to_opl3_miss),
            .TCAM_HIT(orch_to_opl3_hit),

            .O_DATA(opl3_to_buf3_axis_tdata),
            .O_KEEP(opl3_to_buf3_axis_tkeep),
            .O_USER(opl3_to_buf3_axis_tuser),
            .O_VALID(opl3_to_buf3_axis_tvalid),
            .O_READY(s_axis_3_tready),
            .O_LAST(opl3_to_buf3_axis_tlast),
            .TCAM_O_DST_MAC(opl3_to_orch_dst_mac),
            .TCAM_O_SRC_MAC(opl3_to_orch_src_mac),
            .TCAM_O_SRC_PORT(opl3_to_orch_src_port),
            .TCAM_O_LOOKUP_REQ(opl3_to_orch_lookup_req),

            .REQ_ENB(orch_to_opl3_request),
            .RPY_ENB(orch_to_opl3_reply)
            );

    


          //Output queues
           output_queues_ip bram_output_queues_3 (
          .axis_aclk(axis_aclk),
          .axis_resetn(axis_resetn),
          .s_axis_tdata   (opl3_to_buf3_axis_tdata),
          .s_axis_tkeep   (opl3_to_buf3_axis_tkeep),
          .s_axis_tuser   (opl3_to_buf3_axis_tuser),
          .s_axis_tvalid  (opl3_to_buf3_axis_tvalid),
          .s_axis_tready  (opl3_to_buf3_axis_tready),
          .s_axis_tlast   (opl3_to_buf3_axis_tlast),
          .m_axis_0_tdata (buf3_to_oa0_axis_tdata),
          .m_axis_0_tkeep (buf3_to_oa0_axis_tkeep),
          .m_axis_0_tuser (buf3_to_oa0_axis_tuser),
          .m_axis_0_tvalid(buf3_to_oa0_axis_tvalid),
          .m_axis_0_tready(buf3_to_oa0_axis_tready),
          .m_axis_0_tlast (buf3_to_oa0_axis_tlast),
          .m_axis_1_tdata (buf3_to_oa1_axis_tdata),
          .m_axis_1_tkeep (buf3_to_oa1_axis_tkeep),
          .m_axis_1_tuser (buf3_to_oa1_axis_tuser),
          .m_axis_1_tvalid(buf3_to_oa1_axis_tvalid),
          .m_axis_1_tready(buf3_to_oa1_axis_tready),
          .m_axis_1_tlast (buf3_to_oa1_axis_tlast),
          .m_axis_2_tdata (buf3_to_oa2_axis_tdata),
          .m_axis_2_tkeep (buf3_to_oa2_axis_tkeep),
          .m_axis_2_tuser (buf3_to_oa2_axis_tuser),
          .m_axis_2_tvalid(buf3_to_oa2_axis_tvalid),
          .m_axis_2_tready(buf3_to_oa2_axis_tready),
          .m_axis_2_tlast (buf3_to_oa2_axis_tlast),
          .m_axis_3_tdata (buf3_to_oa3_axis_tdata),
          .m_axis_3_tkeep (buf3_to_oa3_axis_tkeep),
          .m_axis_3_tuser (buf3_to_oa3_axis_tuser),
          .m_axis_3_tvalid(buf3_to_oa3_axis_tvalid),
          .m_axis_3_tready(buf3_to_oa3_axis_tready),
          .m_axis_3_tlast (buf3_to_oa3_axis_tlast),

          .bytes_stored(),
          .pkt_stored(),
          .bytes_removed_0(),
          .bytes_removed_1(),
          .bytes_removed_2(),
          .bytes_removed_3(),
          .bytes_removed_4(),
          .pkt_removed_0(),
          .pkt_removed_1(),
          .pkt_removed_2(),
          .pkt_removed_3(),
          .pkt_removed_4(),
          .bytes_dropped(),
          .pkt_dropped(),

        .S_AXI_ACLK (axi_aclk),
        .S_AXI_ARESETN(axi_resetn),
    
      .S_AXI_AWADDR(),
      .S_AXI_AWVALID(),
      .S_AXI_WDATA(),
      .S_AXI_WSTRB(),
      .S_AXI_WVALID(),
      .S_AXI_BREADY(),
      .S_AXI_ARADDR(),
      .S_AXI_ARVALID(),
      .S_AXI_RREADY(),
      .S_AXI_ARREADY(),
      .S_AXI_RDATA(),
      .S_AXI_RRESP(),
      .S_AXI_RVALID(),
      .S_AXI_WREADY(),
      .S_AXI_BRESP(),
      .S_AXI_BVALID(),
      .S_AXI_AWREADY()
    );
        


      //Input Arbiter
      input_arbiter_ip
     input_arbiter_3 (
          .axis_aclk(axis_aclk),
          .axis_resetn(axis_resetn),
          .m_axis_tdata (m_axis_3_tdata),
          .m_axis_tkeep (m_axis_3_tkeep),
          .m_axis_tuser (m_axis_3_tuser),
          .m_axis_tvalid(m_axis_3_tvalid),
          .m_axis_tready(m_axis_3_tready),
          .m_axis_tlast (m_axis_3_tlast),
          .s_axis_0_tdata (buf0_to_oa3_axis_tdata),
          .s_axis_0_tkeep (buf0_to_oa3_axis_tkeep),
          .s_axis_0_tuser (buf0_to_oa3_axis_tuser),
          .s_axis_0_tvalid(buf0_to_oa3_axis_tvalid),
          .s_axis_0_tready(buf0_to_oa3_axis_tready),
          .s_axis_0_tlast (buf0_to_oa3_axis_tlast),
          .s_axis_1_tdata (buf1_to_oa3_axis_tdata),
          .s_axis_1_tkeep (buf1_to_oa3_axis_tkeep),
          .s_axis_1_tuser (buf1_to_oa3_axis_tuser),
          .s_axis_1_tvalid(buf1_to_oa3_axis_tvalid),
          .s_axis_1_tready(buf1_to_oa3_axis_tready),
          .s_axis_1_tlast (buf1_to_oa3_axis_tlast),
          .s_axis_2_tdata (buf2_to_oa3_axis_tdata),
          .s_axis_2_tkeep (buf2_to_oa3_axis_tkeep),
          .s_axis_2_tuser (buf2_to_oa3_axis_tuser),
          .s_axis_2_tvalid(buf2_to_oa3_axis_tvalid),
          .s_axis_2_tready(buf2_to_oa3_axis_tready),
          .s_axis_2_tlast (buf2_to_oa3_axis_tlast),
          .s_axis_3_tdata (buf3_to_oa3_axis_tdata),
          .s_axis_3_tkeep (buf3_to_oa3_axis_tkeep),
          .s_axis_3_tuser (buf3_to_oa3_axis_tuser),
          .s_axis_3_tvalid(buf3_to_oa3_axis_tvalid),
          .s_axis_3_tready(buf3_to_oa3_axis_tready),
          .s_axis_3_tlast (buf3_to_oa3_axis_tlast),

          .S_AXI_ACLK (axi_aclk),
          .S_AXI_ARESETN(axi_resetn),
          .pkt_fwd(),
    
        .S_AXI_AWADDR(),
        .S_AXI_AWVALID(),
        .S_AXI_WDATA(),
        .S_AXI_WSTRB(),
        .S_AXI_WVALID(),
        .S_AXI_BREADY(),
        .S_AXI_ARADDR(),
        .S_AXI_ARVALID(),
        .S_AXI_RREADY(),
        .S_AXI_ARREADY(),
        .S_AXI_RDATA(),
        .S_AXI_RRESP(),
        .S_AXI_RVALID(),
        .S_AXI_WREADY(),
        .S_AXI_BRESP(),
        .S_AXI_BVALID(),
        .S_AXI_AWREADY()
    );
        endmodule
