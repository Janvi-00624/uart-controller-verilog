// ============================================================
//  Module  : uart_rx
//  Project : UART Controller
//  Author  : [Your Name]
//
//  Purpose :
//    Receives one byte over UART serial line.
//    Uses mid-bit sampling to robustly recover data
//    without a shared clock with the transmitter.
//
//  Mid-bit sampling explained:
//    1. Detect falling edge on rx (HIGH→LOW) = start bit
//    2. Wait CPB/2 cycles = land at CENTRE of start bit
//    3. Verify it's still LOW (not a glitch)
//    4. Sample every CPB cycles from here = centre of each bit
//
//  Interface:
//    clk       — system clock
//    rst_n     — active-low synchronous reset
//    rx        — serial input line
//    data_out  — 8-bit received byte (valid when done=1)
//    done      — pulses HIGH for 1 cycle when byte is ready
//
//  FSM States:
//    IDLE → START → DATA → STOP → IDLE
// ============================================================

module uart_rx #(
    parameter CLK_FREQ  = 50_000_000,
    parameter BAUD_RATE = 9_600
)(
    input  wire       clk,
    input  wire       rst_n,
    input  wire       rx,          // serial input
    output reg  [7:0] data_out,    // received byte
    output reg        done         // pulses high 1 cycle when byte ready
);

    localparam CLKS_PER_BIT  = CLK_FREQ / BAUD_RATE;
    localparam HALF_BIT      = CLKS_PER_BIT / 2;
    localparam CTR_W         = $clog2(CLKS_PER_BIT);

    // ── FSM states ───────────────────────────────────────────
    localparam IDLE  = 2'b00;
    localparam START = 2'b01;
    localparam DATA  = 2'b10;
    localparam STOP  = 2'b11;

    reg [1:0]       state;
    reg [CTR_W-1:0] clk_count;   // counts cycles within each bit
    reg [2:0]       bit_index;   // which data bit we're receiving
    reg [7:0]       shift_reg;   // shifts bits in LSB first

    // ── Input synchroniser (2 FF) ────────────────────────────
    // Prevents metastability on the async rx input
    reg rx_sync1, rx_sync2;
    always @(posedge clk) begin
        rx_sync1 <= rx;
        rx_sync2 <= rx_sync1;
    end
    wire rx_in = rx_sync2; // use this everywhere, not raw rx

    // ── FSM ──────────────────────────────────────────────────
    always @(posedge clk) begin
        if (!rst_n) begin
            state     <= IDLE;
            clk_count <= 0;
            bit_index <= 0;
            shift_reg <= 0;
            data_out  <= 0;
            done      <= 0;
        end else begin
            done <= 0; // default: done is low

            case (state)

                // ── IDLE ──────────────────────────────────────
                // Wait for rx to go LOW (start bit arriving)
                IDLE: begin
                    clk_count <= 0;
                    bit_index <= 0;
                    if (rx_in == 1'b0)   // falling edge detected
                        state <= START;
                end

                // ── START ─────────────────────────────────────
                // Wait HALF_BIT cycles to reach centre of start bit.
                // Re-check rx is still LOW — filters out glitches.
                START: begin
                    if (clk_count == HALF_BIT - 1) begin
                        clk_count <= 0;
                        if (rx_in == 1'b0) begin
                            // confirmed start bit — move to data
                            state <= DATA;
                        end else begin
                            // it was a glitch — go back to idle
                            state <= IDLE;
                        end
                    end else begin
                        clk_count <= clk_count + 1;
                    end
                end

                // ── DATA ──────────────────────────────────────
                // Wait CLKS_PER_BIT cycles between samples.
                // This keeps us at the centre of each bit.
                // Shift bits into shift_reg LSB first.
                DATA: begin
                    if (clk_count == CLKS_PER_BIT - 1) begin
                        clk_count             <= 0;
                        shift_reg[bit_index]  <= rx_in;  // sample bit
                        if (bit_index == 3'd7) begin
                            state <= STOP;
                        end else begin
                            bit_index <= bit_index + 1;
                        end
                    end else begin
                        clk_count <= clk_count + 1;
                    end
                end

                // ── STOP ──────────────────────────────────────
                // Wait one full bit period for the stop bit.
                // Output the received byte and pulse done.
                STOP: begin
                    if (clk_count == CLKS_PER_BIT - 1) begin
                        data_out  <= shift_reg;
                        done      <= 1'b1;   // byte ready!
                        clk_count <= 0;
                        state     <= IDLE;
                    end else begin
                        clk_count <= clk_count + 1;
                    end
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule