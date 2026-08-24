module mem_monitor
    import rvfi_pkg::*;
(
    input logic        clk,
    input logic        rst_n,

    input logic        imem_req_valid,
    input logic        imem_req_ready,
    input logic [31:0] imem_req_addr,
    input logic        imem_rsp_valid,
    input logic [31:0] imem_rsp_rdata,

    input logic        dmem_req_valid,
    input logic        dmem_req_ready,
    input logic [31:0] dmem_req_addr,
    input logic        dmem_req_we,
    input logic [3:0]  dmem_req_wstrb,
    input logic [31:0] dmem_req_wdata,
    input logic        dmem_rsp_valid,
    input logic [31:0] dmem_rsp_rdata,

    input mailbox #(rvfi_txn) imem2scb,
    input mailbox #(rvfi_txn) dmem2scb
);

    logic [31:0] fetch_pc;

    always_ff @(posedge clk) begin
        if (rst_n) begin
            if (imem_req_valid && imem_req_ready) fetch_pc = imem_req_addr;
            if (imem_rsp_valid) begin
                automatic rvfi_txn txn = new();
                txn.rvfi_pc_rdata = fetch_pc;
                txn.rvfi_insn = imem_rsp_rdata;
                imem2scb.put(txn);
            end
        end
    end

    struct {
        logic [31:0] addr;
        logic we;
        logic [3:0] wstrb;
        logic [31:0] wdata;
    } dmem_req;

    always_ff @(posedge clk) begin
        if (rst_n) begin
            if (dmem_req_valid && dmem_req_ready) begin
                dmem_req.addr = dmem_req_addr;
                dmem_req.we = dmem_req_we;
                dmem_req.wstrb = dmem_req_wstrb;
                dmem_req.wdata = dmem_req_wdata;
            end
            if (dmem_rsp_valid) begin
                automatic rvfi_txn txn = new();
                txn.rvfi_mem_addr = dmem_req.addr;
                txn.rvfi_mem_wmask = dmem_req.we ? dmem_req.wstrb : 4'b0000;
                txn.rvfi_mem_rmask = !dmem_req.we ? 4'b1111 : 4'b0000;
                txn.rvfi_mem_wdata = dmem_req.we ? dmem_req.wdata : 32'b0;
                txn.rvfi_mem_rdata = dmem_rsp_rdata;
                dmem2scb.put(txn);
            end
        end
    end

endmodule
