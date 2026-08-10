module controller
    import core_pkg::*;
(
    input logic [6:0] op,
    input logic [2:0] funct3,
    input logic funct7_5,
    input logic funct7_0,
    input logic op_5,
    output logic reg_write,
    output logic mem_write,
    output logic alu_src,
    output alu_op_e alu_op,
    output imm_src_e imm_src,
    output result_src_e result_src,
    output logic branch,
    output logic jump,
    output logic jalr,
    output logic illegal_instr
);

    alu_force_e alu_force;
    logic illegal_alu_op;
    logic illegal_opcode;

    assign illegal_instr = illegal_alu_op || illegal_opcode;

    main_dec main_dec_u (
        .op(op),
        .reg_write(reg_write),
        .mem_write(mem_write),
        .alu_src(alu_src),
        .alu_force(alu_force),
        .imm_src(imm_src),
        .result_src(result_src),
        .branch(branch),
        .jump(jump),
        .jalr(jalr),
        .illegal_opcode(illegal_opcode)
    );

    alu_dec alu_dec_u (
        .alu_force(alu_force),
        .funct3(funct3),
        .funct7_5(funct7_5),
        .funct7_0(funct7_0),
        .op_5(op_5),
        .alu_op(alu_op),
        .illegal_alu_op(illegal_alu_op)
    );

endmodule
