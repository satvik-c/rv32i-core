`timescale 1ns / 1ps

module tb_minimal();

    logic clk;
    logic rst_n;

    logic [31:0] pc;
    logic [31:0] instr;
    logic [31:0] alu_result;
    logic [31:0] write_data;
    logic [31:0] read_data;
    logic mem_write;

    logic [31:0] imem [128];
    logic [31:0] dmem [64];

    initial begin
        imem[0]  = 32'h00f00093; // addi  x1, x0, 15    -> x1  = 15
        imem[1]  = 32'h00a00113; // addi  x2, x0, 10    -> x2  = 10
        imem[2]  = 32'h002081b3; // add   x3, x1, x2    -> x3  = 25
        imem[3]  = 32'h40208233; // sub   x4, x1, x2    -> x4  = 5
        imem[4]  = 32'h00c0f293; // andi  x5, x1, 12    -> x5  = 12
        imem[5]  = 32'h0020f333; // and   x6, x1, x2    -> x6  = 10
        imem[6]  = 32'h00516393; // ori   x7, x2, 5     -> x7  = 15
        imem[7]  = 32'h00526433; // or    x8, x4, x5    -> x8  = 13
        imem[8]  = 32'h00a0c493; // xori  x9, x1, 10    -> x9  = 5
        imem[9]  = 32'h0020c533; // xor   x10, x1, x2   -> x10 = 5
        imem[10] = 32'h00209593; // slli  x11, x1, 2    -> x11 = 60
        imem[11] = 32'h00409633; // sll   x12, x1, x4   -> x12 = 480
        imem[12] = 32'h0025d693; // srli  x13, x11, 2   -> x13 = 15
        imem[13] = 32'h00465733; // srl   x14, x12, x4  -> x14 = 15
        imem[14] = 32'hff600793; // addi  x15, x0, -10  -> x15 = -10
        imem[15] = 32'h4017d813; // srai  x16, x15, 1   -> x16 = -5
        imem[16] = 32'h4047d8b3; // sra   x17, x15, x4  -> x17 = -1
        imem[17] = 32'h0057a913; // slti  x18, x15, 5   -> x18 = 1
        imem[18] = 32'h001229b3; // slt   x19, x4, x1   -> x19 = 1
        imem[19] = 32'h0057ba13; // sltiu x20, x15, 5   -> x20 = 0
        imem[20] = 32'h00f23ab3; // sltu  x21, x4, x15  -> x21 = 1
        imem[21] = 32'h01002023; // sw    x16, 0(x0)    -> mem[0] = -5
        imem[22] = 32'h01102223; // sw    x17, 4(x0)    -> mem[1] = -1
        imem[23] = 32'h00002b03; // lw    x22, 0(x0)    -> x22 = -5
        imem[24] = 32'h00402b83; // lw    x23, 4(x0)    -> x23 = -1

        imem[25] = 32'h00100d93; // addi x27, x0, 1
        imem[26] = 32'h00500c13; // addi x24, x0, 5
        imem[27] = 32'h00500c93; // addi x25, x0, 5
        imem[28] = 32'h03b02423; // sw x27, 40(x0)
        imem[29] = 32'h019c0463; // beq x24, x25, L0 (imm=8)
        imem[30] = 32'h02002423; // sw x0, 40(x0)
        imem[31] = 32'h00500c13; // addi x24, x0, 5
        imem[32] = 32'h00600c93; // addi x25, x0, 6
        imem[33] = 32'h03b02623; // sw x27, 44(x0)
        imem[34] = 32'h019c0463; // beq x24, x25, L1 (imm=8)
        imem[35] = 32'h02002623; // sw x0, 44(x0)
        imem[36] = 32'h00500c13; // addi x24, x0, 5
        imem[37] = 32'h00600c93; // addi x25, x0, 6
        imem[38] = 32'h03b02823; // sw x27, 48(x0)
        imem[39] = 32'h019c1463; // bne x24, x25, L2 (imm=8)
        imem[40] = 32'h02002823; // sw x0, 48(x0)
        imem[41] = 32'h00500c13; // addi x24, x0, 5
        imem[42] = 32'h00500c93; // addi x25, x0, 5
        imem[43] = 32'h03b02a23; // sw x27, 52(x0)
        imem[44] = 32'h019c1463; // bne x24, x25, L3 (imm=8)
        imem[45] = 32'h02002a23; // sw x0, 52(x0)
        imem[46] = 32'hffb00c13; // addi x24, x0, -5
        imem[47] = 32'h00300c93; // addi x25, x0, 3
        imem[48] = 32'h03b02c23; // sw x27, 56(x0)
        imem[49] = 32'h019c4463; // blt x24, x25, L4 (imm=8)
        imem[50] = 32'h02002c23; // sw x0, 56(x0)
        imem[51] = 32'h00300c13; // addi x24, x0, 3
        imem[52] = 32'hffb00c93; // addi x25, x0, -5
        imem[53] = 32'h03b02e23; // sw x27, 60(x0)
        imem[54] = 32'h019c4463; // blt x24, x25, L5 (imm=8)
        imem[55] = 32'h02002e23; // sw x0, 60(x0)
        imem[56] = 32'h00300c13; // addi x24, x0, 3
        imem[57] = 32'hffb00c93; // addi x25, x0, -5
        imem[58] = 32'h05b02023; // sw x27, 64(x0)
        imem[59] = 32'h019c5463; // bge x24, x25, L6 (imm=8)
        imem[60] = 32'h04002023; // sw x0, 64(x0)
        imem[61] = 32'hffb00c13; // addi x24, x0, -5
        imem[62] = 32'h00300c93; // addi x25, x0, 3
        imem[63] = 32'h05b02223; // sw x27, 68(x0)
        imem[64] = 32'h019c5463; // bge x24, x25, L7 (imm=8)
        imem[65] = 32'h04002223; // sw x0, 68(x0)
        imem[66] = 32'h00100c13; // addi x24, x0, 1
        imem[67] = 32'hfff00c93; // addi x25, x0, -1
        imem[68] = 32'h05b02423; // sw x27, 72(x0)
        imem[69] = 32'h019c6463; // bltu x24, x25, L8 (imm=8)
        imem[70] = 32'h04002423; // sw x0, 72(x0)
        imem[71] = 32'hfff00c13; // addi x24, x0, -1
        imem[72] = 32'h00100c93; // addi x25, x0, 1
        imem[73] = 32'h05b02623; // sw x27, 76(x0)
        imem[74] = 32'h019c6463; // bltu x24, x25, L9 (imm=8)
        imem[75] = 32'h04002623; // sw x0, 76(x0)
        imem[76] = 32'hfff00c13; // addi x24, x0, -1
        imem[77] = 32'h00100c93; // addi x25, x0, 1
        imem[78] = 32'h05b02823; // sw x27, 80(x0)
        imem[79] = 32'h019c7463; // bgeu x24, x25, L10 (imm=8)
        imem[80] = 32'h04002823; // sw x0, 80(x0)
        imem[81] = 32'h00100c13; // addi x24, x0, 1
        imem[82] = 32'hfff00c93; // addi x25, x0, -1
        imem[83] = 32'h05b02a23; // sw x27, 84(x0)
        imem[84] = 32'h019c7463; // bgeu x24, x25, L11 (imm=8)
        imem[85] = 32'h04002a23; // sw x0, 84(x0)

        imem[86] = 32'h00c00e6f; // jal x28, SUB (imm=12)
        imem[87] = 32'h3e700f13; // addi x30, x0, 999
        imem[88] = 32'h00c0006f; // jal x0, END (imm=12)
        imem[89] = 32'h30900f93; // addi x31, x0, 777    (SUB:)
        imem[90] = 32'h000e0067; // jalr x0, 0(x28)       (return)
    end

    assign instr = imem[(pc - 32'h8000_0000) >> 2];

    always_ff @(posedge clk) begin
        if (mem_write) dmem[alu_result >> 2] <= write_data;
    end

    assign read_data = dmem[alu_result >> 2];

    rv32i_core dut (
        .*
    );

    initial clk = 0;
    always #5 clk = ~clk;

    initial begin
        rst_n = 0;
        repeat (5) @(posedge clk);
        rst_n = 1;        

        #1000;

        // Comprehensive ALU Assertions
        assert (dut.datapath_u.reg_file_u.regs[1]  == 32'd15)    else $error("Assertion failed: x1 != 15");
        assert (dut.datapath_u.reg_file_u.regs[2]  == 32'd10)    else $error("Assertion failed: x2 != 10");
        assert (dut.datapath_u.reg_file_u.regs[3]  == 32'd25)    else $error("Assertion failed: x3 != 25");
        assert (dut.datapath_u.reg_file_u.regs[4]  == 32'd5)     else $error("Assertion failed: x4 != 5");
        assert (dut.datapath_u.reg_file_u.regs[5]  == 32'd12)    else $error("Assertion failed: x5 != 12");
        assert (dut.datapath_u.reg_file_u.regs[6]  == 32'd10)    else $error("Assertion failed: x6 != 10");
        assert (dut.datapath_u.reg_file_u.regs[7]  == 32'd15)    else $error("Assertion failed: x7 != 15");
        assert (dut.datapath_u.reg_file_u.regs[8]  == 32'd13)    else $error("Assertion failed: x8 != 13");
        assert (dut.datapath_u.reg_file_u.regs[9]  == 32'd5)     else $error("Assertion failed: x9 != 5");
        assert (dut.datapath_u.reg_file_u.regs[10] == 32'd5)     else $error("Assertion failed: x10 != 5");
        assert (dut.datapath_u.reg_file_u.regs[11] == 32'd60)    else $error("Assertion failed: x11 != 60");
        assert (dut.datapath_u.reg_file_u.regs[12] == 32'd480)   else $error("Assertion failed: x12 != 480");
        assert (dut.datapath_u.reg_file_u.regs[13] == 32'd15)    else $error("Assertion failed: x13 != 15");
        assert (dut.datapath_u.reg_file_u.regs[14] == 32'd15)    else $error("Assertion failed: x14 != 15");
        assert (dut.datapath_u.reg_file_u.regs[15] == -32'sd10)  else $error("Assertion failed: x15 != -10");
        assert (dut.datapath_u.reg_file_u.regs[16] == -32'sd5)   else $error("Assertion failed: x16 != -5");
        assert (dut.datapath_u.reg_file_u.regs[17] == -32'sd1)   else $error("Assertion failed: x17 != -1");
        assert (dut.datapath_u.reg_file_u.regs[18] == 32'd1)     else $error("Assertion failed: x18 != 1");
        assert (dut.datapath_u.reg_file_u.regs[19] == 32'd1)     else $error("Assertion failed: x19 != 1");
        assert (dut.datapath_u.reg_file_u.regs[20] == 32'd0)     else $error("Assertion failed: x20 != 0");
        assert (dut.datapath_u.reg_file_u.regs[21] == 32'd1)     else $error("Assertion failed: x21 != 1");
        assert (dut.datapath_u.reg_file_u.regs[22] == -32'sd5)   else $error("Assertion failed: x22 != -5");
        assert (dut.datapath_u.reg_file_u.regs[23] == -32'sd1)   else $error("Assertion failed: x23 != -1");

        assert (dmem[0] == -32'sd5) else $error("Assertion failed: dmem[0] != -5");
        assert (dmem[1] == -32'sd1) else $error("Assertion failed: dmem[1] != -1");

        // Branch Assertions
        assert (dmem[10] == 32'd1) else $error("Assertion failed: dmem[10] != 1 (beq x24=5,x25=5 should be taken)");
        assert (dmem[11] == 32'd0) else $error("Assertion failed: dmem[11] != 0 (beq x24=5,x25=6 should be not taken)");
        assert (dmem[12] == 32'd1) else $error("Assertion failed: dmem[12] != 1 (bne x24=5,x25=6 should be taken)");
        assert (dmem[13] == 32'd0) else $error("Assertion failed: dmem[13] != 0 (bne x24=5,x25=5 should be not taken)");
        assert (dmem[14] == 32'd1) else $error("Assertion failed: dmem[14] != 1 (blt x24=-5,x25=3 should be taken)");
        assert (dmem[15] == 32'd0) else $error("Assertion failed: dmem[15] != 0 (blt x24=3,x25=-5 should be not taken)");
        assert (dmem[16] == 32'd1) else $error("Assertion failed: dmem[16] != 1 (bge x24=3,x25=-5 should be taken)");
        assert (dmem[17] == 32'd0) else $error("Assertion failed: dmem[17] != 0 (bge x24=-5,x25=3 should be not taken)");
        assert (dmem[18] == 32'd1) else $error("Assertion failed: dmem[18] != 1 (bltu x24=1,x25=-1 should be taken)");
        assert (dmem[19] == 32'd0) else $error("Assertion failed: dmem[19] != 0 (bltu x24=-1,x25=1 should be not taken)");
        assert (dmem[20] == 32'd1) else $error("Assertion failed: dmem[20] != 1 (bgeu x24=-1,x25=1 should be taken)");
        assert (dmem[21] == 32'd0) else $error("Assertion failed: dmem[21] != 0 (bgeu x24=1,x25=-1 should be not taken)");

        // jal/jalr Assertions
        assert (dut.datapath_u.reg_file_u.regs[28] == 32'h8000015c) else $error("Assertion failed: x28 (jal link) != 0x8000015c");
        assert (dut.datapath_u.reg_file_u.regs[30] == 32'd999) else $error("Assertion failed: x30 != 999 (did not return from subroutine correctly)");
        assert (dut.datapath_u.reg_file_u.regs[31] == 32'd777) else $error("Assertion failed: x31 != 777 (subroutine body did not execute)");
        assert (dut.datapath_u.reg_file_u.regs[0] == 32'd0) else $error("Assertion failed: x0 != 0 (jal/jalr with rd=x0 must not corrupt regs[0])");

        $finish;
    end

endmodule
