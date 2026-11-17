// Arithmetic unit, purely combinational
module alu (
        input logic [31:0] a_i,
        input logic [31:0] b_i,
        input cpu_pkg::instr_type_e op_i,
        output logic [31:0] result_o
);

    import cpu_pkg::*;

    always_comb begin
        case (op_i)
            ADDI, ADD, LOAD, STORE: result_o = a_i + b_i;
            SUB: result_o = a_i - b_i;
            SLL: result_o = a_i << b_i[4:0];
            SRL: result_o = a_i >> b_i[4:0];
            default: result_o = 32'd0;
        endcase
    end

endmodule
