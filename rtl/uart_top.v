// ============================================================
//  Module  : uart_top
//  Project : UART Controller
//  Author  : [Your Name]
//
//  Purpose :
//    Top-level wrapper connecting uart_tx and uart_rx.
//    This is the module you instantiate in your FPGA design.
//
//  Loopback mode (LOOPBACK=1):
//    tx output is fed back into rx input internally.
//    Useful for testing without external hardware.
//
//  Interface:
//    clk       — system clock
//    rst_n     — active-low reset
//    tx_start  — pulse to begin transmission
//    tx_data   — byte to transmit
//    tx        — serial output pin  (connect to other device RX)
//    tx_busy   — high while transmitting
//    rx        — serial input pin   (connect to other device TX)
//    rx_data   — received byte (valid when rx_done=1)
//    rx_done   — pulses high 1 cycle when byte received
// ============================================================

module uart_top #(
    parameter CLK_FREQ  = 50_000_000,
    parameter BAUD_RATE = 9_600,
    parameter LOOPBACK  = 0          // set 1 for self-test
)(
    input  wire       clk,
    input  wire       rst_n,

    // TX interface
    input  wire       tx_start,
    input  wire [7:0] tx_data,
    output wire       tx,
    output wire       tx_busy,

    // RX interface
    input  wire       rx,
    output wire [7:0] rx_data,
    output wire       rx_done
);

    // In loopback mode, ignore the rx pin and loop tx back
    wire rx_in = (LOOPBACK) ? tx : rx;

    // ── TX ───────────────────────────────────────────────────
    uart_tx #(
        .CLK_FREQ  (CLK_FREQ),
        .BAUD_RATE (BAUD_RATE)
    ) tx_inst (
        .clk     (clk),
        .rst_n   (rst_n),
        .start   (tx_start),
        .data_in (tx_data),
        .tx      (tx),
        .busy    (tx_busy)
    );

    // ── RX ───────────────────────────────────────────────────
    uart_rx #(
        .CLK_FREQ  (CLK_FREQ),
        .BAUD_RATE (BAUD_RATE)
    ) rx_inst (
        .clk     (clk),
        .rst_n   (rst_n),
        .rx      (rx_in),
        .data_out(rx_data),
        .done    (rx_done)
    );

endmodule