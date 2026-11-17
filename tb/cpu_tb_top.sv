/*
 * Top-level testbench
 */
module cpu_tb_top;

    import cpu_tb_pkg::*;

    parameter int DataSize = DATA_W;
    parameter int AddrSize = XBAR_AW;

    string requested_seed = "default";

    int assertion_errors = 0;

    logic clk = 0;
    always #5 clk = ~clk;

    // IF instantiation
    cpu_if #(.DataSize(DataSize), .AddrSize(AddrSize)) cpu_if(.clk(clk));

    // DUT instantiation
    chip_top dut (
        .clk_i(clk),
        .rst_i(cpu_if.cpu.reset),
        .en_cpu_i(cpu_if.cpu.en_cpu),
        .halt_cpu_i(cpu_if.cpu.halt_cpu),
        .cpu_halted_o(cpu_if.cpu.cpu_halted),
        .addr_i(cpu_if.cpu.addr),
        .wdata_i(cpu_if.cpu.wdata),
        .w_en_i(cpu_if.cpu.w_en),
        .r_en_i(cpu_if.cpu.r_en),
        .rdata_o(cpu_if.cpu.rdata),
        .rready_o(cpu_if.cpu.rready)
    );

    // Observation signals from the DUT memory path
    assign cpu_if.cpu_active     = dut.cpu_enable_q;
    assign cpu_if.dsram_en       = dut.dsram_en;
    assign cpu_if.dsram_write_en = dut.dsram_write_en;
    assign cpu_if.dsram_addr     = dut.dsram_addr;
    assign cpu_if.dsram_wdata    = dut.dsram_wdata;
    assign cpu_if.dsram_rdata    = dut.dsram_rdata;

    cpu_tb_pkg::cpu_sequencer #(.DataSize(DataSize), .AddrSize(AddrSize)) seqr;
    cpu_tb_pkg::cpu_driver #(.DataSize(DataSize), .AddrSize(AddrSize))    drv;
    cpu_tb_pkg::cpu_monitor #(.DataSize(DataSize), .AddrSize(AddrSize))   mon;
    cpu_tb_pkg::cpu_sb #(.DataSize(DataSize), .AddrSize(AddrSize))        sb;

    // Record failed assertion
    function void assertion_fail(input string message);
        assertion_errors++;
        $error($stime, " ASSERT: %s\n", message);
    endfunction: assertion_fail

    // Initialize both memories through the DUT's external memory port
    task automatic init_memories();
        $display($stime, " TB: Initializing instruction and data memories\n");
        mon.log_transactions = 1'b0;
        sb.log_transactions = 1'b0;
        for (int i = 0; i < ISRAM_WORDS; i++) begin
            seqr.send_write_trans(word_addr(ISRAM_BASE, i), EBREAK_WORD);
        end
        for (int i = 0; i < DSRAM_WORDS; i++) begin
            seqr.send_write_trans(word_addr(DSRAM_BASE, i), $urandom());
        end
        seqr.wait_for_empty();
        repeat (2) @(cpu_if.cb);
        mon.log_transactions = 1'b1;
        sb.log_transactions = 1'b1;
        $display($stime, " TB: Memory initialization complete\n");
    endtask: init_memories

    // Queue external reads on a memory window
    task automatic readback(input int window, input int num_words, input int start_word=0);
        logic [AddrSize-1:0] base;

        case (window)
            0: base = ISRAM_BASE;
            1: base = DSRAM_BASE;
            2: base = REG_BASE;
            default: base = REG_BASE;
        endcase

        for (int i = 0; i < num_words; i++) begin
            seqr.send_read_trans(word_addr(base, start_word + i));
        end
        seqr.wait_for_empty();
        repeat (4) @(cpu_if.cb);
    endtask: readback

    task automatic preload_dmem(input logic [31:0] values [$], input int start_word=0);
        foreach (values[i]) begin
            seqr.send_write_trans(word_addr(DSRAM_BASE, start_word + i), values[i]);
        end
        seqr.wait_for_empty();
        repeat (2) @(cpu_if.cb);
    endtask: preload_dmem

    // Run a directed test
    task automatic run_directed(input string name, const ref logic [31:0] program_words [$],
            input int max_cycles=2000, input int dmem_words=16);
        $display("");
        $display("=================================================================");
        $display(" TEST: %s", name);
        $display("=================================================================");
        sb.set_test(name);

        drv.reset_task();
        seqr.load_program(program_words);
        seqr.wait_for_empty();
        repeat (2) @(cpu_if.cb);
        drv.run_program(max_cycles);

        if (drv.last_run_completed) begin
            readback(2, REG_COUNT);
            readback(1, dmem_words);
        end else begin
            $display($stime, " TB: Skipping %s readback after CPU timeout\n", name);
            drv.reset_task();
        end
    endtask: run_directed

    // Basic smoke test for loading, running, and observing a program that halts
    task automatic run_smoke_test();
        logic [31:0] smoke_prog [$];
        smoke_prog = '{ EBREAK_WORD };
        run_directed("smoke_ebreak", smoke_prog, 100, 1);
    endtask: run_smoke_test

    // Smoke test for stopping the CPU from outside the program
    // Readback is skipped because the CPU stops before the program completes
    task automatic run_external_halt_smoke();
        logic [31:0] long_prog [$];

        for (int i = 0; i < 32; i++) begin
            long_prog.push_back(asm_instr(.op(OP_ADDI), .rd(1), .rs1(1), .imm(1)));
        end
        long_prog.push_back(EBREAK_WORD);

        $display("");
        $display("=================================================================");
        $display(" TEST: smoke_external_halt");
        $display("=================================================================");
        sb.set_test("smoke_external_halt");

        drv.reset_task();
        seqr.load_program(long_prog);
        seqr.wait_for_empty();
        repeat (2) @(cpu_if.cb);
        drv.start_cpu();
        repeat (12) @(cpu_if.cb);
        drv.halt_cpu_now();
        drv.reset_task();
    endtask: run_external_halt_smoke

    

    // TEST PROGRAM
    logic [31:0] prog [$];
    logic [31:0] data [$];

    int NUM_RANDOM_PROGRAMS = 20;
    int NUM_RANDOM_XBAR = 300;

    initial begin
        int total_errors;

        mon = new(cpu_if);
        sb = new(mon.mon_box);
        seqr = new();
        drv = new(cpu_if, seqr.xbar_box);

        void'($value$plusargs("NUM_RANDOM_PROGRAMS=%d", NUM_RANDOM_PROGRAMS));
        void'($value$plusargs("NUM_RANDOM_XBAR=%d", NUM_RANDOM_XBAR));
        if ($test$plusargs("REF_TRACE")) begin
            sb.ref_model.trace = 1'b1;
        end

        fork
            mon.run();
            sb.run();
            drv.run();
        join_none

        drv.reset_task();
        init_memories();

        run_smoke_test();
        run_external_halt_smoke();


        // DIRECTED TESTS
        drv.reset_task();
        init_memories();

        // TODO: Add directed test cases from the test plan
        // Use the existing helpers
        // 1.1 - addi_basic_signs
        prog = '{
        asm_instr(.op(OP_ADDI), .rd(1), .rs1(0), .imm(5)), // x1 = 0 + 5
        asm_instr(.op(OP_ADDI), .rd(2), .rs1(0), .imm(-5)), // x2 = 0 + (-5)
        asm_instr(.op(OP_ADDI), .rd(3), .rs1(1), .imm(100)), // x3 = x1 + 100
        asm_instr(.op(OP_ADDI), .rd(4), .rs1(2), .imm(5)), // x4 = x2 + 5
        EBREAK_WORD
        };
        run_directed("addi_basic_signs", prog);

        // 1.2 - addi_imm_limits
        prog = '{
        asm_instr(.op(OP_ADDI), .rd(1), .rs1(0), .imm(2047)), // largest immediate
        asm_instr(.op(OP_ADDI), .rd(2), .rs1(0), .imm(-2048)), // smallest immediate
        asm_instr(.op(OP_ADDI), .rd(3), .rs1(0), .imm(-1)), // should be all ones
        asm_instr(.op(OP_ADDI), .rd(4), .rs1(3), .imm(1)), // 0xFFFFFFFF + 1 wraps
        asm_instr(.op(OP_ADDI), .rd(5), .rs1(1), .imm(1)), // 2047 + 1 does not wrap
        EBREAK_WORD
        };
        run_directed("addi_imm_limits", prog);

        // 1.3 - add_basic
        prog = '{
        asm_instr(.op(OP_ADDI), .rd(1), .rs1(0), .imm(7)), // x1 = 7
        asm_instr(.op(OP_ADDI), .rd(2), .rs1(0), .imm(-3)), // x2 = -3 = 0xFFFFFFFD
        asm_instr(.op(OP_ADD),  .rd(3), .rs1(1), .rs2(2)), // x3 = x1 + x2
        asm_instr(.op(OP_ADD),  .rd(4), .rs1(2), .rs2(2)), // x4 = x2 + x2
        asm_instr(.op(OP_ADD),  .rd(5), .rs1(1), .rs2(0)),  // x5 = x1 + x0
        asm_instr(.op(OP_ADD),  .rd(6), .rs1(0), .rs2(0)), // x6 = x0 + x0
        EBREAK_WORD
        };
        run_directed("add_basic", prog);

        // 1.4 - add_overflow_wrap
        prog = '{
        asm_instr(.op(OP_ADDI), .rd(1), .rs1(0), .imm(-1)), // x1 = -1 = 0xFFFFFFFF
        asm_instr(.op(OP_ADDI), .rd(2), .rs1(0), .imm(1)), // x2 = 1
        asm_instr(.op(OP_ADD),  .rd(3), .rs1(1), .rs2(2)), // x3 = x1 + x2
        asm_instr(.op(OP_SRL),  .rd(4), .rs1(1), .rs2(2)), // x4 = x1 >> x2
        asm_instr(.op(OP_ADD),  .rd(5), .rs1(4), .rs2(2)),  // x5 = x4 + x2
        asm_instr(.op(OP_ADD),  .rd(6), .rs1(5), .rs2(5)), // x6 = x5 + x5
        EBREAK_WORD
        };
        run_directed("add_overflow_wrap", prog);

        // 1.5 - sub_basic
        prog = '{
        asm_instr(.op(OP_ADDI), .rd(1), .rs1(0), .imm(10)), // x1 = 10
        asm_instr(.op(OP_ADDI), .rd(2), .rs1(0), .imm(3)), // x2 = 3
        asm_instr(.op(OP_SUB),  .rd(3), .rs1(1), .rs2(2)), // x3 = x1 - x2
        asm_instr(.op(OP_SUB),  .rd(4), .rs1(2), .rs2(1)), // x4 = x2 - x1 (order check)
        asm_instr(.op(OP_SUB),  .rd(5), .rs1(1), .rs2(1)),  // x5 = x1 - x1
        asm_instr(.op(OP_SUB),  .rd(6), .rs1(0), .rs2(2)), // x6 = x0 - x2
        asm_instr(.op(OP_SUB),  .rd(7), .rs1(1), .rs2(0)), // x7 = x1 - x0
        EBREAK_WORD
        };
        run_directed("sub_basic", prog);

        // 1.6 - sub_wrap_min_int
        prog = '{
        asm_instr(.op(OP_ADDI), .rd(1), .rs1(0), .imm(1)), // x1 = 1
        asm_instr(.op(OP_ADDI), .rd(2), .rs1(0), .imm(31)), // x2 = 31 (shift amount)
        asm_instr(.op(OP_SLL),  .rd(3), .rs1(1), .rs2(2)), // x3 = 1 << 31 = 0x80000000
        asm_instr(.op(OP_SUB),  .rd(4), .rs1(3), .rs2(1)), // x4 = x3 - 1
        asm_instr(.op(OP_SUB),  .rd(5), .rs1(0), .rs2(3)), // x5 = 0 - x3
        asm_instr(.op(OP_SUB),  .rd(6), .rs1(0), .rs2(1)), // x6 = 0 - x1
        EBREAK_WORD
        };
        run_directed("sub_wrap_min_int", prog);

        // 1.7 - sll_amounts
        prog = '{
        asm_instr(.op(OP_ADDI), .rd(1), .rs1(0), .imm(1)), // x1 = 1
        asm_instr(.op(OP_ADDI), .rd(2), .rs1(0), .imm(0)),  // x2 = 0 (shift amount)
        asm_instr(.op(OP_ADDI), .rd(3), .rs1(0), .imm(31)), // x3 = 31 (shift amount)
        asm_instr(.op(OP_ADDI), .rd(4), .rs1(0), .imm(-1)), // x4 = 0xFFFFFFFF
        asm_instr(.op(OP_SLL),  .rd(6), .rs1(1), .rs2(2)), // x6 = 1 << 0
        asm_instr(.op(OP_SLL),  .rd(7), .rs1(1), .rs2(3)), // x7 = 1 << 31
        asm_instr(.op(OP_SLL),  .rd(8), .rs1(4), .rs2(2)), // x8 = 0xFFFFFFFF << 0
        asm_instr(.op(OP_SLL),  .rd(9), .rs1(4), .rs2(3)), // x9 = 0xFFFFFFFF << 31
        EBREAK_WORD
        };
        run_directed("sll_amounts", prog);

        // 1.8 - srl_logical_fill
        prog = '{
        asm_instr(.op(OP_ADDI), .rd(1), .rs1(0), .imm(1)), // x1 = 1
        asm_instr(.op(OP_ADDI), .rd(2), .rs1(0), .imm(-1)), // x2 = 0xFFFFFFFF
        asm_instr(.op(OP_ADDI), .rd(3), .rs1(0), .imm(31)), // x3 = 31 (shift amount)
        asm_instr(.op(OP_ADDI), .rd(4), .rs1(0), .imm(1)), // x4 = 1 (shift amount)
        asm_instr(.op(OP_ADDI), .rd(5), .rs1(0), .imm(0)), // x5 = 0 (shift amount)
        asm_instr(.op(OP_SLL),  .rd(6), .rs1(1), .rs2(3)), // x6 = 1 << 31 = 0x80000000
        asm_instr(.op(OP_SRL),  .rd(7), .rs1(2), .rs2(4)), // x7 = 0xFFFFFFFF >> 1
        asm_instr(.op(OP_SRL),  .rd(8), .rs1(2), .rs2(3)), // x8 = 0xFFFFFFFF >> 31
        asm_instr(.op(OP_SRL),  .rd(9), .rs1(2), .rs2(5)), // x9 = 0xFFFFFFFF >> 0
        asm_instr(.op(OP_SRL),  .rd(10),.rs1(6), .rs2(3)),  // x10 = 0x80000000 >> 31
        EBREAK_WORD
        };
        run_directed("srl_logical_fill", prog);

        // 1.9 - shift_amount_low5
        prog = '{
        asm_instr(.op(OP_ADDI), .rd(1), .rs1(0), .imm(1)),  // x1 = 1
        asm_instr(.op(OP_ADDI), .rd(2), .rs1(0), .imm(32)), // x2 = 32 -> low 5 bits = 0
        asm_instr(.op(OP_ADDI), .rd(3), .rs1(0), .imm(33)),  // x3 = 33 -> low 5 bits = 1
        asm_instr(.op(OP_ADDI), .rd(4), .rs1(0), .imm(-1)), // x4 = 0xFFFFFFFF -> low 5 bits = 31
        asm_instr(.op(OP_SLL),  .rd(5), .rs1(1), .rs2(2)), // x5 = 1 << (32 & 0x1F) = 1 << 0
        asm_instr(.op(OP_SLL),  .rd(6), .rs1(1), .rs2(3)), // x6 = 1 << (33 & 0x1F) = 1 << 1
        asm_instr(.op(OP_SLL),  .rd(7), .rs1(1), .rs2(4)), // x7 = 1 << (-1 & 0x1F) = 1 << 31
        asm_instr(.op(OP_SRL),  .rd(8), .rs1(7), .rs2(3)), // x8 = 0x80000000 >> (33 & 0x1F) = >> 1
        asm_instr(.op(OP_SRL),  .rd(9), .rs1(7), .rs2(2)),  // x9 = 0x80000000 >> (32 & 0x1F) = >> 0
        EBREAK_WORD
        };
        run_directed("shift_amount_low5", prog);

        // 1.10 - addi_rd_equals_rs1
        prog = '{
        asm_instr(.op(OP_ADDI), .rd(1), .rs1(0), .imm(1)), // x1 = 0 + 1 = 1
        asm_instr(.op(OP_ADDI), .rd(1), .rs1(1), .imm(1)), // x1 = 1 + 1 = 2
        asm_instr(.op(OP_ADDI), .rd(1), .rs1(1), .imm(1)), // x1 = 2 + 1 = 3
        asm_instr(.op(OP_ADDI), .rd(1), .rs1(1), .imm(10)),  // x1 = 3 + 10 = 13
        asm_instr(.op(OP_ADD),  .rd(1), .rs1(1), .rs2(1)),  // x1 = 13 + 13 = 26
        asm_instr(.op(OP_ADD),  .rd(2), .rs1(1), .rs2(0)), // x2 = x1
        EBREAK_WORD
        };
        run_directed("addi_rd_equals_rs1", prog);

        // 1.11 - waw_overwrite
        prog = '{
        asm_instr(.op(OP_ADDI), .rd(1), .rs1(0), .imm(1)), // x1 = 1
        asm_instr(.op(OP_ADDI), .rd(1), .rs1(0), .imm(2)), // x1 = 2 (overwrites and doesn't read old x1)
        asm_instr(.op(OP_ADDI), .rd(1), .rs1(0), .imm(3)), // x1 = 3 (overwrites again)
        asm_instr(.op(OP_ADD),  .rd(2), .rs1(1), .rs2(0)), // x2 = x1
        EBREAK_WORD
        };
        run_directed("waw_overwrite", prog);

        // 1.12 - x0_hardwired
        data = '{32'hDEADBEEF};
        preload_dmem(data, 0);

        prog = '{
        asm_instr(.op(OP_ADDI), .rd(1), .rs1(0), .imm(9)), // x1 = 9
        asm_instr(.op(OP_ADDI), .rd(0), .rs1(0), .imm(5)), // attempt: x0 = 5
        asm_instr(.op(OP_ADD),  .rd(2), .rs1(0), .rs2(1)),  // x2 = x0 + x1, checked right after the attempt
        asm_instr(.op(OP_ADD),  .rd(0), .rs1(1), .rs2(1)),  // attempt: x0 = 18
        asm_instr(.op(OP_SUB),  .rd(0), .rs1(1), .rs2(0)), // attempt: x0 = 9 (also reads x0 as a source)
        asm_instr(.op(OP_SLL),  .rd(0), .rs1(1), .rs2(1)),  // attempt: x0 = 9 << 9
        asm_instr(.op(OP_SRL),  .rd(0), .rs1(1), .rs2(1)),  // attempt: x0 = 9 >> 9
        asm_instr(.op(OP_LW),   .rd(0), .rs1(0), .imm(0)), // attempt: x0 = dmem[0] = 0xDEADBEEF
        asm_instr(.op(OP_ADDI), .rd(3), .rs1(0), .imm(0)), // x3 = x0 + 0 (immediate path)
        asm_instr(.op(OP_ADD),  .rd(4), .rs1(0), .rs2(0)), // x4 = x0 + x0 (register path, right after several write attempts)
        EBREAK_WORD
        };
        run_directed("x0_hardwired", prog);

        // 1.13 - lw_offsets
        data = '{32'h11111111, 32'h22222222, 32'hDEADBEEF, 32'h80000000,
                32'hFFFFFFFF, 32'h00000000, 32'h12345678, 32'hCAFEF00D};
        preload_dmem(data, 0);

        prog = '{
        asm_instr(.op(OP_LW),   .rd(1), .rs1(0), .imm(0)), // x1 = dmem[word 0]
        asm_instr(.op(OP_LW),   .rd(2), .rs1(0), .imm(8)),  // x2 = dmem[word 2]
        asm_instr(.op(OP_ADDI), .rd(3), .rs1(0), .imm(16)), // x3 = 16 (base register, word 4)
        asm_instr(.op(OP_LW),   .rd(4), .rs1(3), .imm(0)), // x4 = dmem[word 4]
        asm_instr(.op(OP_LW),   .rd(5), .rs1(3), .imm(-4)), // x5 = dmem[word 3], negative offset
        asm_instr(.op(OP_LW),   .rd(6), .rs1(3), .imm(8)), // x6 = dmem[word 6], positive offset
        asm_instr(.op(OP_LW),   .rd(7), .rs1(0), .imm(28)), // x7 = dmem[word 7]
        asm_instr(.op(OP_LW),   .rd(8), .rs1(0), .imm(20)),  // x8 = dmem[word 5] = 0, checks a real zero load
        EBREAK_WORD
        };
        run_directed("lw_offsets", prog);

        // 1.14 - sw_offsets
        data = '{11{32'hA5A5A5A5}};
        preload_dmem(data, 0);

        prog = '{
        asm_instr(.op(OP_ADDI), .rd(1), .rs1(0), .imm('h123)),  // x1 = 0x123 (store data)
        asm_instr(.op(OP_ADDI), .rd(2), .rs1(0), .imm(-1)), // x2 = 0xFFFFFFFF (store data)
        asm_instr(.op(OP_ADDI), .rd(3), .rs1(0), .imm(40)),  // x3 = 40 (base register, word 10)
        asm_instr(.op(OP_SW),   .rs1(0), .rs2(1), .imm(0)),  // dmem[word 0]  = x1
        asm_instr(.op(OP_SW),   .rs1(0), .rs2(2), .imm(4)),  // dmem[word 1]  = x2
        asm_instr(.op(OP_SW),   .rs1(0), .rs2(2), .imm(40)), // dmem[word 10] = x2, direct immediate addressing
        asm_instr(.op(OP_SW),   .rs1(3), .rs2(1), .imm(-4)), // dmem[word 9]  = x1, negative offset from x3
        asm_instr(.op(OP_SW),   .rs1(0), .rs2(0), .imm(8)),   // dmem[word 2]  = x0 = 0
        EBREAK_WORD
        };
        run_directed("sw_offsets", prog);

        // 1.15 - sw_then_lw_same_word
        data = '{32'hAAAAAAAA};
        preload_dmem(data, 3);

        prog = '{
        asm_instr(.op(OP_ADDI), .rd(1), .rs1(0), .imm(77)), // x1 = 77 = 0x4D
        asm_instr(.op(OP_SW),   .rs1(0), .rs2(1), .imm(12)), // dmem[word 3] = 0x4D
        asm_instr(.op(OP_LW),   .rd(2), .rs1(0), .imm(12)), // x2 = dmem[word 3] = 0x4D
        asm_instr(.op(OP_ADDI), .rd(2), .rs1(2), .imm(1)), // x2 = 0x4D + 1 = 0x4E
        asm_instr(.op(OP_SW),   .rs1(0), .rs2(2), .imm(12)), // dmem[word 3] = 0x4E
        asm_instr(.op(OP_LW),   .rd(3), .rs1(0), .imm(12)),   // x3 = dmem[word 3] = 0x4E
        EBREAK_WORD
        };
        run_directed("sw_then_lw_same_word", prog);

        // 1.16 - mem_boundaries
        data = '{32'h5A5A5A5A};
        preload_dmem(data, 1023);

        prog = '{
        asm_instr(.op(OP_ADDI), .rd(1), .rs1(0), .imm(2044)),   // x1 = 2044 = byte address of word 511
        asm_instr(.op(OP_ADDI), .rd(2), .rs1(1), .imm(2044)),   // x2 = 4088
        asm_instr(.op(OP_LW),   .rd(3), .rs1(2), .imm(4)),  // x3 = dmem[word 1023] (4088+4=4092)
        asm_instr(.op(OP_ADDI), .rd(4), .rs1(0), .imm(-1)),  // x4 = 0xFFFFFFFF (new store data)
        asm_instr(.op(OP_SW),   .rs1(2), .rs2(4), .imm(4)), // dmem[word 1023] = 0xFFFFFFFF
        asm_instr(.op(OP_LW),   .rd(5), .rs1(2), .imm(4)),   // x5 = dmem[word 1023], confirms the store is visible
        asm_instr(.op(OP_ADDI), .rd(6), .rs1(0), .imm('h111)),  // x6 = 0x111 (store data for word 511)
        asm_instr(.op(OP_SW),   .rs1(1), .rs2(6), .imm(0)), // dmem[word 511] = 0x111, via 0(x1)
        asm_instr(.op(OP_LW),   .rd(7), .rs1(0), .imm(2044)),   // x7 = dmem[word 511], via 2044(x0) -- different address expression
        EBREAK_WORD
        };
        run_directed("mem_boundaries", prog, 2000, 1024);

        // 1.17 - beq_taken_skips
        prog = '{
        asm_instr(.op(OP_ADDI), .rd(1), .rs1(0), .imm(5)), // pc 0:  x1 = 5
        asm_instr(.op(OP_ADDI), .rd(2), .rs1(0), .imm(5)), // pc 4:  x2 = 5
        asm_instr(.op(OP_BEQ),  .rs1(1), .rs2(2), .imm(12)), // pc 8:  taken, target = 8+12 = 20
        asm_instr(.op(OP_ADDI), .rd(3), .rs1(0), .imm(1)), // pc 12: must be skipped
        asm_instr(.op(OP_ADDI), .rd(4), .rs1(0), .imm(1)), // pc 16: must be skipped
        asm_instr(.op(OP_ADDI), .rd(5), .rs1(0), .imm(1)), // pc 20: branch target
        EBREAK_WORD
        };
        run_directed("beq_taken_skips", prog);

        // 1.18 - beq_not_taken
        prog = '{
        asm_instr(.op(OP_ADDI), .rd(1), .rs1(0), .imm(5)), // x1 = 5
        asm_instr(.op(OP_ADDI), .rd(2), .rs1(0), .imm(6)),  // x2 = 6
        asm_instr(.op(OP_BEQ),  .rs1(1), .rs2(2), .imm(8)), // not taken (5 != 6)
        asm_instr(.op(OP_ADDI), .rd(3), .rs1(0), .imm(1)),  // x3 = 1, proves fallthrough (would be skipped if incorrectly taken)
        asm_instr(.op(OP_ADDI), .rd(4), .rs1(0), .imm(1)), // x4 = 1 (base value)
        asm_instr(.op(OP_ADDI), .rd(5), .rs1(0), .imm(31)), // x5 = 31 (shift amount)
        asm_instr(.op(OP_SLL),  .rd(6), .rs1(4), .rs2(5)),  // x6 = 1 << 31 = 0x80000000
        asm_instr(.op(OP_BEQ),  .rs1(6), .rs2(0), .imm(8)), // not taken (0x80000000 != 0), MSB-only difference
        asm_instr(.op(OP_ADDI), .rd(7), .rs1(0), .imm(1)),  // x7 = 1, proves fallthrough again
        EBREAK_WORD
        };
        run_directed("beq_not_taken", prog);

        // 1.19 - beq_x0_and_plus4
        prog = '{
        asm_instr(.op(OP_BEQ),  .rs1(0), .rs2(0), .imm(4)), // pc 0: taken, target = 0+4 = 4
        asm_instr(.op(OP_ADDI), .rd(1), .rs1(1), .imm(1)), // pc 4: x1 = 0 + 1 (must execute exactly once)
        asm_instr(.op(OP_BEQ),  .rs1(0), .rs2(0), .imm(8)), // pc 8: taken, target = 8+8 = 16
        asm_instr(.op(OP_ADDI), .rd(2), .rs1(0), .imm(1)), // pc 12: must be skipped
        asm_instr(.op(OP_ADDI), .rd(3), .rs1(0), .imm(3)), // pc 16: branch target
        EBREAK_WORD
        };
        run_directed("beq_x0_and_plus4", prog);

        // 1.20 - beq_backward_loop
        prog = '{
        asm_instr(.op(OP_ADDI), .rd(1), .rs1(0), .imm(5)), // pc 0:  x1 = 5 (counter)
        asm_instr(.op(OP_ADDI), .rd(2), .rs1(0), .imm(0)), // pc 4:  x2 = 0 (accumulator)
        asm_instr(.op(OP_ADDI), .rd(2), .rs1(2), .imm(3)), // pc 8:  LOOP: x2 += 3
        asm_instr(.op(OP_ADDI), .rd(1), .rs1(1), .imm(-1)), // pc 12: x1 -= 1
        asm_instr(.op(OP_BEQ),  .rs1(1), .rs2(0), .imm(8)), // pc 16: if x1==0, exit (target = 16+8 = 24)
        asm_instr(.op(OP_BEQ),  .rs1(0), .rs2(0), .imm(-12)), // pc 20: else loop back (target = 20-12 = 8)
        asm_instr(.op(OP_ADDI), .rd(4), .rs1(0), .imm(1)), // pc 24: EXIT: x4 = 1
        EBREAK_WORD
        };
        run_directed("beq_backward_loop", prog);

        // 1.21 - beq_over_ebreak
        prog = '{
        asm_instr(.op(OP_ADDI), .rd(1), .rs1(0), .imm(1)), // pc 0:  x1 = 1
        asm_instr(.op(OP_BEQ),  .rs1(0), .rs2(0), .imm(8)), // pc 4:  taken, target = 4+8 = 12
        EBREAK_WORD, // pc 8:  must never retire
        asm_instr(.op(OP_ADDI), .rd(2), .rs1(0), .imm(2)), // pc 12: branch target, x2 = 2
        EBREAK_WORD  // pc 16: real halt
        };
        run_directed("beq_over_ebreak", prog);

        // 1.22 - raw_alu_distances
        prog = '{
        asm_instr(.op(OP_ADDI), .rd(1), .rs1(0), .imm(10)),   // x1 = 10
        asm_instr(.op(OP_ADDI), .rd(2), .rs1(1), .imm(1)), // x2 = x1 + 1, distance 1
        asm_instr(.op(OP_ADDI), .rd(7), .rs1(0), .imm(100)),  // filler, independent of x1
        asm_instr(.op(OP_ADDI), .rd(3), .rs1(1), .imm(2)),    // x3 = x1 + 2, distance 2
        asm_instr(.op(OP_ADDI), .rd(8), .rs1(0), .imm(200)), // filler
        asm_instr(.op(OP_ADDI), .rd(9), .rs1(0), .imm(300)), // filler
        asm_instr(.op(OP_ADDI), .rd(4), .rs1(1), .imm(3)),    // x4 = x1 + 3, distance 3
        asm_instr(.op(OP_ADD),  .rd(5), .rs1(3), .rs2(2)),   // x5 = x3 + x2
        asm_instr(.op(OP_SUB),  .rd(6), .rs1(5), .rs2(4)),   // x6 = x5 - x4
        EBREAK_WORD
        };
        run_directed("raw_alu_distances", prog);

        // 1.23 - load_use_hazards
        data = '{32'd10, 32'd3, 32'h0, 32'h0, 32'h0BADF00D, 32'h0, 32'h0, 32'h0, 32'hFFFFFFFF};
        preload_dmem(data, 0);

        prog = '{
        asm_instr(.op(OP_LW),   .rd(1), .rs1(0), .imm(0)),    // x1 = dmem[0] = 10
        asm_instr(.op(OP_ADDI), .rd(2), .rs1(1), .imm(10)),  // load-use as ALU data: x2 = x1 + 10 = 20
        asm_instr(.op(OP_LW),   .rd(3), .rs1(0), .imm(4)),    // x3 = dmem[1] = 3
        asm_instr(.op(OP_SLL),  .rd(4), .rs1(2), .rs2(3)),  // load-use as shift amount: x4 = x2 << x3 = 20 << 3
        asm_instr(.op(OP_LW),   .rd(6), .rs1(0), .imm(16)),  // x6 = dmem[4] = 0x0BADF00D
        asm_instr(.op(OP_LW),   .rd(7), .rs1(6), .imm(0)),   // load-use as lw base: reads whatever word x6 (a huge address) aliases to
        asm_instr(.op(OP_SW),   .rs1(0), .rs2(6), .imm(32)), // load-use as sw data: dmem[8] = x6 = 0x0BADF00D
        asm_instr(.op(OP_LW),   .rd(9), .rs1(0), .imm(20)),// x9 = dmem[5] = 0
        asm_instr(.op(OP_BEQ),  .rs1(9), .rs2(0), .imm(8)), // load-use as branch operand: taken (0 == x0)
        asm_instr(.op(OP_ADDI), .rd(8), .rs1(0), .imm(99)), // must be skipped
        asm_instr(.op(OP_ADDI), .rd(8), .rs1(0), .imm(0)),  // branch target: x8 = 0
        EBREAK_WORD
        };
        run_directed("load_use_hazards", prog);

        // 1.24 - store_operand_hazards
        prog = '{
        asm_instr(.op(OP_ADDI), .rd(1), .rs1(0), .imm(20)), // x1 = 20 (base, word 5)
        asm_instr(.op(OP_ADDI), .rd(2), .rs1(0), .imm(99)), // x2 = 99 = 0x63
        asm_instr(.op(OP_SW),   .rs1(1), .rs2(2), .imm(0)), // dmem[word 5] = x2; both operands just written
        asm_instr(.op(OP_ADDI), .rd(2), .rs1(2), .imm(1)),  // x2 = 100 = 0x64
        asm_instr(.op(OP_SW),   .rs1(1), .rs2(2), .imm(4)),// dmem[word 6] = x2; data operand just written
        asm_instr(.op(OP_ADDI), .rd(1), .rs1(1), .imm(8)),    // x1 = 28
        asm_instr(.op(OP_SW),   .rs1(1), .rs2(2), .imm(0)), // dmem[word 7] = x2; base operand just written
        EBREAK_WORD
        };
        run_directed("store_operand_hazards", prog);

        // 1.25 - branch_operand_hazard
        prog = '{
        asm_instr(.op(OP_ADDI), .rd(1), .rs1(0), .imm(3)),  // pc 0:  x1 = 3
        asm_instr(.op(OP_ADDI), .rd(2), .rs1(0), .imm(3)),  // pc 4:  x2 = 3
        asm_instr(.op(OP_BEQ),  .rs1(1), .rs2(2), .imm(8)), // pc 8:  taken (3==3), target = 8+8 = 16
        asm_instr(.op(OP_ADDI), .rd(3), .rs1(0), .imm(1)), // pc 12: must be skipped
        asm_instr(.op(OP_ADDI), .rd(1), .rs1(0), .imm(4)),  // pc 16: x1 = 4, rewritten immediately before the next beq
        asm_instr(.op(OP_BEQ),  .rs1(1), .rs2(2), .imm(8)),  // pc 20: not taken (4 != 3)
        asm_instr(.op(OP_ADDI), .rd(4), .rs1(0), .imm(1)),   // pc 24: x4 = 1, proves fallthrough
        EBREAK_WORD
        };
        run_directed("branch_operand_hazard", prog);

        // 1.26 - unsupported_encodings_nop
        prog = '{
        asm_instr(.op(OP_ADDI), .rd(1), .rs1(0), .imm(6)),   // x1 = 6
        asm_instr(.op(OP_ADDI), .rd(2), .rs1(0), .imm(1)),   // x2 = 1
        32'h0020C1B3,  // xor x3, x1, x2   -- unsupported funct3/funct7, must be a no-op
        32'h4020D233, // sra x4, x1, x2   -- unsupported funct7, must be a no-op
        32'h00000000, // reserved/all-zero word -- must be a no-op
        32'h0070A293, // slti x5, x1, 7   -- unsupported funct3, must be a no-op
        32'h12345337,  // lui x6, 0x12345  -- unsupported opcode, must be a no-op
        asm_instr(.op(OP_ADD), .rd(7), .rs1(1), .rs2(2)),    // x7 = x1 + x2, proves normal execution resumed
        EBREAK_WORD
        };
        run_directed("unsupported_encodings_nop", prog);

        // 1.27 - ebreak_stops_execution
        data = '{32'hA5A5A5A5};
        preload_dmem(data, 0);

        prog = '{
        asm_instr(.op(OP_ADDI), .rd(1), .rs1(0), .imm(1)), // x1 = 1
        EBREAK_WORD,         // halts here
        asm_instr(.op(OP_ADDI), .rd(2), .rs1(0), .imm(2)),  // dead code, shouldn't execute
        asm_instr(.op(OP_SW),   .rs1(0), .rs2(2), .imm(0)) // dead code, must never execute
        };
        run_directed("ebreak_stops_execution", prog);

        // 1.28 - restart_after_reset
        prog = '{
        asm_instr(.op(OP_ADDI), .rd(1), .rs1(0), .imm(11)),  // x1 = 11
        asm_instr(.op(OP_ADDI), .rd(2), .rs1(0), .imm(22)),  // x2 = 22
        EBREAK_WORD
        };
        run_directed("restart_after_reset_progA", prog);

        prog = '{
        asm_instr(.op(OP_ADDI), .rd(3), .rs1(0), .imm(3)),   // x3 = 3
        EBREAK_WORD
        };
        run_directed("restart_after_reset_progB", prog);

        // 1.29 - external_port_windows
        drv.reset_task();
        seqr.send_write_trans(word_addr(ISRAM_BASE, 0),    32'hAAAA5555);
        seqr.send_write_trans(word_addr(ISRAM_BASE, 1023), 32'h5555AAAA);
        seqr.send_write_trans(word_addr(DSRAM_BASE, 0),    32'h11112222);
        seqr.send_write_trans(word_addr(DSRAM_BASE, 1023), 32'h33334444);
        seqr.wait_for_empty();

        readback(0, 1, 0);    // ISRAM word 0
        readback(0, 1, 1023); // ISRAM word 1023
        readback(1, 1, 0);     // DSRAM word 0
        readback(1, 1, 1023);  // DSRAM word 1023
        readback(2, 32);// full register window

        init_memories();        // restore known memory state before the next test

        // 1.30 - external_halt_recovery
        begin
        logic [31:0] halt_prog [$];
        for (int i = 0; i < 32; i++) begin
            halt_prog.push_back(asm_instr(.op(OP_ADDI), .rd(1), .rs1(1), .imm(1)));  // 0x00108093
        end
        halt_prog.push_back(EBREAK_WORD);

        drv.reset_task();
        seqr.load_program(halt_prog);
        seqr.wait_for_empty();
        repeat (2) @(cpu_if.cb);
        drv.start_cpu();
        repeat (12) @(cpu_if.cb);
        drv.halt_cpu_now();
        readback(0, 33);        // read back the full 33-word instruction image
        drv.reset_task();
        end

        // 1.31 - unsupported_funct_variants_nop (added during coverage closure)
        prog = '{
            asm_instr(.op(OP_ADDI), .rd(1), .rs1(0), .imm(6)),   // x1 = 6
            asm_instr(.op(OP_ADDI), .rd(2), .rs1(0), .imm(1)),   // x2 = 1
            32'h02208433,  // mul  x8, x1, x2 -- R-type f3=000, bad funct7: x8 must stay 0
            32'h022094B3,  // mulh x9, x1, x2 -- R-type f3=001, bad funct7: x9 must stay 0
            32'h00000503,  // lb   x10, 0(x0)-- LOAD f3=000: x10 must stay 0
            32'h00100023,  // sb   x1, 0(x0) -- STORE f3=000: no store may be observed
            32'h00209463,  // bne  x1, x2, 8 -- BRANCH f3=001: must NOT skip the next instr
            32'h0FF0000F,  // fence            -- opcode 0001111 (bit 3 set): unsupported, no-op
            asm_instr(.op(OP_ADDI), .rd(11), .rs1(0), .imm(1)),  // x11 = 1 proves bne fell through
            asm_instr(.op(OP_ADD), .rd(7), .rs1(1), .rs2(2)),    // x7 = 7 proves normal execution resumed
            EBREAK_WORD
        };
        run_directed("unsupported_funct_variants_nop", prog);

        // 1.32 - pc_far_branch_and_wrap (added during coverage closure)
        // Fill all 1024 words so nothing left over from earlier tests can execute
        begin
            logic [31:0] far_prog [$];
            for (int i = 0; i < ISRAM_WORDS; i++) far_prog.push_back(EBREAK_WORD);
            far_prog[0]    = asm_instr(.op(OP_BEQ), .rs1(1), .rs2(0), .imm(4088)); // x1==0: taken, pc 0x000 -> 0xFF8
            far_prog[1]    = EBREAK_WORD; // reached after the wrap
            far_prog[1022] = asm_instr(.op(OP_ADDI), .rd(1), .rs1(0), .imm(1));  // pc 0xFF8: x1 = 1
            far_prog[1023] = asm_instr(.op(OP_ADDI), .rd(2), .rs1(0), .imm(2));  // pc 0xFFC: x2 = 2, next pc = 0x1000 -> word 0
            // At pc 0x1000, word 0 runs again: beq x1, x0 is now not taken (x1 = 1), so it falls to ebreak at pc 0x1004
            run_directed("pc_far_branch_and_wrap", far_prog, 4000);
        end

                // BUG-HUNT EXPERIMENTS (run with +BUG_EXPERIMENTS; isolate each trigger)
        if ($test$plusargs("BUG_EXPERIMENTS")) begin
            // Bug 1: minimized reproducer
            prog = '{
                asm_instr(.op(OP_ADDI), .rd(1), .rs1(0), .imm(1)),
                asm_instr(.op(OP_ADDI), .rd(2), .rs1(0), .imm(32)),
                asm_instr(.op(OP_SLL),  .rd(3), .rs1(1), .rs2(2)),   // expect x3 = 1
                EBREAK_WORD
            };
            run_directed("exp_shift_min", prog);

            // Bug 1: which rs2 bits matter? bit 5 only, or any bit above [4:0]?
            prog = '{
                asm_instr(.op(OP_ADDI), .rd(1), .rs1(0), .imm(1)),
                asm_instr(.op(OP_ADDI), .rd(2), .rs1(0), .imm(31)),     // [4:0]=31, nothing above
                asm_instr(.op(OP_ADDI), .rd(3), .rs1(0), .imm(32)),     // bit 5 only
                asm_instr(.op(OP_ADDI), .rd(4), .rs1(0), .imm(64)),     // bit 6 only
                asm_instr(.op(OP_ADDI), .rd(5), .rs1(0), .imm(-2048)),  // bits 31:11 only
                asm_instr(.op(OP_SLL),  .rd(10), .rs1(1), .rs2(2)),     // expect 0x80000000
                asm_instr(.op(OP_SLL),  .rd(11), .rs1(1), .rs2(3)),     // expect 1
                asm_instr(.op(OP_SLL),  .rd(12), .rs1(1), .rs2(4)),     // expect 1
                asm_instr(.op(OP_SLL),  .rd(13), .rs1(1), .rs2(5)),     // expect 1
                asm_instr(.op(OP_SRL),  .rd(14), .rs1(10), .rs2(3)),    // expect 0x80000000
                asm_instr(.op(OP_SRL),  .rd(15), .rs1(10), .rs2(4)),    // expect 0x80000000
                EBREAK_WORD
            };
            run_directed("exp_shift_amounts", prog);

            // Bug 2: dmem[0] = 5 so the loaded value differs from the stale 0
            data = '{32'h5};
            preload_dmem(data, 0);

            // Bug 2: minimized reproducer (beq rs1 = load rd, distance 1)
            prog = '{
                asm_instr(.op(OP_LW),   .rd(1), .rs1(0), .imm(0)),   // x1 = 5
                asm_instr(.op(OP_BEQ),  .rs1(1), .rs2(0), .imm(8)),  // 5 != 0: NOT taken
                asm_instr(.op(OP_ADDI), .rd(2), .rs1(0), .imm(1)),   // expect x2 = 1
                EBREAK_WORD
            };
            run_directed("exp_lduse_beq_min", prog);

            // Bug 2: loaded register in the rs2 position
            prog = '{
                asm_instr(.op(OP_LW),   .rd(1), .rs1(0), .imm(0)),
                asm_instr(.op(OP_BEQ),  .rs1(0), .rs2(1), .imm(8)),
                asm_instr(.op(OP_ADDI), .rd(2), .rs1(0), .imm(1)),   // expect x2 = 1
                EBREAK_WORD
            };
            run_directed("exp_lduse_beq_rs2", prog);

            // Bug 2: one independent instruction between lw and beq (distance 2)
            prog = '{
                asm_instr(.op(OP_LW),   .rd(1), .rs1(0), .imm(0)),
                asm_instr(.op(OP_ADDI), .rd(6), .rs1(0), .imm(7)),
                asm_instr(.op(OP_BEQ),  .rs1(1), .rs2(0), .imm(8)),
                asm_instr(.op(OP_ADDI), .rd(2), .rs1(0), .imm(1)),   // expect x2 = 1
                EBREAK_WORD
            };
            run_directed("exp_lduse_beq_dist2", prog);

            // Bug 2 control: same load-use, but consumed by add instead of beq
            prog = '{
                asm_instr(.op(OP_LW),   .rd(1), .rs1(0), .imm(0)),
                asm_instr(.op(OP_ADD),  .rd(3), .rs1(1), .rs2(0)),   // expect x3 = 5
                EBREAK_WORD
            };
            run_directed("exp_lduse_add_control", prog);
                        // Bug 3 candidate: store, then load, then beq on the loaded register
            prog = '{
                asm_instr(.op(OP_ADDI), .rd(3), .rs1(0), .imm(9)),   // x3 = 9 (store data)
                asm_instr(.op(OP_SW),   .rs1(0), .rs2(3), .imm(64)), // dmem[16] = 9 (different word)
                asm_instr(.op(OP_LW),   .rd(1), .rs1(0), .imm(0)),   // x1 = dmem[0] = 5
                asm_instr(.op(OP_BEQ),  .rs1(1), .rs2(0), .imm(8)),  // 5 != 0: not taken
                asm_instr(.op(OP_ADDI), .rd(2), .rs1(0), .imm(1)),   // expect x2 = 1
                EBREAK_WORD
            };
            run_directed("exp_st_ld_beq", prog);   // expect x1 = 5; x1 = 9 means store data leaked

            // Same, but the beq does not read the loaded register
            prog = '{
                asm_instr(.op(OP_ADDI), .rd(3), .rs1(0), .imm(9)),
                asm_instr(.op(OP_SW),   .rs1(0), .rs2(3), .imm(64)),
                asm_instr(.op(OP_LW),   .rd(1), .rs1(0), .imm(0)),
                asm_instr(.op(OP_BEQ),  .rs1(0), .rs2(0), .imm(8)),  // always taken
                asm_instr(.op(OP_ADDI), .rd(2), .rs1(0), .imm(1)),   // skipped: expect x2 = 0
                EBREAK_WORD
            };
            run_directed("exp_st_ld_beq_indep", prog);   // expect x1 = 5

            // Same, but an add consumes the load instead of a beq
            prog = '{
                asm_instr(.op(OP_ADDI), .rd(3), .rs1(0), .imm(9)),
                asm_instr(.op(OP_SW),   .rs1(0), .rs2(3), .imm(64)),
                asm_instr(.op(OP_LW),   .rd(1), .rs1(0), .imm(0)),
                asm_instr(.op(OP_ADD),  .rd(4), .rs1(1), .rs2(0)),   // expect x4 = 5
                EBREAK_WORD
            };
            run_directed("exp_st_ld_add", prog);   // expect x1 = x4 = 5

        end







        // CONSTRAINED-RANDOM TESTS
        // TODO: Add constrained-randomized testing for cpu_seq_item and cpu_xbar_item
        // Use the existing helpers
                drv.reset_task();
        init_memories();   // ISRAM = ebreak, DSRAM = random data for loads to read

        for (int i = 0; i < NUM_RANDOM_PROGRAMS; i++) begin
            int    len;
            string name;

            len  = $urandom_range(1, 40);
            name = $sformatf("random_prog_%0d_len%0d", i, len);
            $display("");
            $display("=================================================================");
            $display(" TEST: %s", name);
            $display("=================================================================");
            sb.set_test(name);

            drv.reset_task();
            seqr.gen_program(len);     // randomize, print, stage ISRAM writes + ebreak
            seqr.wait_for_empty();
            repeat (2) @(cpu_if.cb);
            drv.run_program(2000);

            if (drv.last_run_completed) begin
                readback(2, REG_COUNT);
                readback(1, DSRAM_WORDS);  // random stores can hit any word
            end else begin
                $display($stime, " TB: Skipping %s readback after CPU timeout\n", name);
                drv.reset_task();
            end
        end

        // Random external-port traffic with the CPU idle
        $display("");
        $display("=================================================================");
        $display(" TEST: random_xbar");
        $display("=================================================================");
        sb.set_test("random_xbar");
        drv.reset_task();
        seqr.gen_xbar(NUM_RANDOM_XBAR, 1'b1);
        seqr.wait_for_empty();
        repeat (4) @(cpu_if.cb);


        // TEST FINISH
        repeat (20) @(cpu_if.cb);
        total_errors = sb.errors + drv.timeouts + mon.errors + assertion_errors;
        if (sb.checks == 0) begin
            $error("Testbench performed zero checks; no results were verified");
        end

        $display("=================================================================");
        $display("  Scoreboard mismatches : %0d", sb.errors);
        $display("  Driver timeouts       : %0d", drv.timeouts);
        $display("  Monitor protocol errs : %0d", mon.errors);
        $display("  Assertion failures    : %0d", assertion_errors);
        $display("=================================================================");
        $display();

        if (total_errors == 0) begin
            $display("=================================================================");
            $display(" TEST PASSED!");
            $display("=================================================================");
        end else begin
            $display("=================================================================");
            $display(" TEST FAILED: %0d error(s)", total_errors);
            $display("=================================================================");
        end
        $finish;
    end

    // Stop a broken DUT or testbench instead of letting the simulation run forever
    initial begin
        #10ms;
        $display(" TEST FAILED - global timeout");
        $fatal(1, "global timeout");
    end

    initial begin
        void'($value$plusargs("SEED_LABEL=%s", requested_seed));
        if ($test$plusargs("BUG_HUNT_WAVES")) begin
            $shm_open("bug_hunt_waves.shm");
        end else begin
            $shm_open("waves.shm");
        end
        $shm_probe("AC");
    end

    wire rst = cpu_if.reset;
    // TODO: Add the required protocol or control assertions from the testplan

    // Example assertion
    // It checks one interface rule and sends failures through the testbench counter
    NO_SIMULTANEOUS_READ_WRITE:
        assert property (@(posedge clk) disable iff (rst)
            !(cpu_if.w_en && cpu_if.r_en))
        else assertion_fail("w_en_i and r_en_i were asserted together");
        // 3.1 - A pending instruction/data-SRAM read gets rready exactly one cycle later
        SRAM_READ_RESPONDS_NEXT_CYCLE:
            assert property (@(posedge clk) disable iff (rst)
                (cpu_if.r_en && !cpu_if.rready && !cpu_if.cpu_active &&
                cpu_if.addr[13:12] inside {2'b00, 2'b01})
                |=> cpu_if.rready)
            else assertion_fail("SRAM read did not return rready on the following cycle");

        // 3.2 - A register-window read gets rready in the same cycle
        REG_READ_RESPONDS_SAME_CYCLE:
            assert property (@(posedge clk) disable iff (rst)
                (cpu_if.r_en && !cpu_if.cpu_active && cpu_if.addr[13:12] == 2'b10)
                |-> cpu_if.rready)
            else assertion_fail("register-window read did not return rready in the request cycle");

        // 3.3 - cpu_halted is a one-cycle pulse per ebreak
            HALT_IS_SINGLE_PULSE:
        assert property (@(posedge clk) disable iff (rst)
            $rose(cpu_if.cpu_halted) |=> ##[0:2] !cpu_if.cpu_halted)
        else assertion_fail("cpu_halted did not drop within 3 cycles of rising");


        // 3.4 - the testbench never drives the external port while the CPU owns the memories
        NO_PORT_ACCESS_WHILE_CPU_ACTIVE:
            assert property (@(posedge clk) disable iff (rst)
                cpu_if.cpu_active |-> !(cpu_if.w_en || cpu_if.r_en))
            else assertion_fail("external port was driven while the CPU owned the memories");

        // 3.5 - Every CPU store to data SRAM has a known address and data (no X/Z)
        CPU_STORE_NO_X:
            assert property (@(posedge clk) disable iff (rst)
                (cpu_if.cpu_active && cpu_if.dsram_en && cpu_if.dsram_write_en)
                |-> !$isunknown({cpu_if.dsram_addr, cpu_if.dsram_wdata}))
            else assertion_fail($sformatf("CPU store with unknown addr/data: addr=%0h data=%0h",
                                        $sampled(cpu_if.dsram_addr), $sampled(cpu_if.dsram_wdata)));
        
        // 3.6 - While reset is asserted, the testbench holds every control input idle
        RESET_INPUTS_IDLE:
            assert property (@(posedge clk)
                rst |-> !(cpu_if.w_en || cpu_if.r_en || cpu_if.en_cpu || cpu_if.halt_cpu))
            else assertion_fail("control input asserted while reset was high");

        // 3.7 - One cycle into reset, the DUT's control outputs are cleared
        RESET_OUTPUTS_CLEAR:
            assert property (@(posedge clk)
                rst |=> !(cpu_if.cpu_active || cpu_if.cpu_halted || cpu_if.rready))
            else assertion_fail($sformatf("control output not cleared by reset: active=%0b halted=%0b rready=%0b",
                                        $sampled(cpu_if.cpu_active), $sampled(cpu_if.cpu_halted), $sampled(cpu_if.rready)));


endmodule: cpu_tb_top