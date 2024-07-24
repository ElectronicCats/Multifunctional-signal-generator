`define default_netname none

module tt_um_pwm_sine_uart (
    input               clk1,        // Top level system clock input
    input               sw_0,        // Slide switches
    input               sw_1,        // Slide switches
    input   wire        uart_rxd,    // UART Receive pin
    output  wire        uart_txd,    // UART transmit pin
    input               rst,         // Reset
    output reg          pwm_out      // PWM output
);

// Look-Up Tables (LUTs) for different waveforms
reg [7:0] tabla_seno [0:255];        // LUT for sine wave
reg [7:0] tabla_cuadrada [0:255];    // LUT for square wave
reg [7:0] tabla_triangular [0:255];  // LUT for triangular wave
reg [7:0] tabla_diente_sierra [0:255]; // LUT for sawtooth wave
reg [7:0] tabla_actual [0:255];      // Selected waveform LUT

reg [31:0] counter = 0;              // Counter for PWM frequency generation
reg [7:0] lut_addr = 0;              // Address for LUT
reg [31:0] freq;                     // Frequency control

reg white_noise_enable = 0;          // Enable/disable white noise
reg [1:0] filter_level = 2'b00;      // 2-bit for 3 filter levels + off
reg adsr_active = 0;                 // Enable/disable ADSR

// Filters
reg [7:0] filter_taps [0:4];         // Filter taps for convolution
reg [7:0] filtered_output;           // Output of the filter

// Initializing the LUTs
initial begin
    integer i;
    // Initialize the sine wave LUT
    for (i = 0; i < 256; i = i + 1) begin
        tabla_seno[i] = $rtoi(8'h80 + 8'h7F * $sin(2 * 3.14159 * i / 256)); // Sine approximation
    end

    // Initialize the square wave LUT
    for (i = 0; i < 256; i = i + 1) begin
        tabla_cuadrada[i] = (i < 128) ? 8'hFF : 8'h00;
    end

    // Initialize the triangular wave LUT
    for (i = 0; i < 256; i = i + 1) begin
        tabla_triangular[i] = (i < 128) ? (i * 2) : (8'hFF - (i - 128) * 2);
    end

    // Initialize the sawtooth wave LUT
    for (i = 0; i < 256; i = i + 1) begin
        tabla_diente_sierra[i] = i;
    end

    // Default to the sine wave LUT
    tabla_actual = tabla_seno;

    // Initialize filter taps to zero
    filter_taps[0] = 0;
    filter_taps[1] = 0;
    filter_taps[2] = 0;
    filter_taps[3] = 0;
    filter_taps[4] = 0;
end

// Clock frequency in hertz
parameter CLK_HZ = 25000000;
parameter BIT_RATE = 9600;
parameter PAYLOAD_BITS = 8;

wire [PAYLOAD_BITS-1:0] uart_rx_data;
wire uart_rx_valid;
wire uart_rx_break;

wire uart_tx_busy;
wire [PAYLOAD_BITS-1:0] uart_tx_data;
wire uart_tx_en;

reg [7:0] uart_data_shift_reg = 0;
reg [7:0] uart_data_string[3:0];
reg [3:0] byte_counter = 0;

// Frequency mapping (0 to 7) to actual frequencies (250 to 4000 Hz)
reg [31:0] freq_map [0:7];
initial begin
    freq_map[0] = CLK_HZ / 250;  // 250 Hz
    freq_map[1] = CLK_HZ / 500;  // 500 Hz
    freq_map[2] = CLK_HZ / 750;  // 750 Hz
    freq_map[3] = CLK_HZ / 1000; // 1 kHz
    freq_map[4] = CLK_HZ / 1500; // 1.5 kHz
    freq_map[5] = CLK_HZ / 2000; // 2 kHz
    freq_map[6] = CLK_HZ / 3000; // 3 kHz
    freq_map[7] = CLK_HZ / 4000; // 4 kHz
end

// Instantiate LFSR for white noise generation
wire lfsr_noise;
lfsr lfsr_inst (
    .clk(clk1),
    .rst_n(~rst),
    .enable(white_noise_enable),
    .noise(lfsr_noise)
);

// Instantiate ADC interface for reading potentiometer values
wire [7:0] attack, decay, sustain, relax;
adc_interface adc_if (
    .clk(clk1),
    .rst_n(~rst),
    .adc_in(uart_rx_data), // Connect to the appropriate ADC pins
    .attack(attack),
    .decay(decay),
    .sustain(sustain),
    .relax(relax)
);

// Instantiate UART Receiver
wire uart_data_ready;
uart_receiver uart_rx_inst (
    .clk(clk1),
    .rst_n(~rst),
    .rx(uart_rxd),
    .data_ready(uart_data_ready),
    .data(uart_rx_data)
);

// Instantiate ADSR envelope generator
wire [7:0] adsr_out;
adsr adsr_inst (
    .clk(clk1),
    .rst_n(~rst),
    .trigger(uart_data_ready),
    .attack(attack),
    .decay(decay),
    .sustain(sustain),
    .relax(relax),
    .envelope(adsr_out)
);

// Filter FIR controlled by UART
always @(posedge clk1) begin
    if (rst) begin
        counter <= 0;
        pwm_out <= 0;
        filter_taps[0] <= 0;
        filter_taps[1] <= 0;
        filter_taps[2] <= 0;
        filter_taps[3] <= 0;
        filter_taps[4] <= 0;
        filtered_output <= 0;
    end else begin
        if (uart_rx_valid) begin
            case (uart_rx_data[7:0])
                8'b00110000: freq <= freq_map[0]; // '0'
                8'b00110001: freq <= freq_map[1]; // '1'
                8'b00110010: freq <= freq_map[2]; // '2'
                8'b00110011: freq <= freq_map[3]; // '3'
                8'b00110100: freq <= freq_map[4]; // '4'
                8'b00110101: freq <= freq_map[5]; // '5'
                8'b00110110: freq <= freq_map[6]; // '6'
                8'b00110111: freq <= freq_map[7]; // '7'
                8'b01000001: tabla_actual <= tabla_seno;          // 'A'
                8'b01000010: tabla_actual <= tabla_cuadrada;      // 'B'
                8'b01000011: tabla_actual <= tabla_triangular;    // 'C'
                8'b01000100: tabla_actual <= tabla_diente_sierra; // 'D'
                8'b01001000: white_noise_enable <= ~white_noise_enable; // 'H' Toggle white noise
                8'b01001001: filter_level <= 2'b01; // 'I' Set filter level 1 (low)
                8'b01001010: filter_level <= 2'b10; // 'J' Set filter level 2 (mid)
                8'b01001011: filter_level <= 2'b11; // 'K' Set filter level 3 (high)
                8'b01001100: adsr_active <= 1; // 'L' Enable ADSR
                8'b01001101: adsr_active <= 0; // 'M' Disable ADSR
            endcase
        end

        counter <= counter + 1;
        if (counter >= freq) begin
            counter <= 0;
            lut_addr <= lut_addr + 1;
            if (lut_addr == 255) begin
                lut_addr <= 0;
            end
        end

        // Apply filter
        filter_taps[4:1] <= filter_taps[3:0];
        filter_taps[0] <= tabla_actual[lut_addr];

        case (filter_level)
            2'b00: filtered_output <= filter_taps[0]; // No filter
            2'b01: filtered_output <= (filter_taps[0] + filter_taps[1] + filter_taps[2] + filter_taps[3] + filter_taps[4]) / 5; // Low
            2'b10: filtered_output <= (filter_taps[0] + 2*filter_taps[1] + filter_taps[2] + 2*filter_taps[3] + filter_taps[4]) / 7; // Mid
            2'b11: filtered_output <= (filter_taps[0] + 3*filter_taps[1] + 4*filter_taps[2] + 3*filter_taps[3] + filter_taps[4]) / 12; // High
        endcase

        if (adsr_active) begin
            pwm_out <= (adsr_out > counter[7:0]) ? 1 : 0; // Ensure 8-bit comparison
        end else if (white_noise_enable) begin
            pwm_out <= lfsr_noise;
        end else begin
            pwm_out <= (filtered_output > counter[7:0]) ? 1 : 0; // Ensure 8-bit comparison
        end
    end
end

// UART RX
uart_rx #(
    .BIT_RATE(BIT_RATE),
    .PAYLOAD_BITS(PAYLOAD_BITS),
    .CLK_HZ(CLK_HZ)
) i_uart_rx (
    .clk(clk1),
    .resetn(~rst), // Using consistent naming for reset signal
    .uart_rxd(uart_rxd),
    .uart_rx_en(1'b1),
    .uart_rx_break(1'b0), // Default to no break
    .uart_rx_valid(uart_rx_valid),
    .uart_rx_data(uart_rx_data)
);

// UART TX
uart_tx #(
    .BIT_RATE(BIT_RATE),
    .PAYLOAD_BITS(PAYLOAD_BITS),
    .CLK_HZ(CLK_HZ)
) i_uart_tx (
    .clk(clk1),
    .resetn(~rst), // Using consistent naming for reset signal
    .uart_txd(uart_txd),
    .uart_tx_en(uart_tx_en),
    .uart_tx_busy(uart_tx_busy),
    .uart_tx_data(uart_tx_data)
);

endmodule

// Define the LFSR module for generating white noise
module lfsr (
    input wire clk,
    input wire rst_n,
    input wire enable,
    output reg noise
);
    reg [15:0] lfsr_reg;
    wire feedback;

    assign feedback = lfsr_reg[15] ^ lfsr_reg[14] ^ lfsr_reg[13] ^ lfsr_reg[10];

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            lfsr_reg <= 16'hFFFF;
            noise <= 0;
        end else if (enable) begin
            lfsr_reg <= {lfsr_reg[14:0], feedback};
            noise <= lfsr_reg[15];
        end
    end
endmodule

// ADSR envelope generator module
module adsr (
    input wire clk,
    input wire rst_n,
    input wire trigger,
    input wire [7:0] attack,
    input wire [7:0] decay,
    input wire [7:0] sustain,
    input wire [7:0] relax,
    output reg [7:0] envelope
);
    typedef enum reg [2:0] {
        IDLE,
        ATTACK,
        DECAY,
        SUSTAIN,
        RELAX
    } state_t;
    
    state_t state, next_state;
    reg [7:0] counter;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            counter <= 0;
            envelope <= 0;
        end else begin
            state <= next_state;
            case (state)
                IDLE: begin
                    envelope <= 0;
                    if (trigger) next_state <= ATTACK;
                end
                ATTACK: begin
                    if (counter < attack) begin
                        envelope <= envelope + 1;
                        counter <= counter + 1;
                    end else begin
                        next_state <= DECAY;
                        counter <= 0;
                    end
                end
                DECAY: begin
                    if (counter < decay) begin
                        envelope <= envelope - 1;
                        counter <= counter + 1;
                    end else begin
                        next_state <= SUSTAIN;
                    end
                end
                SUSTAIN: begin
                    envelope <= sustain;
                    if (!trigger) next_state <= RELAX;
                end
                RELAX: begin
                    if (counter < relax) begin
                        envelope <= envelope - 1;
                        counter <= counter + 1;
                    end else begin
                        next_state <= IDLE;
                        counter <= 0;
                    end
                end
            endcase
        end
    end
endmodule
