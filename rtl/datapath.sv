module datapath
    import core_pkg::*;
(
    input logic clk,
    input logic rst_n,

    input logic reg_write,
    input logic alu_src,
    input alu_op_e alu_op,
    input imm_src_e imm_src,
    input result_src_e result_src,
    input logic branch,
    input logic jump,
    input logic jalr,
    input logic illegal_instr,
    input logic stall,
    output logic misaligned_access,
    output logic misaligned_fetch,

    output logic [31:0] pc,
    input logic [31:0] instr,
    output logic [31:0] alu_result,
    output logic [31:0] write_data,
    output logic [3:0] wstrb,
    input logic [31:0] read_data,

    // Ports needed for RVFI
    output logic [31:0] src_a_rvfi,
    output logic [31:0] rd2_data_rvfi,
    output logic [31:0] result_rvfi,
    output logic [31:0] pc_next_rvfi
);

    logic [31:0] src_a;
    assign src_a_rvfi = src_a;
    logic [31:0] src_b;
    logic [31:0] imm_ext;
    logic [31:0] result;
    assign result_rvfi = result;

    logic [31:0] pc_next;
    assign pc_next_rvfi = pc_next;
    logic take_branch;

    logic [31:0] rd2_data;
    assign rd2_data_rvfi = rd2_data;
    logic [31:0] lsu_result;

    assign misaligned_fetch = (pc_next[1:0] != 2'b00);
    assign src_b = (alu_src) ? imm_ext : rd2_data;
    
    always_comb begin
        if (result_src == RESULT_ALU) result = alu_result;
        else if (result_src == RESULT_MEM) result = lsu_result;
        else if (result_src == RESULT_PC4) result = pc + 32'd4;
        else if (result_src == RESULT_AUIPC) result = alu_result + pc;
        else result = 32'd0;
    end

    always_comb begin
        if (jalr) pc_next = (src_a + imm_ext) & ~32'd1;
        else if ((branch && take_branch) || jump) pc_next = pc + imm_ext;
        else pc_next = pc + 32'd4;
    end

    always_ff @(posedge clk) begin
        if (!rst_n) pc <= 32'h8000_0000;
        else if (!illegal_instr && !stall) pc <= pc_next;
    end

    alu alu_u (
        .src_a(src_a),
        .src_b(src_b),
        .alu_op(alu_op),
        .result(alu_result),
        .zero(),
        .sign()
    );

    imm_gen imm_gen_u (
        .instr(instr[31:7]),
        .imm_src(imm_src),
        .imm_ext(imm_ext)
    );

    reg_file reg_file_u (
        .clk(clk),
        .a1(instr[19:15]),
        .a2(instr[24:20]),
        .a3(instr[11:7]),
        .we3(reg_write && !stall),
        .wd3(result),
        .rd1(src_a),
        .rd2(rd2_data)
    );

    branch_logic branch_logic_u (
        .funct3(instr[14:12]),
        .src_a(src_a),
        .src_b(rd2_data),
        .take_branch(take_branch)
    );

    lsu lsu_u (
        .funct3(instr[14:12]),
        .addr(alu_result),
        .rs2_data(rd2_data),
        .dmem_wdata(write_data),
        .dmem_wstrb(wstrb),
        .dmem_rdata(read_data),
        .result_data(lsu_result),
        .misaligned_access(misaligned_access)
    );

endmodule
