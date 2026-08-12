package rvfi_pkg;

    localparam logic [31:0] SIM_EXIT = 32'h1000_0000;
    localparam logic [31:0] SIM_EXIT_HI = 32'h1000_0004;
    localparam logic [31:0] SIM_PUTC = 32'h1000_0008;
    localparam logic [31:0] RESET_VECTOR = 32'h8000_0000;

    // Logic to derive byte-lane masks from instruction since Spike doesn't report it
    localparam logic [6:0] OP_LOAD = 7'b0000011;
    localparam logic [6:0] OP_STORE = 7'b0100011;

    function automatic logic [3:0] decode_mask(logic [31:0] insn, logic [31:0] addr);
        logic [6:0] opcode = insn[6:0];
        logic [1:0] width = insn[13:12]; // lower 2 bits of funct3: 00 = byte, 01 = half, 10 = word

        if (!(opcode inside {OP_LOAD, OP_STORE})) return 4'b0000;

        case (width)
            2'b00: return (4'b0001 << addr[1:0]);
            2'b01: return (addr[1] ? 4'b1100 : 4'b0011);
            2'b10: return 4'b1111;
            default: return 4'b0000;
        endcase
    endfunction

    `include "rvfi_txn.sv"

endpackage
