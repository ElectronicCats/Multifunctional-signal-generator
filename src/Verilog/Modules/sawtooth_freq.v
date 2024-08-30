module sawtooth_wave_generator (
    input wire clk,                  // Reloj de entrada (25 MHz)
    input wire reset,                // Señal de reinicio
    input wire [2:0] freq_select,    // Selección de frecuencia (3 bits para 8 niveles)
    output reg [7:0] wave_out        // Salida de onda diente de sierra de 8 bits
);

    reg [7:0] counter;               // Contador para la onda diente de sierra
    reg [15:0] clk_div;              // Contador de divisor de reloj
    reg [15:0] clk_div_threshold;    // Umbral para el divisor de reloj

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

    // Lógica del generador de onda diente de sierra
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            counter <= 8'd0;           // Reiniciar el contador a 0
            clk_div <= 16'd0;          // Reiniciar el divisor de reloj a 0
        end else begin
            if (clk_div >= clk_div_threshold) begin
                clk_div <= 16'd0;      // Reiniciar el divisor de reloj
                counter <= counter + 1; // Incrementar el contador
            end else begin
                clk_div <= clk_div + 1; // Incrementar el divisor de reloj
            end
        end
    end

    // Asignar el valor del contador a la salida
    always @(posedge clk) begin
        wave_out <= counter;
    end

endmodule
