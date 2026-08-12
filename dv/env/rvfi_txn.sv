class rvfi_txn;
    import rvfi_pkg::*;

    logic        rvfi_valid;
    logic [63:0] rvfi_order;
    logic [31:0] rvfi_insn;
    logic        rvfi_trap;
    logic        rvfi_halt;
    logic        rvfi_intr;
    logic [1:0]  rvfi_mode;
    logic [1:0]  rvfi_ixl;
    logic [4:0]  rvfi_rs1_addr;
    logic [4:0]  rvfi_rs2_addr;
    logic [31:0] rvfi_rs1_rdata;
    logic [31:0] rvfi_rs2_rdata;
    logic [4:0]  rvfi_rd_addr;
    logic [31:0] rvfi_rd_wdata;
    logic [31:0] rvfi_pc_rdata;
    logic [31:0] rvfi_pc_wdata;
    logic [31:0] rvfi_mem_addr;
    logic [3:0]  rvfi_mem_rmask;
    logic [3:0]  rvfi_mem_wmask;
    logic [31:0] rvfi_mem_rdata;
    logic [31:0] rvfi_mem_wdata;

    function automatic logic is_sim_ctrl();
        return (rvfi_mem_wmask != 4'b0 && rvfi_mem_addr inside {SIM_EXIT, SIM_EXIT_HI, SIM_PUTC});
    endfunction

    function automatic string compare (rvfi_txn golden);
        string diffs = "";
        if (rvfi_order !== golden.rvfi_order)
            diffs = {diffs, $sformatf(" order: dut=%0d golden=%0d\n", rvfi_order, golden.rvfi_order)};
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
