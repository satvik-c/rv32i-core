module rvfi_monitor
    import rvfi_pkg::*;
(
    input logic         clk,
    input logic         rst_n,

    input logic         rvfi_valid,
    input logic [63:0]  rvfi_order,
    input logic [31:0]  rvfi_insn,
    input logic         rvfi_trap,
    input logic         rvfi_halt,
    input logic         rvfi_intr,
    input logic [1:0]   rvfi_mode,
    input logic [1:0]   rvfi_ixl,
    input logic [4:0]   rvfi_rs1_addr,
    input logic [4:0]   rvfi_rs2_addr,
    input logic [31:0]  rvfi_rs1_rdata,
    input logic [31:0]  rvfi_rs2_rdata,
    input logic [4:0]   rvfi_rd_addr,
    input logic [31:0]  rvfi_rd_wdata,
    input logic [31:0]  rvfi_pc_rdata,
    input logic [31:0]  rvfi_pc_wdata,
    input logic [31:0]  rvfi_mem_addr,
    input logic [3:0]   rvfi_mem_rmask,
    input logic [3:0]   rvfi_mem_wmask,
    input logic [31:0]  rvfi_mem_rdata,
    input logic [31:0]  rvfi_mem_wdata,

    input mailbox #(rvfi_txn) mon2scb,
    input mailbox #(rvfi_txn) mon2cov
);

    always_ff @(posedge clk) begin
        if (rst_n && rvfi_valid) begin
            automatic rvfi_txn txn = new();
            txn.rvfi_valid     = rvfi_valid;
            txn.rvfi_order     = rvfi_order;
            txn.rvfi_insn      = rvfi_insn;
            txn.rvfi_trap      = rvfi_trap;
            txn.rvfi_halt      = rvfi_halt;
            txn.rvfi_intr      = rvfi_intr;
            txn.rvfi_mode      = rvfi_mode;
            txn.rvfi_ixl       = rvfi_ixl;
            txn.rvfi_rs1_addr  = rvfi_rs1_addr;
            txn.rvfi_rs2_addr  = rvfi_rs2_addr;
            txn.rvfi_rs1_rdata = rvfi_rs1_rdata;
            txn.rvfi_rs2_rdata = rvfi_rs2_rdata;
            txn.rvfi_rd_addr   = rvfi_rd_addr;
            txn.rvfi_rd_wdata  = rvfi_rd_wdata;
            txn.rvfi_pc_rdata  = rvfi_pc_rdata;
            txn.rvfi_pc_wdata  = rvfi_pc_wdata;
            txn.rvfi_mem_addr  = rvfi_mem_addr;
            txn.rvfi_mem_rmask = rvfi_mem_rmask;
            txn.rvfi_mem_wmask = rvfi_mem_wmask;
            txn.rvfi_mem_rdata = rvfi_mem_rdata;
            txn.rvfi_mem_wdata = rvfi_mem_wdata;
            mon2scb.put(txn);
            mon2cov.put(txn);
        end
    end

endmodule
