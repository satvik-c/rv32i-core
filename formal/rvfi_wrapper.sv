module rvfi_wrapper (
    input         clock,
    input         reset,
    `RVFI_OUTPUTS
);

    // System controls
    logic rst_n = !reset;

    // Instruction Memory Port
    logic        imem_req_valid;
    (* anyseq *) logic imem_req_ready;
    logic [31:0] imem_req_addr;
    (* anyseq *) logic imem_rsp_valid;
    (* anyseq *) logic imem_rsp_error;
    (* anyseq *) logic [31:0] imem_rsp_rdata;

    // Data Memory Port
    logic        dmem_req_valid;
    (* anyseq *) logic dmem_req_ready;
    logic [31:0] dmem_req_addr;
    logic        dmem_req_we;
    logic [3:0]  dmem_req_wstrb;
    logic [31:0] dmem_req_wdata;
    (* anyseq *) logic dmem_rsp_valid;
    (* anyseq *) logic dmem_rsp_error;
    (* anyseq *) logic [31:0] dmem_rsp_rdata;

    logic        core_halted;

    // Core Instance
    rv32i_core #(
        .RESET_VECTOR(32'h8000_0000)
    ) core (
        .clk(clock),
        .rst_n(rst_n),
        .core_halted(core_halted),

        .imem_req_valid(imem_req_valid),
        .imem_req_ready(imem_req_ready),
        .imem_req_addr (imem_req_addr),
        .imem_rsp_valid(imem_rsp_valid),
        .imem_rsp_error(imem_rsp_error),
        .imem_rsp_rdata(imem_rsp_rdata),

        .dmem_req_valid(dmem_req_valid),
        .dmem_req_ready(dmem_req_ready),
        .dmem_req_addr (dmem_req_addr),
        .dmem_req_we   (dmem_req_we),
        .dmem_req_wstrb(dmem_req_wstrb),
        .dmem_req_wdata(dmem_req_wdata),
        .dmem_rsp_valid(dmem_rsp_valid),
        .dmem_rsp_error(dmem_rsp_error),
        .dmem_rsp_rdata(dmem_rsp_rdata),

        .rvfi_valid    (rvfi_valid),
        .rvfi_order    (rvfi_order),
        .rvfi_insn     (rvfi_insn),
        .rvfi_trap     (rvfi_trap),
        .rvfi_halt     (rvfi_halt),
        .rvfi_intr     (rvfi_intr),
        .rvfi_mode     (rvfi_mode),
        .rvfi_ixl      (rvfi_ixl),
        .rvfi_rs1_addr (rvfi_rs1_addr),
        .rvfi_rs2_addr (rvfi_rs2_addr),
        .rvfi_rs1_rdata(rvfi_rs1_rdata),
        .rvfi_rs2_rdata(rvfi_rs2_rdata),
        .rvfi_rd_addr  (rvfi_rd_addr),
        .rvfi_rd_wdata (rvfi_rd_wdata),
        .rvfi_pc_rdata (rvfi_pc_rdata),
        .rvfi_pc_wdata (rvfi_pc_wdata),
        .rvfi_mem_addr (rvfi_mem_addr),
        .rvfi_mem_rmask(rvfi_mem_rmask),
        .rvfi_mem_wmask(rvfi_mem_wmask),
        .rvfi_mem_rdata(rvfi_mem_rdata),
        .rvfi_mem_wdata(rvfi_mem_wdata)
    );

`ifdef RISCV_FORMAL
    // -------------------------------------------------------------------------
    // Memory Abstraction / Contract (MAS 6)
    // -------------------------------------------------------------------------

    logic imem_inflight;
    always_ff @(posedge clock) begin
        if (reset) begin
            imem_inflight <= 0;
        end else begin
            if (imem_req_valid && imem_req_ready) begin
                imem_inflight <= 1;
            end
            if (imem_rsp_valid) begin
                imem_inflight <= 0;
            end
        end
    end

    logic dmem_inflight;
    always_ff @(posedge clock) begin
        if (reset) begin
            dmem_inflight <= 0;
        end else begin
            if (dmem_req_valid && dmem_req_ready) begin
                dmem_inflight <= 1;
            end
            if (dmem_rsp_valid) begin
                dmem_inflight <= 0;
            end
        end
    end

    // Restrict responses to only when a request is inflight
    always_comb begin
        if (!imem_inflight && !(imem_req_valid && imem_req_ready)) begin
            assume(imem_rsp_valid == 0);
        end
        if (!dmem_inflight && !(dmem_req_valid && dmem_req_ready)) begin
            assume(dmem_rsp_valid == 0);
        end
    end

    // Bound req-to-resp latency: unconstrained stalls make liveness unprovable
    localparam MAX_MEM_LATENCY = 8;

    logic [3:0] imem_wait;
    always_ff @(posedge clock) begin
        if (reset || imem_rsp_valid) imem_wait <= 0;
        else if (imem_req_valid || imem_inflight) imem_wait <= imem_wait + 1;
    end
    always_comb assume(imem_wait < MAX_MEM_LATENCY);

    logic [3:0] dmem_wait;
    always_ff @(posedge clock) begin
        if (reset || dmem_rsp_valid) dmem_wait <= 0;
        else if (dmem_req_valid || dmem_inflight) dmem_wait <= dmem_wait + 1;
    end
    always_comb assume(dmem_wait < MAX_MEM_LATENCY);

    // Access faults are out of scope here (see vPlan 7/10); keep memory fault-free
    always_comb begin
        assume(imem_rsp_error == 0);
        assume(dmem_rsp_error == 0);
    end

    // Assume requests don't change while waiting for ready (rule 2)
    always_ff @(posedge clock) begin
        if (!reset && $past(imem_req_valid) && !$past(imem_req_ready)) begin
            assume(imem_req_valid == 1);
            assume(imem_req_addr == $past(imem_req_addr));
        end
        
        if (!reset && $past(dmem_req_valid) && !$past(dmem_req_ready)) begin
            assume(dmem_req_valid == 1);
            assume(dmem_req_addr  == $past(dmem_req_addr));
            assume(dmem_req_we    == $past(dmem_req_we));
            assume(dmem_req_wstrb == $past(dmem_req_wstrb));
            assume(dmem_req_wdata == $past(dmem_req_wdata));
        end
    end
`endif

endmodule
