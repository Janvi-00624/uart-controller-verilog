// ============================================================
//  Testbench : tb_uart_top
//  Tests the full TX→RX loopback path.
//  Sends a byte through TX, receives it on RX,
//  confirms the output matches — end to end.
// ============================================================
`timescale 1ns/1ps

module tb_uart_top;
    localparam CLK_FREQ  = 100;
    localparam BAUD_RATE = 10;

    reg  clk=0, rst_n=0, tx_start=0;
    reg  [7:0] tx_data=0;
    wire tx, tx_busy;
    wire [7:0] rx_data;
    wire rx_done;

    // Instantiate in LOOPBACK mode — tx feeds directly into rx
    uart_top #(
        .CLK_FREQ  (CLK_FREQ),
        .BAUD_RATE (BAUD_RATE),
        .LOOPBACK  (1)
    ) dut (
        .clk     (clk),
        .rst_n   (rst_n),
        .tx_start(tx_start),
        .tx_data (tx_data),
        .tx      (tx),
        .tx_busy (tx_busy),
        .rx      (1'b1),      // unused in loopback
        .rx_data (rx_data),
        .rx_done (rx_done)
    );

    always #5 clk=~clk;
    integer pass=0, fail=0;

    task check; input c; input [127:0] l; begin
        if(c) begin $display("  PASS: %0s",l); pass=pass+1; end
        else  begin $display("  FAIL: %0s",l); fail=fail+1; end
    end endtask

    reg [7:0] received;

    task loopback_test; input [7:0] b; input [127:0] label;
        begin
            // wait for idle
            while(tx_busy) @(posedge clk);
            repeat(5) @(posedge clk);
            // send byte
            tx_data=b; tx_start=1; @(posedge clk); tx_start=0;
            // wait for rx_done
            while(!rx_done) @(posedge clk);
            received = rx_data;
            $display("  Sent:0x%02X  Received:0x%02X", b, received);
            check(received===b, label);
            repeat(5) @(posedge clk);
        end
    endtask

    initial begin
        $dumpfile("sim/uart_top.vcd");
        $dumpvars(0, tb_uart_top);
        $display("\n=== UART Top Loopback Testbench ===\n");

        repeat(5) @(posedge clk); rst_n=1; repeat(5) @(posedge clk);

        $display("[Test 1] Loopback 0x55"); loopback_test(8'h55, "0x55 loopback correct");
        $display("[Test 2] Loopback 0xA5"); loopback_test(8'hA5, "0xA5 loopback correct");
        $display("[Test 3] Loopback 0x00"); loopback_test(8'h00, "0x00 loopback correct");
        $display("[Test 4] Loopback 0xFF"); loopback_test(8'hFF, "0xFF loopback correct");
        $display("[Test 5] Loopback 0x37"); loopback_test(8'h37, "0x37 loopback correct");
        $display("[Test 6] Loopback 0xC8"); loopback_test(8'hC8, "0xC8 loopback correct");

        $display("\n=== %0d passed, %0d failed ===\n", pass, fail);
        if(fail==0) $display("UART Controller complete! Full TX-RX path verified.\n");
        $finish;
    end
    initial begin #2_000_000; $display("TIMEOUT"); $finish; end

endmodule