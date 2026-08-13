module rvfi_sva
    import rvfi_pkg::*;
(
    input logic clk,
    input logic rst_n,

    input logic        rvfi_valid,
    input logic [63:0] rvfi_order,
    input logic [31:0] rvfi_insn,
    input logic        rvfi_trap,
    input logic        rvfi_halt,
    input logic        rvfi_intr,
    input logic [1:0]  rvfi_mode,
    input logic [1:0]  rvfi_ixl,
    input logic [4:0]  rvfi_rs1_addr,
    input logic [4:0]  rvfi_rs2_addr,
    input logic [31:0] rvfi_rs1_rdata,
    input logic [31:0] rvfi_rs2_rdata,
    input logic [4:0]  rvfi_rd_addr,
    input logic [31:0] rvfi_rd_wdata,
    input logic [31:0] rvfi_pc_rdata,
    input logic [31:0] rvfi_pc_wdata,
    input logic [31:0] rvfi_mem_addr,
    input logic [3:0]  rvfi_mem_rmask,
    input logic [3:0]  rvfi_mem_wmask,
    input logic [31:0] rvfi_mem_rdata,
    input logic [31:0] rvfi_mem_wdata,

    input logic        imem_req_valid,
    input logic        imem_req_ready,
    input logic        imem_rsp_valid,
    input logic        dmem_req_valid,
    input logic        dmem_req_ready,
    input logic        dmem_rsp_valid
);

    default clocking @(posedge clk); endclocking
    default disable iff (!rst_n);

    // A1
    A1: assert property (rvfi_valid && $past(rst_n) |-> rvfi_order == ($past(rvfi_order) + 1));

    // A2
    A2: assert property (rvfi_valid |-> rvfi_pc_rdata[1:0] == 2'b00);

    // A3
    logic branch_taken;
    always_comb begin
        case (rvfi_insn[14:12])
            3'b000: branch_taken = (rvfi_rs1_rdata == rvfi_rs2_rdata);
            3'b001: branch_taken = (rvfi_rs1_rdata != rvfi_rs2_rdata);
            3'b100: branch_taken = ($signed(rvfi_rs1_rdata) < $signed(rvfi_rs2_rdata));
            3'b101: branch_taken = ($signed(rvfi_rs1_rdata) >= $signed(rvfi_rs2_rdata));
            3'b110: branch_taken = (rvfi_rs1_rdata < rvfi_rs2_rdata);
            3'b111: branch_taken = (rvfi_rs1_rdata >= rvfi_rs2_rdata);
            default: branch_taken = 1'b0;
        endcase
    end

    wire is_jal = (rvfi_insn[6:0] == OP_JAL);
    wire is_jalr = (rvfi_insn[6:0] == OP_JALR);
    wire is_branch = (rvfi_insn[6:0] == OP_BRANCH);

    A3: assert property (rvfi_valid && !rvfi_trap && !is_jal && !is_jalr && !(is_branch && branch_taken)
                            |-> rvfi_pc_wdata == rvfi_pc_rdata + 4);

    // A4
    A4: assert property (rvfi_valid && rvfi_rd_addr == 5'b0 |-> rvfi_rd_wdata == 32'b0);

    // A5
    A5_RS1: assert property (rvfi_valid && rvfi_rs1_addr == 5'b0 |-> rvfi_rs1_rdata == 32'b0);
    A5_RS2: assert property (rvfi_valid && rvfi_rs2_addr == 5'b0 |-> rvfi_rs2_rdata == 32'b0);

    // A6
    wire is_store = (rvfi_insn[6:0] == OP_STORE);
    wire is_fence = (rvfi_insn[6:0] == OP_FENCE);

    A6: assert property (rvfi_valid && (is_branch || is_store || is_fence)
                            |-> rvfi_rd_addr == 32'b0);

    // A7
    wire is_load = (rvfi_insn[6:0] == OP_LOAD);

    A7_1: assert property (rvfi_valid && !is_load && !is_store 
                            |-> rvfi_mem_rmask == 4'b0 && rvfi_mem_wmask == 4'b0);
    A7_2: assert property (rvfi_valid |-> !(rvfi_mem_rmask != 4'b0 && rvfi_mem_wmask != 4'b0));

    // A8
    A8: assert property (rvfi_valid && (rvfi_mem_rmask != 4'b0 || rvfi_mem_wmask != 4'b0)
                            |-> rvfi_mem_addr[1:0] == 2'b0);

    // A9
    A9: assert property (rvfi_valid && rvfi_trap
                            |-> rvfi_rd_addr == 5'b0 && rvfi_mem_rmask == 4'b0 && rvfi_mem_wmask == 4'b0);

    // A10
    logic halted;
    always_ff @(posedge clk) begin
        if (!rst_n) halted <= 1'b0;
        else if (rvfi_valid && rvfi_halt) halted <= 1'b1;
    end

    A10: assert property (halted |-> !rvfi_valid);

    // A11
    logic imem_outstanding, dmem_outstanding;
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            imem_outstanding <= 1'b0;
            dmem_outstanding <= 1'b0;
        end else begin
            imem_outstanding <= !imem_rsp_valid && ((imem_req_valid && imem_req_ready) || imem_outstanding);
            dmem_outstanding <= !dmem_rsp_valid && ((dmem_req_valid && dmem_req_ready) || dmem_outstanding);
        end
    end

    A11: assert property (rvfi_valid |->
        !(imem_outstanding && !imem_rsp_valid) && !(dmem_outstanding && !dmem_rsp_valid));

    // A12
    A12: assert property (rvfi_valid |-> !$isunknown({
        rvfi_order, rvfi_insn, rvfi_trap, rvfi_halt, rvfi_intr,
        rvfi_mode, rvfi_ixl, rvfi_rs1_addr, rvfi_rs2_addr, 
        rvfi_rs1_rdata, rvfi_rs2_rdata, rvfi_rd_addr, rvfi_rd_wdata,
        rvfi_pc_rdata, rvfi_pc_wdata, rvfi_mem_addr, rvfi_mem_rmask,
        rvfi_mem_wmask, rvfi_mem_rdata, rvfi_mem_wdata
    }));

endmodule
