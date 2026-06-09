
`timescale 1ns/1ps
module tb_uart_tx;
    localparam CLK_FREQ  = 100;
    localparam BAUD_RATE = 10;
    localparam CPB       = CLK_FREQ / BAUD_RATE; // 10
 
    reg clk=0, rst_n=0, start=0;
    reg [7:0] data_in=0;
    wire tx, busy;
 
    uart_tx #(.CLK_FREQ(CLK_FREQ),.BAUD_RATE(BAUD_RATE)) dut(
        .clk(clk),.rst_n(rst_n),.start(start),
        .data_in(data_in),.tx(tx),.busy(busy));
 
    always #5 clk=~clk;
    integer pass=0, fail=0;
 
    task check; input c; input [127:0] l; begin
        if(c) begin $display("  PASS: %0s",l); pass=pass+1; end
        else  begin $display("  FAIL: %0s",l); fail=fail+1; end
    end endtask
 
    reg [7:0] cap;
 
    // Send a byte and capture data bits by pure cycle counting.
    // baud_gen is reset on start, so timing is deterministic:
    //   After start pulse posedge: tx=LOW, counter=0
    //   Tick at CPB=10: transition to DATA
    //   Sample D0 at CPB + CPB/2 = 15 cycles after start posedge
    //   Sample D1 at 25, D2 at 35 ... D7 at 85
    task send_and_capture; input [7:0] b;
        integer i;
        begin
            // ensure idle and let baud counter free-run to any state
            while(busy) @(posedge clk);
            repeat(3) @(posedge clk);
            // Trigger — baud resets on THIS posedge, START begins
            data_in=b; start=1; @(posedge clk); start=0;
            // We are now 1 cycle into the START bit.
            // To sample D0 at its centre: wait CPB-1 + CPB/2 = 14 more cycles
            repeat(CPB - 1 + CPB/2) @(posedge clk);
            cap[0] = tx;
            for(i=1;i<8;i=i+1) begin
                repeat(CPB) @(posedge clk);
                cap[i] = tx;
            end
            $display("  Sent:0x%02X Got:0x%02X",b,cap);
        end
    endtask
 
    initial begin
        $dumpfile("sim/uart_tx.vcd");
        $dumpvars(0,tb_uart_tx);
        $display("\n=== UART TX Testbench ===\n");
        repeat(5) @(posedge clk); rst_n=1; repeat(3) @(posedge clk);
 
        $display("[Test 1] Idle");
        check(tx===1'b1,"tx HIGH when idle");
        check(busy===1'b0,"busy LOW when idle");
 
        $display("[Test 2] 0x55 (01010101)");
        send_and_capture(8'h55); check(cap===8'h55,"0x55 correct");
 
        $display("[Test 3] 0xA5 (10100101)");
        send_and_capture(8'hA5); check(cap===8'hA5,"0xA5 correct");
 
        $display("[Test 4] 0x00 (all zeros)");
        send_and_capture(8'h00); check(cap===8'h00,"0x00 correct");
 
        $display("[Test 5] 0xFF (all ones)");
        send_and_capture(8'hFF); check(cap===8'hFF,"0xFF correct");
 
        $display("[Test 6] busy flag");
        while(busy) @(posedge clk); repeat(3) @(posedge clk);
        data_in=8'hAB; start=1; @(posedge clk); start=0;
        @(posedge clk);
        check(busy===1'b1,"busy asserts on start");
        while(busy) @(posedge clk);
        check(busy===1'b0,"busy deasserts after stop bit");
 
        $display("\n=== %0d passed, %0d failed ===\n",pass,fail);
        if(fail==0) $display("All tests passed! Ready to build uart_rx.\n");
        $finish;
    end
    initial begin #500_000; $display("TIMEOUT"); $finish; end
endmodule
 