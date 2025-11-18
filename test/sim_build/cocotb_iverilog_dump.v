module cocotb_iverilog_dump();
initial begin
    $dumpfile("sim_build/tb_core.fst");
    $dumpvars(0, tb_core);
end
endmodule
