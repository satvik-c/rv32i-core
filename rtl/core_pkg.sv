package core_pkg;

    typedef enum logic [3:0] {
        ALU_ADD,
        ALU_SUB,
        ALU_SLL,
        ALU_SLT,
        ALU_SLTU,
        ALU_XOR,
        ALU_SRL,
        ALU_SRA,
        ALU_OR,
        ALU_AND,
        ALU_SRCB
    } alu_op_e;

    typedef enum logic [1:0] {
        ALU_FORCE_ADD,
        ALU_FUNCT_DECODE,
        ALU_FORCE_SRCB
    } alu_force_e;

    typedef enum logic [2:0] {
        IMM_I,
        IMM_S,
        IMM_B,
        IMM_U,
        IMM_J
    } imm_src_e;

    typedef enum logic [1:0] {
        RESULT_ALU,
        RESULT_MEM,
        RESULT_PC4,
        RESULT_AUIPC
    } result_src_e;

    localparam logic [6:0] OP_LOAD = 7'b0000011;
    localparam logic [6:0] OP_STORE = 7'b0100011;
    localparam logic [6:0] OP_ALU_R = 7'b0110011;
    localparam logic [6:0] OP_ALU_I = 7'b0010011;
    localparam logic [6:0] OP_BRANCH = 7'b1100011;
    localparam logic [6:0] OP_JALR = 7'b1100111;
    localparam logic [6:0] OP_JAL = 7'b1101111;
    localparam logic [6:0] OP_LUI = 7'b0110111;
    localparam logic [6:0] OP_AUIPC = 7'b0010111;

endpackage
