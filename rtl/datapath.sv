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

    output logic [31:0] pc,
    input logic [31:0] instr,
    output logic [31:0] alu_result,
    output logic [31:0] write_data,
    input logic [31:0] read_data
);

    logic [31:0] src_a;
    logic [31:0] src_b;
    logic [31:0] imm_ext;
    logic [31:0] result;

    logic [31:0] pc_next;
    logic take_branch;

    assign src_b = (alu_src) ? imm_ext : write_data;
    
    always_comb begin
        if (result_src == RESULT_ALU) result = alu_result;
        else if (result_src == RESULT_MEM) result = read_data;
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
        else pc <= pc_next;
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
        .we3(reg_write),
        .wd3(result),
        .rd1(src_a),
        .rd2(write_data)
    );

    branch_logic branch_logic_instance (
        .funct3(instr[14:12]),
        .src_a(src_a),
        .src_b(write_data),
        .take_branch(take_branch)
    );

endmodule
