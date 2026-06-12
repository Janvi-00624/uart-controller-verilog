// ============================================================
//  Testbench : tb_uart_rx
//  Strategy  : drive the rx line manually, mimicking a UART TX
//  Tests     :
//    1. Receive 0x55 (01010101)
//    2. Receive 0xA5 (10100101)
//    3. Receive 0x00 (all zeros)
//    4. Receive 0xFF (all ones)
//    5. Glitch rejection — short LOW pulse should be ignored
//    6. done pulse is exactly 1 cycle wide
// ============================================================
`timescale 1ns/1ps

module tb_uart_rx;
    localparam CLK_FREQ  = 100;
    localparam BAUD_RATE = 10;
    localparam CPB       = CLK_FREQ / BAUD_RATE; // 10

    reg  clk=0, rst_n=0, rx=1;
    wire [7:0] data_out;
    wire done;

    uart_rx #(.CLK_FREQ(CLK_FREQ),.BAUD_RATE(BAUD_RATE)) dut(
        .clk     (clk),
        .rst_n   (rst_n),
        .rx      (rx),
        .data_out(data_out),
        .done    (done)
    );

    always #5 clk=~clk;
    integer pass=0, fail=0;

    task check; input c; input [127:0] l; begin
        if(c) begin $display("  PASS: %0s",l); pass=pass+1; end
        else  begin $display("  FAIL: %0s",l); fail=fail+1; end
    end endtask

    // Drive a full UART frame onto rx line
    // Mimics exactly what uart_tx would send
    task drive_byte; input [7:0] b;
        integer i;
        begin
            // start bit
            rx = 1'b0; repeat(CPB) @(posedge clk);
            // 8 data bits LSB first
            for(i=0;i<8;i=i+1) begin
                rx = b[i]; repeat(CPB) @(posedge clk);
            end
            // stop bit
            rx = 1'b1; repeat(CPB) @(posedge clk);
        end
    endtask

    // Send byte and capture result
    reg [7:0] received;
    task send_and_check; input [7:0] b; input [127:0] label;
        begin
            fork
                // Thread 1: drive the rx line
                drive_byte(b);
                // Thread 2: wait for done and capture
                begin
                    while(!done) @(posedge clk);
                    received = data_out;
                end
            join
            $display("  Sent:0x%02X  Received:0x%02X", b, received);
            check(received===b, label);
            repeat(5) @(posedge clk);
        end
    endtask

    initial begin
        $dumpfile("sim/uart_rx.vcd");
        $dumpvars(0, tb_uart_rx);
        $display("\n=== UART RX Testbench ===\n");

        repeat(5) @(posedge clk); rst_n=1; repeat(5) @(posedge clk);

        // ── Test 1: Receive 0x55 ──────────────────────────────
        $display("[Test 1] Receive 0x55 (01010101)");
        send_and_check(8'h55, "0x55 received correctly");

        // ── Test 2: Receive 0xA5 ──────────────────────────────
        $display("[Test 2] Receive 0xA5 (10100101)");
        send_and_check(8'hA5, "0xA5 received correctly");

        // ── Test 3: Receive 0x00 ──────────────────────────────
        $display("[Test 3] Receive 0x00 (all zeros)");
        send_and_check(8'h00, "0x00 received correctly");

        // ── Test 4: Receive 0xFF ──────────────────────────────
        $display("[Test 4] Receive 0xFF (all ones)");
        send_and_check(8'hFF, "0xFF received correctly");

        // ── Test 5: Glitch rejection ──────────────────────────
        // A pulse shorter than HALF_BIT should be ignored
        $display("[Test 5] Glitch rejection");
        rx = 1'b0; repeat(CPB/2 - 2) @(posedge clk); // short glitch
        rx = 1'b1; repeat(5) @(posedge clk);
        check(done===1'b0, "short glitch ignored");

        // ── Test 6: done pulse width ──────────────────────────
        $display("[Test 6] done pulse is 1 cycle wide");
        repeat(5) @(posedge clk);
        fork
            drive_byte(8'hAA);
            begin
                while(!done) @(posedge clk);
                @(posedge clk);
                check(done===1'b0, "done deasserts after 1 cycle");
            end
        join

        $display("\n=== %0d passed, %0d failed ===\n", pass, fail);
        if(fail==0) $display("All tests passed! Ready to build uart_top.\n");
        $finish;
    end
    initial begin #1_000_000; $display("TIMEOUT"); $finish; end

endmodule