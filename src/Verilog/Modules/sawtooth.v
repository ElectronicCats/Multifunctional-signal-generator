module sawtooth_wave_generator (
    input wire clk,            // Reloj de entrada
    input wire reset,          // Señal de reinicio
    output reg [7:0] wave_out  // Salida de onda diente de sierra de 8 bits
);

    reg [7:0] counter;  // Contador para la onda diente de sierra

    // Lógica del generador de onda diente de sierra
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            counter <= 8'd0;  // Reiniciar el contador a 0
        end else begin
            counter <= counter + 1;  // Incrementar el contador
        end
    end

    // Asignar el valor del contador a la salida
    always @(posedge clk) begin
        wave_out <= counter;
    end

endmodule
