module alu
    import core_pkg::*;
(
    input logic [31:0] src_a,
    input logic [31:0] src_b,
    input alu_op_e alu_op,
    output logic [31:0] result,
    output logic zero,
    output logic sign
);

    assign zero = (result == 32'b0);
    assign sign = result[31];

    always_comb begin
        case (alu_op)
            ALU_ADD: result = src_a + src_b;
            ALU_SUB: result = src_a - src_b;
            ALU_SLL: result = src_a << src_b[4:0];
            ALU_SLT: result = {31'b0, ($signed(src_a) < $signed(src_b))};
            ALU_SLTU: result = {31'b0, (src_a < src_b)};
            ALU_XOR: result = src_a ^ src_b;
            ALU_SRL: result = src_a >> src_b[4:0];
            ALU_SRA: result = $signed(src_a) >>> src_b[4:0];
            ALU_OR: result = src_a | src_b;
            ALU_AND: result = src_a & src_b;
            ALU_SRCB: result = src_b;
            default: result = 32'b0;
        endcase
    end

endmodule
