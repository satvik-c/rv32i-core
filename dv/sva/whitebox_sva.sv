module whitebox_sva
    import core_pkg::*;
#(
    parameter RESET_VECTOR = 32'h8000_0000
)
(
    input logic clk,
    input logic rst_n,

    input logic        core_halted,
    input logic        imem_req_valid,
    input logic [31:0] imem_req_addr,
    input logic [31:0] instr_word,
    input logic        dmem_req_valid,
    input logic [31:0] dmem_req_addr,

    input ctrl_t       ctrl,
    input fault_t      fault,

    input logic        reg_file_we,
    input logic        mem_read,
    input logic        pc_en,
    input logic [31:0] pc,
    input logic [31:0] alu_result,
    input logic [31:0] src_a_rvfi,
    input logic [31:0] rd2_data_rvfi,

    input logic        rvfi_valid
);

    default clocking @(posedge clk); endclocking
    default disable iff (!rst_n);

    // W2
    W2_RS1: assert property (instr_word[19:15] == 5'b0 |-> src_a_rvfi == 32'b0);
    W2_RS2: assert property (instr_word[24:20] == 5'b0 |-> rd2_data_rvfi == 32'b0);

    // W3
    W3: assert property (!$isunknown(ctrl.result_src));

    // W4
    W4: assert property (!rvfi_valid |=> !$past(reg_file_we) && $stable(pc));

    // W5
    W5: assert property (!(instr_word[6:0] inside {OP_LOAD, OP_STORE}) |-> !dmem_req_valid);

    // W6
    wire h_access = instr_word[13:12] == 2'b01 && instr_word[6:0] inside {OP_LOAD, OP_STORE};
    wire w_access = instr_word[13:12] == 2'b10 && instr_word[6:0] inside {OP_LOAD, OP_STORE};

    W6_H: assert property (h_access && alu_result[0] != 1'b0 |-> !dmem_req_valid);
    W6_W: assert property (w_access && alu_result[1:0] != 2'b00 |-> !dmem_req_valid);

    // W7
    W7: assert property ($rose(rst_n) |-> (pc == RESET_VECTOR) s_until_with rvfi_valid);

    // W8
    W8: assert property (imem_req_valid |-> imem_req_addr == pc);

    // W9
    wire [6:0] opcode = instr_word[6:0];
    wire [2:0] funct3 = instr_word[14:12];
    wire funct7_0 = instr_word[25];
    wire op_5 = instr_word[5];

    wire opcode_illegal = !(opcode inside {
        OP_LOAD, OP_STORE, OP_ALU_R, OP_ALU_I, OP_BRANCH, OP_JALR, OP_JAL,
        OP_LUI, OP_AUIPC, OP_FENCE}); // no OP_SYSTEM since its illegal for now

    wire alu_op_illegal = (opcode inside {OP_ALU_R, OP_ALU_I}) &&
        funct7_0 && (op_5 || funct3 inside {3'b001, 3'b101});

    W9: assert property (imem_req_valid |->
        (opcode_illegal || alu_op_illegal) <-> fault.illegal_instr);

    // W10
    W10: assert property ($rose(core_halted) |-> core_halted until !rst_n);

endmodule
