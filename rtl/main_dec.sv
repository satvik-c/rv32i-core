module main_dec
    import core_pkg::*;
(
    input logic [6:0] op,
    output logic reg_write,
    output logic mem_write,
    output logic alu_src,           // 0 = register, 1 = immediate
    output alu_force_e alu_force,
    output imm_src_e imm_src,
    output logic result_src,        // 0 = alu, 1 = memory
    output logic branch
);

    always_comb begin
        reg_write = 1'b0;
        mem_write = 1'b0;
        alu_src = 1'b0;
        result_src = 1'b0;
        imm_src = IMM_I;
        alu_force = ALU_FORCE_ADD;
        branch = 1'b0;

        case (op)
            OP_LOAD: begin
                reg_write = 1'b1;
                alu_src = 1'b1;
                result_src = 1'b1;
                imm_src = IMM_I;
                alu_force = ALU_FORCE_ADD;
            end
            OP_STORE: begin
                mem_write = 1'b1;
                alu_src = 1'b1;
                imm_src = IMM_S;
                alu_force = ALU_FORCE_ADD;
            end
            OP_ALU_R: begin
                reg_write = 1'b1;
                alu_force = ALU_FUNCT_DECODE;
            end
            OP_ALU_I: begin
                reg_write = 1'b1;
                alu_src = 1'b1;
                imm_src = IMM_I;
                alu_force = ALU_FUNCT_DECODE;
            end
            OP_BRANCH: begin
                imm_src = IMM_B;
                branch = 1'b1;
            end
            default: ;
        endcase
    end

endmodule
