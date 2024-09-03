module sawtooth_wave_generator_with_adsr (
    input wire clk,                  // Reloj de entrada (25 MHz)
    input wire reset,                // Señal de reinicio
    input wire [2:0] freq_select,    // Selección de frecuencia (3 bits para 8 niveles)
    input wire [7:0] attack_time,    // Tiempo de ataque (simulado por un valor digital)
    input wire [7:0] decay_time,     // Tiempo de decaimiento (simulado por un valor digital)
    input wire [7:0] sustain_level,  // Nivel de sostenimiento (simulado por un valor digital)
    input wire [7:0] release_time,   // Tiempo de liberación (simulado por un valor digital)
    input wire note_on,              // Señal de inicio de nota
    input wire note_off,             // Señal de fin de nota
    output reg [7:0] wave_out        // Salida de onda diente de sierra de 8 bits
);

    reg [7:0] counter;               // Contador para la onda diente de sierra
    reg [15:0] clk_div;              // Contador de divisor de reloj
    reg [15:0] clk_div_threshold;    // Umbral para el divisor de reloj

    // Variables para el ADSR
    reg [7:0] envelope_level;        // Nivel del sobre (ADS)
    reg [7:0] envelope_counter;      // Contador para la envolvente
    reg [3:0] state;                 // Estado del ADSR

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

    // Lógica de ADSR
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            envelope_level <= 8'd0;   // Reiniciar el nivel del sobre a 0
            envelope_counter <= 8'd0; // Reiniciar el contador del sobre a 0
            state <= 4'd0;            // Reiniciar el estado del ADSR
        end else begin
            case (state)
                4'd0: begin // Idle
                    if (note_on) state <= 4'd1; // Cambiar a ataque si se activa la nota
                end
                4'd1: begin // Attack
                    if (envelope_counter < attack_time) begin
                        envelope_counter <= envelope_counter + 1;
                        envelope_level <= envelope_counter * 8 / attack_time; // Aumento
                    end else begin
                        envelope_counter <= 8'd0;
                        state <= 4'd2; // Cambiar a decaimiento
                    end
                end
                4'd2: begin // Decay
                    if (envelope_counter < decay_time) begin
                        envelope_counter <= envelope_counter + 1;
                        envelope_level <= (sustain_level + (8'd255 - sustain_level) * (decay_time - envelope_counter) / decay_time); // Decaimiento
                    end else begin
                        envelope_counter <= 8'd0;
                        state <= 4'd3; // Cambiar a sostenimiento
                    end
                end
                4'd3: begin // Sustain
                    if (note_off) state <= 4'd4; // Cambiar a liberación si se desactiva la nota
                    // Mantener el nivel de sostenimiento
                end
                4'd4: begin // Release
                    if (envelope_counter < release_time) begin
                        envelope_counter <= envelope_counter + 1;
                        envelope_level <= sustain_level * (release_time - envelope_counter) / release_time; // Liberación
                    end else begin
                        envelope_counter <= 8'd0;
                        envelope_level <= 8'd0; // Fin de la nota
                        state <= 4'd0; // Volver al estado idle
                    end
                end
                default: state <= 4'd0; // Estado por defecto
            endcase
        end
    end

    // Asignar el valor de la onda diente de sierra modulado por el ADSR
    always @(posedge clk) begin
        wave_out <= (counter * envelope_level) / 8'd255; // Modulación de la onda
    end

endmodule
