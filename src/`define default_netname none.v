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

// Tablas de búsqueda para diferentes formas de onda
reg [7:0] tabla_seno [0:255];        // LUT para la onda sinusoidal
reg [7:0] tabla_cuadrada [0:255];    // LUT para la onda cuadrada
reg [7:0] tabla_triangular [0:255];  // LUT para la onda triangular
reg [7:0] tabla_diente_sierra [0:255]; // LUT para la onda de diente de sierra
reg [7:0] tabla_actual [0:255];      // Tabla de onda seleccionada

reg [31:0] counter = 0;              // Contador para generar la frecuencia de PWM
reg [7:0] lut_addr = 0;              // Dirección para la tabla de búsqueda (LUT)
reg [31:0] freq;                     // Change integer freq to reg [31:0]

reg white_noise_enable = 0;          // Enable/disable white noise
reg [1:0] filter_level = 2'b00;      // 2-bit for 3 levels + off
reg adsr_active = 0;                 // Enable/disable ADSR

// Filtros
reg [7:0] filter_coeffs [0:2][0:4];  // Coeficientes del filtro para diferentes niveles (low, mid, high)
reg [7:0] filter_taps [0:4];         // Tapas del filtro para la convolución
reg [7:0] filtered_output;           // Salida del filtro

// Inicialización de las tablas de búsqueda
initial begin
    // Inicialización de la tabla de onda sinusoidal
    integer i;
    for (i = 0; i < 256; i = i + 1) begin
        tabla_seno[i] = 8'h80 + 8'h7F * $sin(2 * 3.14159 * i / 256);
    end

    // Inicialización de la tabla de onda cuadrada
    for (i = 0; i < 256; i = i + 1) begin
        if (i < 128)
            tabla_cuadrada[i] = 8'hFF;
        else
            tabla_cuadrada[i] = 8'h00;
    end

    // Inicialización de la tabla de onda triangular
    for (i = 0; i < 256; i = i + 1) begin
        if (i < 128)
            tabla_triangular[i] = i * 2;
        else
            tabla_triangular[i] = 8'hFF - (i - 128) * 2;
    end

    // Inicialización de la tabla de onda de diente de sierra
    for (i = 0;  i < 256; i = i + 1) begin
        tabla_diente_sierra[i] = i;
    end

    // Por defecto, seleccionar la tabla de onda sinusoidal
    tabla_actual = tabla_seno;

    // Inicialización de los coeficientes del filtro
    filter_coeffs[0] = {8'd1, 8'd1, 8'd1, 8'd1, 8'd1}; // Low filter
    filter_coeffs[1] = {8'd1, 8'd2, 8'd1, 8'd2, 8'd1}; // Mid filter
    filter_coeffs[2] = {8'd1, 8'd3, 8'd4, 8'd3, 8'd1}; // High filter
end

// Clock frequency in hertz.
parameter CLK_HZ = 25000000;
parameter BIT_RATE = 9600;
parameter PAYLOAD_BITS = 8;

wire [PAYLOAD_BITS-1:0] uart_rx_data;
wire uart_rx_valid;
wire uart_rx_break;

wire uart_tx_busy;
wire [PAYLOAD_BITS-1:0] uart_tx_data;
wire uart_tx_en;

reg [7:0] uart_data_shift_reg = 0; // Registro de desplazamiento para los datos UART
reg [7:0] uart_data_string[3:0]; // Almacena los bytes recibidos como cadena (4 bytes en este caso)
reg [3:0] byte_counter = 0; // Contador de bytes recibidos

assign uart_tx_data = uart_rx_data;
assign uart_tx_en = uart_rx_valid;

// Mapeo de frecuencias (0 a 7) a frecuencias reales (250 a 2000 Hz)
reg [31:0] freq_map [0:7];
initial begin
    freq_map[0] = CLK_HZ / 250;
    freq_map[1] = CLK_HZ / 500;
    freq_map[2] = CLK_HZ / 750;
    freq_map[3] = CLK_HZ / 1000;
    freq_map[4] = CLK_HZ / 1250;
    freq_map[5] = CLK_HZ / 1500;
    freq_map[6] = CLK_HZ / 1750;
    freq_map[7] = CLK_HZ / 2000;
end

// Instancia del módulo LFSR para la generación de ruido blanco
wire lfsr_noise;
lfsr lfsr_inst (
    .clk(clk1),
    .rst_n(~rst),
    .enable(white_noise_enable),
    .noise(lfsr_noise)
);

// Instancia del módulo ADC para leer valores de los potenciómetros
wire [7:0] attack, decay, sustain, relax;
adc_interface adc_if (
    .clk(clk1),
    .rst_n(~rst),
    .adc_in(uart_rx_data), // Conectar a los pines ADC correspondientes
    .attack(attack),
    .decay(decay),
    .sustain(sustain),
    .relax(relax)
);

// Instancia del módulo UART Receiver
wire uart_data_ready;
uart_receiver uart_rx_inst (
    .clk(clk1),
    .rst_n(~rst),
    .rx(uart_rxd),
    .data_ready(uart_data_ready),
    .data(uart_rx_data)
);

// Instancia del generador de envolvente ADSR
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

// Filtro FIR simple controlado por UART
always @(posedge clk1) begin
    if (rst) begin
        counter <= 0;
        pwm_out <= 0;
        filter_taps <= 0;
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
            pwm_out <= (adsr_out > counter) ? 1 : 0;
        end else if (white_noise_enable) begin
            pwm_out <= lfsr_noise;
        end else begin
            pwm_out <= (filtered_output > counter) ? 1 : 0;
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
    .uart_rx_break(uart_rx_break),
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

