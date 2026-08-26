module rvfi_scoreboard
    import rvfi_pkg::*;
(
    input logic clk,
    input logic rst_n,
    input logic core_halted,

    input mailbox #(rvfi_txn) mon2scb,
    input mailbox #(rvfi_txn) spike2scb,
    input mailbox #(rvfi_txn) imem2scb,
    input mailbox #(rvfi_txn) dmem2scb,

    input logic sim_exit_valid,
    input logic [31:0] sim_exit_code
);

    int count, errors;

    initial begin
        count = 0;
        errors = 0;
    end

    task automatic run_one_program();
        logic test_done;
        logic got;
        rvfi_txn txn_mon, txn_spike, txn_imem, txn_dmem;
        string diff;

        test_done = 1'b0;

        #1;

        // Drain the previous program's leftover SIM_EXIT bus entries so they can't misalign this one.
        while (mon2scb.try_get(txn_mon))   ;
        while (imem2scb.try_get(txn_imem)) ;
        while (dmem2scb.try_get(txn_dmem)) ;

        while (!test_done) begin
            got = 1'b0;
            while (!got && !(rst_n && core_halted)) begin
                got = mon2scb.try_get(txn_mon);
                if (!got) @(posedge clk);
            end

            if (!got) begin
                // halted with no SIM_EXIT (fault), so trap correctness is an SVA check
                test_done = 1'b1;
            end else if (txn_mon.is_sim_exit()) begin
                #1; // wait for mem_model non-blocking
                assert (sim_exit_valid == 1'b1 && sim_exit_code == 32'b0);
                test_done = 1'b1;
            end else if (txn_mon.rvfi_trap) begin
                // spike is bare-ISA (no mtvec), so it has no golden entry for a trap
            end else if (!spike2scb.try_get(txn_spike)) begin
                $error("SCOREBOARD: spike2scb starved at retirement %0d (PC=%0h) - golden trace ended early, aborting program instead of hanging",
                        count, txn_mon.rvfi_pc_rdata);
                errors++;
                test_done = 1'b1;
            end else begin
                // Spike Reference Comparison
                diff = txn_mon.compare(txn_spike);
                if (diff != "") begin
                    $error("SCOREBOARD: mismatch at retirement %0d:\n%s", count, diff);
                    errors++;
                end

                // IMEM Bus Check
                if (!imem2scb.try_get(txn_imem)) begin
                    $error("SCOREBOARD: imem2scb starved at retirement %0d (PC=%0h)", count, txn_mon.rvfi_pc_rdata);
                    errors++;
                    test_done = 1'b1;
                end else begin
                    if (txn_imem.rvfi_pc_rdata !== txn_mon.rvfi_pc_rdata ||
                        txn_imem.rvfi_insn !== txn_mon.rvfi_insn) begin
                        $error("SCOREBOARD: IMEM bus mismatch at PC=%0h", txn_mon.rvfi_pc_rdata);
                        errors++;
                    end

                    // DMEM Bus Check (load/store only)
                    if (txn_mon.rvfi_mem_wmask != 4'b0 || txn_mon.rvfi_mem_rmask != 4'b0) begin
                        if (!dmem2scb.try_get(txn_dmem)) begin
                            $error("SCOREBOARD: dmem2scb starved at retirement %0d (PC=%0h)", count, txn_mon.rvfi_pc_rdata);
                            errors++;
                            test_done = 1'b1;
                        end else if (txn_dmem.rvfi_mem_addr !== txn_mon.rvfi_mem_addr ||
                            txn_dmem.rvfi_mem_wmask !== txn_mon.rvfi_mem_wmask ||
                            txn_dmem.rvfi_mem_wdata !== txn_mon.rvfi_mem_wdata ||
                            (txn_mon.rvfi_mem_rmask == 4'hF && txn_dmem.rvfi_mem_rdata !== txn_mon.rvfi_mem_rdata))
                        begin
                            $error("SCOREBOARD: DMEM bus mismatch at PC=%0h (addr=%h vs %h, wmask=%h vs %h, wdata=%h vs %h)",
                                    txn_mon.rvfi_pc_rdata, txn_mon.rvfi_mem_addr,  txn_dmem.rvfi_mem_addr, txn_mon.rvfi_mem_wmask,
                                    txn_dmem.rvfi_mem_wmask, txn_mon.rvfi_mem_wdata, txn_dmem.rvfi_mem_wdata);
                            errors++;
                        end
                    end
                end
            end
            count++;
        end
    endtask

    task automatic report_and_finish();
        if (errors == 0) $display("SCOREBOARD: PASS (%0d retirements checked)", count);
        else $display("SCOREBOARD: FAIL (%0d errors)", errors);
        $finish;
    endtask

endmodule
