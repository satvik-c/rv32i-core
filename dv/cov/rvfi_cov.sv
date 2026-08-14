module rvfi_cov
    import rvfi_pkg::*;
(
    input mailbox #(rvfi_txn) mon2cov
);

    typedef enum { JAL, JALR_0, JALR_1 } jump_type_e;
    typedef enum { SEQ, TAKEN_BRANCH, JAL_PC, JALR_PC } pc_src_e;
    typedef enum { 
        NONE, ILLEGAL_INSN, ECALL, EBREAK, 
        INSN_MISALIGNED, LOAD_MISALIGNED, STORE_MISALIGNED,
        LOAD_FAULT, STORE_FAULT
    } fault_cause_e;

    covergroup cg_rvfi with function sample(rvfi_txn txn, bit is_taken, bit is_backward, jump_type_e jump_type,
                                            bit [5:0] alias_flags, bit[5:0] alu_corners, bit [4:0] shift_amt,
                                            bit [31:0] imm, pc_src_e pc_src, fault_cause_e fault);
        
        cp_instr : coverpoint txn.rvfi_insn[6:0] {
            bins load   = { OP_LOAD };
            bins store  = { OP_STORE };
            bins alu_r  = { OP_ALU_R };
            bins alu_i  = { OP_ALU_I };
            bins branch = { OP_BRANCH };
            bins jalr   = { OP_JALR };
            bins jal    = { OP_JAL };
            bins lui    = { OP_LUI };
            bins auipc  = { OP_AUIPC };
            bins fence  = { OP_FENCE };
            bins system = { OP_SYSTEM };
        }

        cp_instr_format : coverpoint txn.rvfi_insn[6:0] {
            bins r_type = { OP_ALU_R };
            bins i_type = { OP_ALU_I, OP_LOAD, OP_JALR };
            bins s_type = { OP_STORE };
            bins b_type = { OP_BRANCH };
            bins u_type = { OP_LUI, OP_AUIPC };
            bins j_type = { OP_JAL };
        }

        cp_branch_instr : coverpoint txn.rvfi_insn[14:12] iff (txn.rvfi_insn[6:0] == OP_BRANCH) {
            bins beq  = { 3'b000 };
            bins bne  = { 3'b001 };
            bins blt  = { 3'b100 };
            bins bge  = { 3'b101 };
            bins bltu = { 3'b110 };
            bins bgeu = { 3'b111 };
        }

        cp_branch_outcome : coverpoint is_taken iff (txn.rvfi_insn[6:0] == OP_BRANCH) {
            bins taken = { 1 };
            bins not_taken = { 0 };
        }

        cp_branch_dir : coverpoint is_backward iff (txn.rvfi_insn[6:0] == OP_BRANCH) {
            bins backward = { 1 };
            bins forward = { 0 };
        }

        cp_jump_target : coverpoint jump_type iff (txn.rvfi_insn[6:0] inside {OP_JAL, OP_JALR}) {
            bins jal = { JAL };
            bins jalr_aligned = { JALR_0 };
            bins jal_misaligned = { JALR_1 };
        }

        cp_rd : coverpoint txn.rvfi_insn[11:7] iff (!(txn.rvfi_insn[6:0] inside {OP_STORE, OP_BRANCH})) {
            bins x0 = { 5'd0 };
            bins x1 = { 5'd1 };
            bins other = { [5'd2 : 5'd31] };
        }

        cp_aliasing : coverpoint alias_flags iff (!(txn.rvfi_insn[6:0] inside {OP_LUI, OP_JAL})) {
            wildcard bins rd_rs1  = { 6'b1????? };
            wildcard bins rd_rs2  = { 6'b?1???? };
            wildcard bins rs1_rs2 = { 6'b??1??? };
            wildcard bins rs1_x0  = { 6'b???1?? };
            wildcard bins rs2_x0  = { 6'b????1? };
            wildcard bins none    = { 6'b?????1 };
        }

        cp_alu_result : coverpoint alu_corners iff (txn.rvfi_insn[6:0] inside {OP_ALU_I, OP_ALU_R}) {
            wildcard bins zero     = { 6'b1????? };
            wildcard bins all_ones = { 6'b?1???? };
            wildcard bins max_pos  = { 6'b??1??? };
            wildcard bins max_neg  = { 6'b???1?? };
            wildcard bins carry    = { 6'b????1? };
            wildcard bins overflow = { 6'b?????1 };
        }
//                                    opcode              funct3                funct7
        cp_shift_instr : coverpoint {txn.rvfi_insn[6:0], txn.rvfi_insn[14:12], txn.rvfi_insn[31:25]} {
            bins slli = {{ OP_ALU_I, 10'b001_0000000 }};
            bins srli = {{ OP_ALU_I, 10'b101_0000000 }};
            bins srai = {{ OP_ALU_I, 10'b101_0100000 }};
            bins sll  = {{ OP_ALU_R, 10'b001_0000000 }};
            bins srl  = {{ OP_ALU_R, 10'b101_0000000 }};
            bins sra  = {{ OP_ALU_R, 10'b101_0100000 }};
        }

        cp_shift_amt : coverpoint shift_amt iff (
            txn.rvfi_insn[6:0] inside {OP_ALU_I, OP_ALU_R} && txn.rvfi_insn[14:12] inside {3'b001, 3'b101}) {
            bins shift_0   = { 5'd0 };
            bins shift_1   = { 5'd1 };
            bins shift_31  = { 5'd31 };
            bins shift_mid = { [5'd2 : 5'd30]};
        }

        cp_imm_corners : coverpoint imm iff (!(txn.rvfi_insn[6:0] inside {OP_ALU_R, OP_SYSTEM})) {
            bins zero    = { 32'h0000_0000 };
            bins pos_1[] = { 32'h0000_0001, 32'h0000_0002, 32'h0000_1000 };
            bins neg_1[] = { 32'hFFFF_FFFF, 32'hFFFF_FFFE, 32'hFFFF_F000 }; 
            bins max_I_S = { 32'h0000_07FF }; // 2047
            bins min_I_S = { 32'hFFFF_F800 }; // -2048
            bins max_B   = { 32'h0000_0FFE }; // 4094
            bins min_B   = { 32'hFFFF_F000 }; // -4096
            bins max_J   = { 32'h000F_FFFE }; // 1048574
            bins min_J   = { 32'hFFF0_0000 }; // -1048576
            bins max_U   = { 32'h7FFF_F000 };
            bins min_U   = { 32'h8000_0000 };
        }

        cp_ls_width : coverpoint txn.rvfi_insn[13:12] iff (txn.rvfi_insn[6:0] inside {OP_LOAD, OP_STORE}) {
            bins b = { 2'b00 };
            bins h = { 2'b01 };
            bins w = { 2'b10 };
        }

        cp_byte_offset : coverpoint txn.rvfi_mem_addr[1:0] iff (txn.rvfi_insn[6:0] inside {OP_LOAD, OP_STORE}) {
            bins offset_0 = { 2'd0 };
            bins offset_1 = { 2'd1 };
            bins offset_2 = { 2'd2 };
            bins offset_3 = { 2'd3 };
        }

        cp_load_ext : coverpoint txn.rvfi_insn[14] iff (txn.rvfi_insn[6:0] == OP_LOAD && txn.rvfi_insn[13:12] != 2'b10) {
            bins signed_ext   = { 0 };
            bins unsigned_ext = { 1 };
        }

        cp_wstrb : coverpoint txn.rvfi_mem_wmask iff (txn.rvfi_insn[6:0] == OP_STORE) {
            bins b[] = { 4'b0001, 4'b0010, 4'b0100, 4'b1000 };
            bins h[] = { 4'b0011, 4'b1100 };
            bins w   = { 4'b1111 };
        }

        cp_pc_src : coverpoint pc_src {
            bins seq = { SEQ };
            bins taken_branch = { TAKEN_BRANCH };
            bins jal = { JAL_PC };
            bins jalr = { JALR_PC };
        }

        cp_fault : coverpoint fault iff (txn.rvfi_trap) {
            bins illegal_insn = { ILLEGAL_INSN };
            bins ecall = { ECALL };
            bins ebreak = { EBREAK };
            bins insn_misaligned = { INSN_MISALIGNED };
            bins load_misaligned = { LOAD_MISALIGNED };
            bins store_misaligned = { STORE_MISALIGNED };
            bins load_fault = { LOAD_FAULT };
            bins store_fault = { STORE_FAULT };
        }

    endgroup

    cg_rvfi cg = new();

    initial begin
        rvfi_txn txn;
        bit is_taken;
        bit is_backward;
        jump_type_e jump_type;
        bit [5:0] alias_flags;
        bit [31:0] op_a, op_b;
        bit [32:0] sum;
        bit [5:0] alu_corners;
        bit alu_carry, alu_overflow;
        bit [4:0] shift_amt;
        bit [31:0] imm;
        pc_src_e pc_src;
        fault_cause_e fault;

        forever begin
            mon2cov.get(txn);

            is_taken = (txn.rvfi_pc_wdata != txn.rvfi_pc_rdata + 4);
            is_backward = (txn.rvfi_pc_wdata < txn.rvfi_pc_rdata);
            if (txn.rvfi_insn[6:0] == OP_JAL) begin
                jump_type = JAL;
            end else if (txn.rvfi_insn[6:0] == OP_JALR) begin
                if (txn.rvfi_insn[20] ^ txn.rvfi_rs1_rdata[0]) begin
                    jump_type = JALR_1;
                end else begin
                    jump_type = JALR_0;
                end
            end
            alias_flags[5] = (txn.rvfi_rd_addr == txn.rvfi_rs1_addr) && (txn.rvfi_rd_addr != 0);
            alias_flags[4] = (txn.rvfi_rd_addr == txn.rvfi_rs2_addr) && (txn.rvfi_rd_addr != 0);
            alias_flags[3] = (txn.rvfi_rs1_addr == txn.rvfi_rs2_addr) && (txn.rvfi_rs1_addr != 0);
            alias_flags[2] = (txn.rvfi_rs1_addr == 0);
            alias_flags[1] = (txn.rvfi_rs2_addr == 0);
            alias_flags[0] = (alias_flags[5:1] == 5'b00000);

            op_a = txn.rvfi_rs1_rdata;
            if (txn.rvfi_insn[6:0] == OP_ALU_R) begin
                op_b = txn.rvfi_rs2_rdata;
            end else if (txn.rvfi_insn[6:0] == OP_ALU_I) begin
                op_b = {{20{txn.rvfi_insn[31]}}, txn.rvfi_insn[31:20]};
            end
            
            sum = {1'b0, op_a} + {1'b0, op_b};
            alu_carry = sum[32];
            alu_overflow = (op_a[31] == op_b[31]) && (sum[31] != op_a[31]);
            
            alu_corners[5] = (txn.rvfi_rd_wdata == 32'h0000_0000);
            alu_corners[4] = (txn.rvfi_rd_wdata == 32'hFFFF_FFFF);
            alu_corners[3] = (txn.rvfi_rd_wdata == 32'h7FFF_FFFF);
            alu_corners[2] = (txn.rvfi_rd_wdata == 32'h8000_0000);
            alu_corners[1] = alu_carry;
            alu_corners[0] = alu_overflow;

            if (txn.rvfi_insn[6:0] == OP_ALU_R) begin
                shift_amt = txn.rvfi_rs2_rdata[4:0];
            end else if (txn.rvfi_insn[6:0] == OP_ALU_I) begin
                shift_amt = txn.rvfi_insn[24:20];
            end
            
            if (txn.rvfi_insn[6:0] inside {OP_ALU_I, OP_LOAD, OP_JALR}) begin
                imm = {{20{txn.rvfi_insn[31]}}, txn.rvfi_insn[31:20]};
            end else if (txn.rvfi_insn[6:0] == OP_STORE) begin
                imm = {{20{txn.rvfi_insn[31]}}, txn.rvfi_insn[31:25], txn.rvfi_insn[11:7]};
            end else if (txn.rvfi_insn[6:0] == OP_BRANCH) begin
                imm = {{20{txn.rvfi_insn[31]}}, txn.rvfi_insn[7], txn.rvfi_insn[30:25], txn.rvfi_insn[11:8], 1'b0};
            end else if (txn.rvfi_insn[6:0] == OP_JAL) begin
                imm = {{12{txn.rvfi_insn[31]}}, txn.rvfi_insn[19:12], txn.rvfi_insn[20], txn.rvfi_insn[30:21], 1'b0};
            end else if (txn.rvfi_insn[6:0] inside {OP_LUI, OP_AUIPC}) begin
                imm = {txn.rvfi_insn[31:12], 12'b0};
            end else begin
                imm = 32'b0;
            end
            
            if (txn.rvfi_insn[6:0] == OP_JAL) pc_src = JAL_PC;
            else if (txn.rvfi_insn[6:0] == OP_JALR) pc_src = JALR_PC;
            else if (txn.rvfi_insn[6:0] == OP_BRANCH && is_taken) pc_src = TAKEN_BRANCH;
            else pc_src = SEQ;
            
            fault = NONE;
            if (txn.rvfi_trap) begin
                if (txn.rvfi_insn == 32'h0000_0073) fault = ECALL;
                else if (txn.rvfi_insn == 32'h0010_0073) fault = EBREAK;
                else if (txn.rvfi_insn[6:0] == OP_LOAD) begin
                    if (txn.rvfi_insn[13:12] == 2'b10 && txn.rvfi_mem_addr[1:0] != 2'b00) fault = LOAD_MISALIGNED;
                    else if (txn.rvfi_insn[13:12] == 2'b01 && txn.rvfi_mem_addr[0] != 1'b0) fault = LOAD_MISALIGNED;
                    else fault = LOAD_FAULT;
                end else if (txn.rvfi_insn[6:0] == OP_STORE) begin
                    if (txn.rvfi_insn[13:12] == 2'b10 && txn.rvfi_mem_addr[1:0] != 2'b00) fault = STORE_MISALIGNED;
                    else if (txn.rvfi_insn[13:12] == 2'b01 && txn.rvfi_mem_addr[0] != 1'b0) fault = STORE_MISALIGNED;
                    else fault = STORE_FAULT;
                end else if (txn.rvfi_insn[6:0] inside {OP_JAL, OP_JALR, OP_BRANCH}) begin
                    fault = INSN_MISALIGNED;
                end else begin
                    fault = ILLEGAL_INSN;
                end
            end

            if (!txn.is_sim_ctrl()) begin
                cg.sample(txn, is_taken, is_backward, jump_type, alias_flags, alu_corners, shift_amt,
                            imm, pc_src, fault);
            end
        end
    end

endmodule
