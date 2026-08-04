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

    logic [31:0] imem [64];
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

        #350;

        // Comprehensive Rung 2 Assertions
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

        $finish;
    end

endmodule
