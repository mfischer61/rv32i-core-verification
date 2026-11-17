// RV32I instruction decoder.
// Pure combinational: given one instruction word, produce the operation type,
// the register addresses, and the correctly sign-extended immediate.
module decode (
	input  logic [31:0]         instr_i,

	output cpu_pkg::instr_type_e instr_type_o,
	output logic [4:0]          rs1_addr_o,
	output logic [4:0]          rs2_addr_o,
	output logic [4:0]          rd_addr_o,
	output logic [31:0]         imm_o
);

    import cpu_pkg::*;

    // === Opcodes, instr[6:0] == //
    localparam logic [6:0] OP_RTYPE = 7'b0110011; /// add, sub, sll, srl
    localparam logic [6:0] OP_ITYPE  = 7'b0010011; // addi
	localparam logic [6:0] OP_LOAD   = 7'b0000011; // lw
	localparam logic [6:0] OP_STORE  = 7'b0100011; // sw
	localparam logic [6:0] OP_BRANCH = 7'b1100011; // beq
	localparam logic [6:0] OP_SYSTEM = 7'b1110011; // ebreak

	localparam logic [6:0] F7_BASE   = 7'b0000000; // add, sll, srl
	localparam logic [6:0] F7_ALT    = 7'b0100000; // sub (and sra, unsupported)
	localparam logic [31:0] INSTR_EBREAK = 32'h0010_0073;

    // == Fixed field positions == //
    // rs1/rs2/rd sit at the same bits in every format that uses them
    // so these are unconditional wires that don't need decoding before 
    // register reads
    logic [6:0] opcode;
    logic [2:0] funct3;
    logic [6:0] funct7;

    assign opcode = instr_i[6:0];
    assign funct3 = instr_i[14:12];
    assign funct7 = instr_i[31:25];

    assign rs1_addr_o = instr_i[19:15];
    assign rs2_addr_o = instr_i[24:20];
    assign rd_addr_o = instr_i[11:7];

    // === Immediate assembly === //
    logic[31:0] imm_i_type;
    logic[31:0] imm_s_type;
    logic[31:0] imm_b_type;

    assign imm_i_type = {{20{instr_i[31]}}, instr_i[31:20]};

	assign imm_s_type = {{20{instr_i[31]}}, instr_i[31:25], instr_i[11:7]};

	assign imm_b_type = {{19{instr_i[31]}}, instr_i[31], instr_i[7],
	                     instr_i[30:25], instr_i[11:8], 1'b0};

    // == Operation decoding == //
    always_comb begin
        instr_type_o = NOP;

        case (opcode)
            OP_RTYPE: begin
                case (funct3)
                    3'b000: begin
                        if (funct7 == F7_BASE) instr_type_o = ADD;
                        else if (funct7 == F7_ALT) instr_type_o = SUB;
                    end
                    3'b001: if (funct7 == F7_BASE) instr_type_o = SLL;
					3'b101: if (funct7 == F7_BASE) instr_type_o = SRL;
					default: ;
                endcase
            end

            OP_ITYPE:  if (funct3 == 3'b000) instr_type_o = ADDI;
			OP_LOAD:   if (funct3 == 3'b010) instr_type_o = LOAD;
			OP_STORE:  if (funct3 == 3'b010) instr_type_o = STORE;
			OP_BRANCH: if (funct3 == 3'b000) instr_type_o = BEQ;
			OP_SYSTEM: if (instr_i == INSTR_EBREAK) instr_type_o = EBREAK;

            default: ;
        endcase
    end

    // == Immediate selection === //
    always_comb begin
        case (instr_type_o)
            ADDI, LOAD: imm_o = imm_i_type;
            STORE: imm_o = imm_s_type;
            BEQ: imm_o = imm_b_type;
            default: imm_o = 32'd0;
        endcase
    end

endmodule


