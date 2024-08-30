module square_wave_generator (
    input wire clk,                  // Reloj del sistema (25 MHz)
    input wire reset,                // Señal de reinicio
    input wire [2:0] freq_select,    // Selección de frecuencia (3 bits para 8 niveles)
    output reg [7:0] wave_out        // Salida de onda cuadrada de 8 bits
);

    reg [15:0] clk_div;              // Contador de divisor de reloj
    reg [15:0] clk_div_threshold;    // Umbral para el divisor de reloj
    reg wave_state;                  // Estado actual de la onda cuadrada

    // Lógica para seleccionar el umbral del divisor de reloj según la frecuencia deseada
    always @(*) begin
        case (freq_select)
            3'b000: clk_div_threshold = 16'd390;   // 250 Hz
            3'b001: clk_div_threshold = 16'd195;   // 500 Hz
            3'b010: clk_div_threshold = 16'd130;   // 750 Hz
            3'b011: clk_div_threshold = 16'd98;    // 1000 Hz
            3'b100: clk_div_threshold = 16'd65;    // 1500 Hz
            3'b101: clk_div_threshold = 16'd49;    // 2000 Hz
            3'b110: clk_div_threshold = 16'd32;    // 3000 Hz
            3'b111: clk_div_threshold = 16'd24;    // 4000 Hz
            default: clk_div_threshold = 16'd390;  // Default to 250 Hz
        endcase
    end

    // Inicialización
    initial begin
        clk_div = 16'd0;
        wave_state = 1'b0;
        wave_out = 8'd0;
    end

    // Generación de la onda cuadrada
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            clk_div <= 16'd0;          // Reiniciar el divisor de reloj a 0
            wave_state <= 1'b0;        // Reiniciar el estado de la onda
            wave_out <= 8'd0;          // Reiniciar la salida de la onda
        end else begin
            if (clk_div >= clk_div_threshold) begin
                clk_div <= 16'd0;      // Reiniciar el divisor de reloj
                wave_state <= ~wave_state; // Cambiar el estado de la onda cuadrada
            end else begin
                clk_div <= clk_div + 1; // Incrementar el divisor de reloj
            end

            wave_out <= (wave_state) ? 8'd255 : 8'd0; // Establecer la salida de la onda cuadrada
        end
    end

endmodule
