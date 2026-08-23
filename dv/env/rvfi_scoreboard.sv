module rvfi_scoreboard
    import rvfi_pkg::*;
(
    input mailbox #(rvfi_txn) mon2scb,
    input mailbox #(rvfi_txn) spike2scb,
    input mailbox #(rvfi_txn) imem2scb,
    input mailbox #(rvfi_txn) dmem2scb,

    input logic sim_exit_valid,
    input logic [31:0] sim_exit_code
);  

    int count, errors;

    initial begin
        logic test_done;
        rvfi_txn txn_mon, txn_spike, txn_imem, txn_dmem;
        string diff;

        count = 0;
        errors = 0;
        test_done = 1'b0;

        while (!test_done) begin
            mon2scb.get(txn_mon);
            if (txn_mon.is_sim_exit()) begin
                #1; // wait for mem_model non-blocking
                assert (sim_exit_valid == 1'b1 && sim_exit_code == 32'b0);
                test_done = 1'b1;
            end else begin
                // Spike Reference Comparison
                spike2scb.get(txn_spike);
                diff = txn_mon.compare(txn_spike);
                if (diff != "") begin
                    $error("SCOREBOARD: mismatch at retirement %0d:\n%s", count, diff);
                    errors++;
                end

                // IMEM Bus Check
                imem2scb.get(txn_imem);
                if (txn_imem.rvfi_pc_rdata !== txn_mon.rvfi_pc_rdata ||
                    txn_imem.rvfi_insn !== txn_mon.rvfi_insn) begin
                    $error("SCOREBOARD: IMEM bus mismatch at PC=%0h", txn_mon.rvfi_pc_rdata);
                    errors++;
                end

                // DMEM Bus Check (load/store only)
                if (txn_mon.rvfi_mem_wmask != 4'b0 || txn_mon.rvfi_mem_rmask != 4'b0) begin
                    dmem2scb.get(txn_dmem);
                    if (txn_dmem.rvfi_mem_addr !== txn_mon.rvfi_mem_addr ||
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
            count++;
        end

        if (errors == 0) $display("SCOREBOARD: PASS (%0d retirements checked)", count);
        else $display("SCOREBOARD: FAIL (%0d errors)", errors);
        $finish;
    end

endmodule
