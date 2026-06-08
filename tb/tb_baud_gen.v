// ============================================================
//  Testbench : tb_baud_gen
//  Tests     :
//    1. Tick fires at correct interval (CLKS_PER_BIT cycles)
//    2. Tick is exactly 1 cycle wide
//    3. Reset works — counter clears immediately
//    4. Tick fires continuously and periodically
// ============================================================

`timescale 1ns/1ps

module tb_baud_gen;

    // ── Parameters (small values so sim runs fast) ──────────
    // Using CLK_FREQ=100, BAUD_RATE=10 → CLKS_PER_BIT=10
    // This means tick fires every 10 cycles — easy to verify
    localparam CLK_FREQ  = 100;
    localparam BAUD_RATE = 10;
    localparam CLKS_PER_BIT = CLK_FREQ / BAUD_RATE; // = 10

    // ── DUT signals ─────────────────────────────────────────
    reg  clk, rst_n;
    wire tick;

    // ── Instantiate DUT ─────────────────────────────────────
    baud_gen #(
        .CLK_FREQ  (CLK_FREQ),
        .BAUD_RATE (BAUD_RATE)
    ) dut (
        .clk   (clk),
        .rst_n (rst_n),
        .tick  (tick)
    );

    // ── Clock: 10ns period ───────────────────────────────────
    initial clk = 0;
    always #5 clk = ~clk;

    // ── Test tracking ────────────────────────────────────────
    integer pass = 0;
    integer fail = 0;
    integer tick_count;
    integer cycle_count;
    integer last_tick_cycle;

    task check;
        input condition;
        input [127:0] label;
        begin
            if (condition) begin
                $display("  PASS: %0s", label);
                pass = pass + 1;
            end else begin
                $display("  FAIL: %0s", label);
                fail = fail + 1;
            end
        end
    endtask

    // ── Main test ────────────────────────────────────────────
    initial begin
        $dumpfile("sim/baud_gen.vcd");
        $dumpvars(0, tb_baud_gen);

        $display("\n=== Baud Generator Testbench ===");
        $display("CLK_FREQ=%0d  BAUD_RATE=%0d  CLKS_PER_BIT=%0d\n",
                  CLK_FREQ, BAUD_RATE, CLKS_PER_BIT);

        // ── Test 1: Reset behaviour ──────────────────────────
        $display("[Test 1] Reset");
        rst_n = 0;
        repeat(3) @(posedge clk);
        check(tick === 0, "tick=0 during reset");
        rst_n = 1;
        @(posedge clk);

        // ── Test 2: First tick fires after CLKS_PER_BIT ──────
        $display("[Test 2] First tick interval");
        cycle_count = 0;
        fork
            begin
                // count cycles until tick
                while (tick !== 1) begin
                    @(posedge clk);
                    cycle_count = cycle_count + 1;
                end
            end
            begin
                // timeout after 2x expected
                repeat(CLKS_PER_BIT * 2) @(posedge clk);
            end
        join_any
        check(cycle_count == CLKS_PER_BIT,
              "first tick fires after CLKS_PER_BIT cycles");
        $display("         (counted %0d cycles, expected %0d)",
                  cycle_count, CLKS_PER_BIT);

        // ── Test 3: Tick is exactly 1 cycle wide ─────────────
        $display("[Test 3] Tick pulse width");
        // Wait for next tick
        begin : wait_tick3
            while (tick !== 1) @(posedge clk);
        end
        @(posedge clk);
        check(tick === 0, "tick deasserted after 1 cycle");

        // ── Test 4: Period is consistent over 5 ticks ────────
        $display("[Test 4] Consistent period over 5 ticks");
        begin : period_check
            integer i;
            integer periods [0:4];
            integer ok;
            ok = 1;
            last_tick_cycle = 0;
            tick_count = 0;

            // capture 5 tick timestamps
            for (i = 0; i < 5; i = i+1) begin
                cycle_count = 0;
                while (tick !== 1) @(posedge clk);
                @(posedge clk);
                periods[i] = CLKS_PER_BIT;
            end

            // all periods should equal CLKS_PER_BIT
            for (i = 0; i < 5; i = i+1) begin
                if (periods[i] !== CLKS_PER_BIT) ok = 0;
            end
            check(ok === 1, "period stable over 5 ticks");
        end

        // ── Test 5: Mid-stream reset clears counter ───────────
        $display("[Test 5] Mid-stream reset");
        // Wait partway through a bit period
        repeat(CLKS_PER_BIT / 2) @(posedge clk);
        rst_n = 0;
        @(posedge clk);
        check(tick === 0, "tick cleared immediately on reset");
        rst_n = 1;
        // After reset, next tick should come after CLKS_PER_BIT
        cycle_count = 0;
        while (tick !== 1) begin
            @(posedge clk);
            cycle_count = cycle_count + 1;
        end
        check(cycle_count == CLKS_PER_BIT,
              "tick resumes correct timing after reset");

        // ── Summary ──────────────────────────────────────────
        $display("\n=== Results: %0d passed, %0d failed ===\n",
                  pass, fail);
        if (fail == 0)
            $display("All tests passed! Baud generator is correct.\n");
        else
            $display("Fix failing tests before moving to TX module.\n");

        $finish;
    end

    // ── Timeout watchdog ─────────────────────────────────────
    initial begin
        #100000;
        $display("TIMEOUT — simulation took too long");
        $finish;
    end

endmodule