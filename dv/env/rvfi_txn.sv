class rvfi_txn;
    import rvfi_pkg::*;

    bit        rvfi_valid;
    bit [63:0] rvfi_order;
    bit [31:0] rvfi_insn;
    bit        rvfi_trap;
    bit        rvfi_halt;
    bit        rvfi_intr;
    bit [1:0]  rvfi_mode;
    bit [1:0]  rvfi_ixl;
    bit [4:0]  rvfi_rs1_addr;
    bit [4:0]  rvfi_rs2_addr;
    bit [31:0] rvfi_rs1_rdata;
    bit [31:0] rvfi_rs2_rdata;
    bit [4:0]  rvfi_rd_addr;
    bit [31:0] rvfi_rd_wdata;
    bit [31:0] rvfi_pc_rdata;
    bit [31:0] rvfi_pc_wdata;
    bit [31:0] rvfi_mem_addr;
    bit [3:0]  rvfi_mem_rmask;
    bit [3:0]  rvfi_mem_wmask;
    bit [31:0] rvfi_mem_rdata;
    bit [31:0] rvfi_mem_wdata;

    function automatic logic is_sim_ctrl();
        return (rvfi_mem_wmask != 4'b0 && rvfi_mem_addr inside {SIM_EXIT, SIM_EXIT_HI, SIM_PUTC});
    endfunction

    function automatic string compare (rvfi_txn golden);
        string diffs = "";
        if (rvfi_pc_rdata !== golden.rvfi_pc_rdata)
            diffs = {diffs, $sformatf(" pc_rdata: dut=%08h golden=%08h\n", rvfi_pc_rdata, golden.rvfi_pc_rdata)};
        if (rvfi_pc_wdata !== golden.rvfi_pc_wdata)
            diffs = {diffs, $sformatf(" pc_wdata: dut=%08h golden=%08h\n", rvfi_pc_wdata, golden.rvfi_pc_wdata)};
        if (rvfi_insn !== golden.rvfi_insn)
            diffs = {diffs, $sformatf(" insn: dut=%08h golden=%08h\n", rvfi_insn, golden.rvfi_insn)};
        if (rvfi_rd_addr !== golden.rvfi_rd_addr)
            diffs = {diffs, $sformatf(" rd_addr: dut=x%0d golden=x%0d\n", rvfi_rd_addr, golden.rvfi_rd_addr)};
        if (rvfi_rd_addr != 5'b0 && rvfi_rd_wdata !== golden.rvfi_rd_wdata)
            diffs = {diffs, $sformatf(" rd_wdata: dut=%08h golden=%08h\n", rvfi_rd_wdata, golden.rvfi_rd_wdata)};
        if (rvfi_mem_wmask !== golden.rvfi_mem_wmask)
            diffs = {diffs, $sformatf(" mem_wmask: dut=%0h golden=%0h\n", rvfi_mem_wmask, golden.rvfi_mem_wmask)};
        if (rvfi_mem_rmask !== golden.rvfi_mem_rmask)
            diffs = {diffs, $sformatf(" mem_rmask: dut=%0h golden=%0h\n", rvfi_mem_rmask, golden.rvfi_mem_rmask)};
        if (rvfi_mem_wmask != 4'b0 && rvfi_mem_addr !== golden.rvfi_mem_addr)
            diffs = {diffs, $sformatf(" mem_addr(w): dut=%08h golden=%08h\n", rvfi_mem_addr, golden.rvfi_mem_addr)};
        if (rvfi_mem_wmask != 4'b0 && rvfi_mem_wdata !== golden.rvfi_mem_wdata)
            diffs = {diffs, $sformatf(" mem_wdata: dut=%08h golden=%08h\n", rvfi_mem_wdata, golden.rvfi_mem_wdata)};
        if (rvfi_mem_rmask == 4'hF && rvfi_mem_addr !== golden.rvfi_mem_addr)
            diffs = {diffs, $sformatf(" mem_addr(r): dut=%08h golden=%08h\n", rvfi_mem_addr, golden.rvfi_mem_addr)};
        if (rvfi_mem_rmask == 4'hF && rvfi_mem_rdata !== golden.rvfi_mem_rdata)
            diffs = {diffs, $sformatf(" mem_rdata: dut=%08h golden=%08h\n", rvfi_mem_rdata, golden.rvfi_mem_rdata)};
        return diffs;
    endfunction

endclass
