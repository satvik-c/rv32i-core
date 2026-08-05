module alu_dec
    import core_pkg::*;
(
    input alu_force_e alu_force,
    input logic [2:0] funct3,
    input logic funct7_5,
    input logic op_5,
    output alu_op_e alu_op
);

    always_comb begin
        case (alu_force)
            ALU_FORCE_ADD: alu_op = ALU_ADD;
            ALU_FUNCT_DECODE: begin
                casez ({funct3, funct7_5, op_5})
                    5'b000_?_0, 5'b000_0_1: alu_op = ALU_ADD;
                    5'b000_1_1: alu_op = ALU_SUB;
                    5'b001_0_?: alu_op = ALU_SLL;
                    5'b010_?_?: alu_op = ALU_SLT;
                    5'b011_?_?: alu_op = ALU_SLTU;
                    5'b100_?_?: alu_op = ALU_XOR;
                    5'b101_0_?: alu_op = ALU_SRL;
                    5'b101_1_?: alu_op = ALU_SRA;
                    5'b110_?_?: alu_op = ALU_OR;
                    5'b111_?_?: alu_op = ALU_AND;
                    default: alu_op = ALU_ADD;
                endcase
            end
            ALU_FORCE_SRCB: alu_op = ALU_SRCB;
            default: alu_op = ALU_ADD;
        endcase
    end

endmodule
