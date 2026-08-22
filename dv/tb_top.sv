module tb_top
    import rvfi_pkg::*;
();
    
    logic clk;
    logic rst_n;

    logic        core_halted;

    logic        imem_req_valid;
    logic        imem_req_ready;
    logic [31:0] imem_req_addr;
    logic        imem_rsp_valid;
    logic        imem_rsp_error;
    logic [31:0] imem_rsp_rdata;

    logic        dmem_req_valid;
    logic        dmem_req_ready;
    logic [31:0] dmem_req_addr;
    logic        dmem_req_we;
    logic [3:0]  dmem_req_wstrb;
    logic [31:0] dmem_req_wdata;
    logic        dmem_rsp_valid;
    logic        dmem_rsp_error;
    logic [31:0] dmem_rsp_rdata;

    logic        rvfi_valid;
    logic [63:0] rvfi_order;
    logic [31:0] rvfi_insn;
    logic        rvfi_trap;
    logic        rvfi_halt;
    logic        rvfi_intr;
    logic [1:0]  rvfi_mode;
    logic [1:0]  rvfi_ixl;
    logic [4:0]  rvfi_rs1_addr;
    logic [4:0]  rvfi_rs2_addr;
    logic [31:0] rvfi_rs1_rdata;
    logic [31:0] rvfi_rs2_rdata;
    logic [4:0]  rvfi_rd_addr;
    logic [31:0] rvfi_rd_wdata;
    logic [31:0] rvfi_pc_rdata;
    logic [31:0] rvfi_pc_wdata;
    logic [31:0] rvfi_mem_addr;
    logic [3:0]  rvfi_mem_rmask;
    logic [3:0]  rvfi_mem_wmask;
    logic [31:0] rvfi_mem_rdata;
    logic [31:0] rvfi_mem_wdata;

    logic        sim_exit_valid;
    logic [31:0] sim_exit_code;

    mailbox #(rvfi_txn) mon2scb = new();
    mailbox #(rvfi_txn) mon2cov = new();
    mailbox #(rvfi_txn) spike2scb = new();
    mailbox #(rvfi_txn) imem2scb = new();
    mailbox #(rvfi_txn) dmem2scb = new();

    initial clk = 0;
    always #5 clk = ~clk;

    initial begin
        rst_n = 0;
        repeat (5) @(posedge clk);
        rst_n = 1;
    end

    rv32i_core #(
        .RESET_VECTOR(RESET_VECTOR)
    ) dut (
        .*
    );

    mem_model mem_model_u (
        .*
    );

    spike_trace_adapter spike_trace_adapter_u (
        .spike2scb(spike2scb)
    );

    rvfi_monitor rvfi_monitor_u (
        .*
    );

    mem_monitor mem_monitor_u (
        .*
    );

    rvfi_scoreboard rvfi_scoreboard_u (
        .*
    );

    rvfi_cov rvfi_cov_u (
        .*
    );

    mem_timing_cov mem_timing_cov_u (
        .*,
        .imem_rsp_valid(mem_model_u.imem_timing_agent.rsp_valid),
        .imem_rsp_latency(mem_model_u.imem_timing_agent.rsp_latency),
        .imem_req_stalled(mem_model_u.imem_timing_agent.req_stalled),
        .dmem_rsp_valid(mem_model_u.dmem_timing_agent.rsp_valid),
        .dmem_rsp_latency(mem_model_u.dmem_timing_agent.rsp_latency),
        .dmem_req_stalled(mem_model_u.dmem_timing_agent.req_stalled)
    );

    bind rv32i_core memory_sva memory_sva_u (
        .*
    );

    bind rv32i_core rvfi_sva rvfi_sva_u (
        .*
    );

    bind rv32i_core whitebox_sva #(
        .RESET_VECTOR(RESET_VECTOR)
    ) whitebox_sva_u (
        .*
    );

endmodule
