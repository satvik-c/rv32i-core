module rv32i_core
    import core_pkg::*;
(
    input logic clk,
    input logic rst_n,

    output logic core_halted,

    output logic [31:0] pc,
    input logic [31:0] instr,
    output logic [31:0] alu_result,
    output logic [31:0] write_data,
    output logic [3:0] wstrb,
    input logic [31:0] read_data,
    output logic mem_write
);

    logic reg_write;
    logic alu_src;
    alu_op_e alu_op;
    imm_src_e imm_src;
    result_src_e result_src;
    logic branch;
    logic jump;
    logic jalr;
    logic illegal_instr;

    assign core_halted = illegal_instr;

    controller controller_u (
        .op(instr[6:0]),
        .funct3(instr[14:12]),
        .funct7_5(instr[30]),
        .op_5(instr[5]),
        .reg_write(reg_write),
        .mem_write(mem_write),
        .alu_src(alu_src),
        .alu_op(alu_op),
        .imm_src(imm_src),
        .result_src(result_src),
        .branch(branch),
        .jump(jump),
        .jalr(jalr),
        .illegal_instr(illegal_instr)
    );

    datapath datapath_u (
        .clk(clk),
        .rst_n(rst_n),
        .reg_write(reg_write),
        .alu_src(alu_src),
        .alu_op(alu_op),
        .imm_src(imm_src),
        .result_src(result_src),
        .pc(pc),
        .instr(instr),
        .alu_result(alu_result),
        .write_data(write_data),
        .wstrb(wstrb),
        .read_data(read_data),
        .branch(branch),
        .jump(jump),
        .jalr(jalr),
        .illegal_instr(illegal_instr)
    );

endmodule
