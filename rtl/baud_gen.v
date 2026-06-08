// ============================================================
//  Module  : baud_gen
//  Project : UART Controller
//  Author  : [Your Name]
//
//  Purpose :
//    Generates a single-cycle pulse (tick) at the baud rate.
//    Every other UART module is clocked off this tick — it is
//    the timing reference for the entire controller.
//
//  How it works :
//    A counter increments every system clock cycle.
//    When it reaches (CLKS_PER_BIT - 1), it resets to 0 and
//    asserts `tick` for exactly one clock cycle.
//
//    CLKS_PER_BIT = CLK_FREQ / BAUD_RATE
//
//  Example :
//    CLK_FREQ  = 50_000_000  (50 MHz — Tang Nano 9K)
//    BAUD_RATE = 9_600
//    CLKS_PER_BIT = 5208
//    tick pulses every 5208 cycles → 9600 times per second
//
//  Parameters :
//    CLK_FREQ  — system clock frequency in Hz
//    BAUD_RATE — desired baud rate in bps
// ============================================================

module baud_gen #(
    parameter CLK_FREQ  = 50_000_000,   // 50 MHz default (Tang Nano 9K)
    parameter BAUD_RATE = 9_600         // 9600 baud default
)(
    input  wire clk,    // system clock
    input  wire rst_n,  // active-low synchronous reset
    output reg  tick    // 1-cycle pulse at baud rate
);

    // Number of clock cycles per UART bit period
    localparam CLKS_PER_BIT = CLK_FREQ / BAUD_RATE;

    // Counter width: enough bits to hold CLKS_PER_BIT
    // $clog2(5208) = 13 bits for 9600 baud @ 50MHz
    localparam CTR_W = $clog2(CLKS_PER_BIT);

    reg [CTR_W-1:0] counter;

    always @(posedge clk) begin
        if (!rst_n) begin
            counter <= 0;
            tick    <= 0;
        end else begin
            if (counter == CLKS_PER_BIT - 1) begin
                counter <= 0;
                tick    <= 1;   // pulse for exactly one cycle
            end else begin
                counter <= counter + 1;
                tick    <= 0;
            end
        end
    end

endmodule