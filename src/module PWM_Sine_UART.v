default_nettype none

module tt_um_PWM_Sine_UART (
    input  wire [7:0] ui_in,    // Dedicated inputs
    output wire [7:0] uo_out,   // Dedicated outputs
    input  wire [7:0] uio_in,   // IOs: Input path
    output wire [7:0] uio_out,  // IOs: Output path
    output wire [7:0] uio_oe,   // IOs: Enable path (active high: 0=input, 1=output)
    input  wire       ena,      // will go high when the design is enabled
    input  wire       clk,      // clock
    input  wire       rst_n     // reset_n - low to reset
);

    wire rst1, sw_01, sw_11, uart_rx, uart_tx, pwm_outx;
    wire [7:0] uart_rx_data;
    wire uart_rx_valid;
    wire [3:0] frequency_sel;
    wire [7:0] waveform_sel;

    // Assign inputs
    assign rst1 = ~rst_n;       // Active low reset
    assign sw_01 = ui_in[5];   // Selector for waveform
    assign sw_11 = ui_in[4];   // Selector for frequency
    assign uart_rx = ui_in[0]; // UART RX input
    assign uo_out[0] = uart_tx; // UART TX output
    assign pwm_outx = uo_out[2]; // PWM output

    // Set the default output values
    assign uo_out[7:3] = 5'b00000;
    assign uo_out[1] = 1'b0;
    assign uio_oe = 8'b00000000;
    assign uio_out = 8'b00000000;

    // Instantiate the PWM_Sine_UART module
    PWM_Sine_UART PWM_Sine_inst (
        .clk1(clk),
        .rst(rst1),
        .sw_0(sw_01),
        .sw_1(sw_11),
        .uart_rxd(uart_rx),
        .uart_txd(uart_tx),
        .pwm_out(pwm_outx)
    );

    // UART RX module
    uart_rx #(
        .BIT_RATE(9600),
        .PAYLOAD_BITS(8),
        .CLK_HZ(25000000)
    ) uart_rx_inst (
        .clk(clk),
        .resetn(rst_n),
        .uart_rxd(uart_rx),
        .uart_rx_en(1'b1),
        .uart_rx_break(),
        .uart_rx_valid(uart_rx_valid),
        .uart_rx_data(uart_rx_data)
    );

    // UART TX module
    uart_tx #(
        .BIT_RATE(9600),
        .PAYLOAD_BITS(8),
        .CLK_HZ(25000000)
    ) uart_tx_inst (
        .clk(clk),
        .resetn(rst_n),
        .uart_txd(uart_tx),
        .uart_tx_en(uart_rx_valid),
        .uart_tx_busy(),
        .uart_tx_data(uart_rx_data)
    );

    // Logic for selecting frequency and waveform
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            frequency_sel <= 4'd0;
            waveform_sel <= 8'd0;
        end else begin
            // Map switch inputs to frequency and waveform
            frequency_sel <= {sw_01, sw_11};
            waveform_sel <= uart_rx_data;
        end
    end

    // Update PWM_Sine_UART with frequency and waveform selection
    always @(posedge clk) begin
        if (ena) begin
            PWM_Sine_inst.freq <= frequency_sel;
            PWM_Sine_inst.waveform_sel <= waveform_sel;
        end
    end

endmodule
