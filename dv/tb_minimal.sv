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

    logic [31:0] imem [16];
    logic [31:0] dmem [16];

    initial begin
        imem[0]  = 32'h00500093; // addi x1, x0, 5      -> x1 = 5
        imem[1]  = 32'h00a00113; // addi x2, x0, 10     -> x2 = 10
        imem[2]  = 32'h00f00193; // addi x3, x0, 15     -> x3 = 15
        imem[3]  = 32'h00208233; // add  x4, x1, x2     -> x4 = 15
        imem[4]  = 32'h003182b3; // add  x5, x3, x3     -> x5 = 30
        imem[5]  = 32'h00428333; // add  x6, x5, x4     -> x6 = 45
        imem[6]  = 32'h00502023; // sw   x5, 0(x0)      -> mem[0] = 30
        imem[7]  = 32'h00602223; // sw   x6, 4(x0)      -> mem[1] = 45
        imem[8]  = 32'h00102423; // sw   x1, 8(x0)      -> mem[2] = 5
        imem[9]  = 32'h00002383; // lw   x7, 0(x0)      -> x7 = 30
        imem[10] = 32'h00402403; // lw   x8, 4(x0)      -> x8 = 45
        imem[11] = 32'h00802483; // lw   x9, 8(x0)      -> x9 = 5
        imem[12] = 32'h00838533; // add  x10, x7, x8    -> x10 = 75
        imem[13] = 32'h009505b3; // add  x11, x10, x9   -> x11 = 80
        imem[14] = 32'h00b02623; // sw   x11, 12(x0)    -> mem[3] = 80
        imem[15] = 32'h00c02603; // lw   x12, 12(x0)    -> x12 = 80
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

        #200;

        assert (dut.datapath_u.reg_file_u.regs[1] == 32'd5)  else $error("Assertion failed: x1 != 5");
        assert (dut.datapath_u.reg_file_u.regs[2] == 32'd10) else $error("Assertion failed: x2 != 10");
        assert (dut.datapath_u.reg_file_u.regs[3] == 32'd15) else $error("Assertion failed: x3 != 15");
        assert (dut.datapath_u.reg_file_u.regs[4] == 32'd15) else $error("Assertion failed: x4 != 15");
        assert (dut.datapath_u.reg_file_u.regs[5] == 32'd30) else $error("Assertion failed: x5 != 30");
        assert (dut.datapath_u.reg_file_u.regs[6] == 32'd45) else $error("Assertion failed: x6 != 45");
        assert (dut.datapath_u.reg_file_u.regs[7] == 32'd30) else $error("Assertion failed: x7 != 30");
        assert (dut.datapath_u.reg_file_u.regs[8] == 32'd45) else $error("Assertion failed: x8 != 45");
        assert (dut.datapath_u.reg_file_u.regs[9] == 32'd5)  else $error("Assertion failed: x9 != 5");
        assert (dut.datapath_u.reg_file_u.regs[10] == 32'd75) else $error("Assertion failed: x10 != 75");
        assert (dut.datapath_u.reg_file_u.regs[11] == 32'd80) else $error("Assertion failed: x11 != 80");
        assert (dut.datapath_u.reg_file_u.regs[12] == 32'd80) else $error("Assertion failed: x12 != 80");

        assert (dmem[0] == 32'd30) else $error("Assertion failed: dmem[0] != 30");
        assert (dmem[1] == 32'd45) else $error("Assertion failed: dmem[1] != 45");
        assert (dmem[2] == 32'd5) else $error("Assertion failed: dmem[2] != 5");
        assert (dmem[3] == 32'd80) else $error("Assertion failed: dmem[3] != 80");

        $finish;
    end

endmodule
