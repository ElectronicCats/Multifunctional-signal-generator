module triangular_wave_generator (
    input wire clk,                  // Reloj de entrada
    input wire reset,                // Señal de reinicio
    input wire [2:0] freq_select,    // Selección de frecuencia (3 bits para 8 niveles)
    output reg [7:0] wave_out        // Salida de onda triangular de 8 bits
);

    reg [7:0] counter;               // Contador para la onda triangular
    reg direction;                   // Dirección del contador (ascendente o descendente)
    reg [7:0] clk_div;               // Contador de divisor de reloj
    reg [7:0] clk_div_threshold;     // Umbral para el divisor de reloj

    // Lógica para seleccionar el umbral del divisor de reloj según la frecuencia deseada
    always @(*) begin
        case (freq_select)
            3'b000: clk_div_threshold = 8'd195;   // 250 Hz
            3'b001: clk_div_threshold = 8'd98;    // 500 Hz
            3'b010: clk_div_threshold = 8'd65;    // 750 Hz
            3'b011: clk_div_threshold = 8'd49;    // 1000 Hz
            3'b100: clk_div_threshold = 8'd32;    // 1500 Hz
            3'b101: clk_div_threshold = 8'd24;    // 2000 Hz
            3'b110: clk_div_threshold = 8'd16;    // 3000 Hz
            3'b111: clk_div_threshold = 8'd12;    // 4000 Hz
            default: clk_div_threshold = 8'd195;  // Default to 250 Hz
        endcase
    end

    // Lógica del generador de onda triangular
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            counter <= 8'd0;          // Reiniciar el contador a 0
            direction <= 1'b1;        // Iniciar en modo ascendente
            clk_div <= 8'd0;          // Reiniciar el divisor de reloj
        end else begin
            if (clk_div >= clk_div_threshold) begin
                clk_div <= 8'd0;      // Reiniciar el divisor de reloj

                // Lógica de dirección y contador para la onda triangular
                if (direction) begin
                    if (counter < 8'd255) begin
                        counter <= counter + 1;  // Incrementar el contador
                    end else begin
                        direction <= 1'b0;       // Cambiar a modo descendente
                    end
                end else begin
                    if (counter > 8'd0) begin
                        counter <= counter - 1;  // Decrementar el contador
                    end else begin
                        direction <= 1'b1;       // Cambiar a modo ascendente
                    end
                end
            end else begin
                clk_div <= clk_div + 1;          // Incrementar el divisor de reloj
            end
        end
    end

    // Asignar el valor del contador a la salida
    always @(posedge clk) begin
        wave_out <= counter;
    end

endmodule
