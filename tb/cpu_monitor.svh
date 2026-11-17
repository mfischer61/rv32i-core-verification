/*
 * Watches the DUT interface and sends observed events to the scoreboard. It
 * keeps enough state to match requests with responses, including responses
 * that take more than one cycle.
 */
class cpu_monitor #(int DataSize=32, int AddrSize=14);

    virtual interface cpu_if #(.DataSize(DataSize), .AddrSize(AddrSize)) cpuVif;

    mailbox #(cpu_xbar_item #(DataSize, AddrSize)) mon_box;

    // State for external reads
    bit                  pending_read;                 // A read is waiting for rready
    logic [AddrSize-1:0] pending_read_addr;            // Address of that read

    // State for CPU data-memory requests
    bit                  load_in_flight;    // A CPU load is waiting for data
    logic [9:0]          load_addr;         // Address of that load
    bit                  prev_store_valid;  // A store was still active last cycle
    logic [9:0]          prev_store_addr;   // Address of that store
    logic [DataSize-1:0] prev_store_data;   // Data for that store
    bit                  prev_load_valid;   // A load was still active last cycle
    logic [9:0]          prev_load_addr;    // Address of that load

    // Detecting state changes
    bit prev_cpu_active;          // Previous CPU memory-ownership state
    bit prev_cpu_halted;          // Previous CPU halt state
    bit prev_reset;               // Previous reset state
    int errors;                   // Number of interface errors found

    bit log_transactions;         // Optional transaction logging flag

    // Constructor
    function new(virtual interface cpu_if #(DataSize, AddrSize) cpuVif);
        this.cpuVif = cpuVif;
        this.mon_box = new();
        this.pending_read     = 1'b0;
        this.load_in_flight   = 1'b0;
        this.prev_store_valid = 1'b0;
        this.prev_load_valid  = 1'b0;
        this.prev_cpu_active  = 1'b0;
        this.prev_cpu_halted  = 1'b0;
        this.prev_reset       = 1'b0;
        this.log_transactions = 1'b1;
        this.errors           = 0;
    endfunction: new

    // Create a transaction for an observed event and send it to the scoreboard
    task send(input trans_kind_e kind,
              input logic [AddrSize-1:0] addr, input logic [DataSize-1:0] data,
              input logic is_write=1'b0);
        cpu_xbar_item #(DataSize, AddrSize) trans;

        // TODO: Create and send an xbar transaction through the mailbox
        trans = new();
        trans.kind = kind;
        trans.addr = addr;
        trans.data = data;
        trans.is_write = is_write;
        mon_box.put(trans);
    endtask: send

    // Match each external read request with its response
    task observe_external_read();
        // TODO: Match each external read request with its response. Save
        // the address when the request starts, and send one XBAR_READ when rready
        // shows that rdata is valid. How should you handle register file vs SRAM
        // reads?
        if (!pending_read) begin
            pending_read_addr = cpuVif.cb.addr;
            pending_read = 1'b1;
        end

        if(cpuVif.cb.rready) begin
            send(XBAR_READ, pending_read_addr, cpuVif.cb.rdata, 1'b0);
            pending_read = 1'b0;
        end

    endtask: observe_external_read

    // Report each CPU data-memory request once
    task observe_cpu_memory();
        bit curr_req;
        bit curr_store;

        curr_req   = cpuVif.cb.cpu_active && cpuVif.cb.dsram_en;
        curr_store = curr_req && cpuVif.cb.dsram_write_en;

        // sram_wrapper registers rdata_valid <= en, so a load issued last
        // cycle has its data on dsram_rdata now. Send it before tracking a
        // new request so back-to-back loads stay in order.
        if (load_in_flight) begin
            send(CPU_LOAD, word_addr(DSRAM_BASE, load_addr), cpuVif.cb.dsram_rdata);
            load_in_flight = 1'b0;
        end

        // The SRAM writes on every enabled edge, so each store cycle is a store.
                if (curr_store) begin
            if (!(prev_store_valid && cpuVif.cb.dsram_addr == prev_store_addr &&
                  cpuVif.cb.dsram_wdata == prev_store_data)) begin
                send(CPU_STORE, word_addr(DSRAM_BASE, cpuVif.cb.dsram_addr),
                     cpuVif.cb.dsram_wdata, 1'b1);
            end
            prev_store_addr = cpuVif.cb.dsram_addr;
            prev_store_data = cpuVif.cb.dsram_wdata;
        end


        prev_store_valid = curr_store;

        // A new load address starts a load; the same address held while the
        // CPU waits for rready is the same load
        if (curr_req && !curr_store) begin
            if (!(prev_load_valid && cpuVif.cb.dsram_addr == prev_load_addr)) begin
                load_in_flight = 1'b1;
                load_addr      = cpuVif.cb.dsram_addr;
            end
            prev_load_addr = cpuVif.cb.dsram_addr;
        end
        prev_load_valid = curr_req && !curr_store;
    endtask: observe_cpu_memory

    // Monitor the DUT once per clock and pass new events to the scoreboard
    task run();
        forever begin
            @(cpuVif.cb);

            if (cpuVif.cb.reset && !prev_reset) begin
                send(DUT_RESET, '0, '0);
                pending_read = 1'b0;
                load_in_flight = 1'b0;
                prev_store_valid = 1'b0;
                prev_load_valid = 1'b0;
                $display($stime, " Mon: Reset asserted\n");
            end
            prev_reset = cpuVif.cb.reset;

            if (cpuVif.cb.cpu_active && !prev_cpu_active) begin
                send(CPU_START, '0, '0);
                $display($stime, " Mon: CPU started executing\n");
            end

            if (cpuVif.cb.cpu_halted && !prev_cpu_halted) begin
                send(CPU_HALT, '0, '0);
                $display($stime, " Mon: cpu_halted_o asserted\n");
            end

            if (cpuVif.cb.w_en && !cpuVif.cb.cpu_active) begin
                if (log_transactions) begin
                    $display($stime, " Mon: External write Addr: 0x%04x, Data: 0x%08x\n",
                             cpuVif.cb.addr, cpuVif.cb.wdata);
                end
                
                send(XBAR_WRITE, cpuVif.cb.addr, cpuVif.cb.wdata, 1'b1);
            end

            if ((cpuVif.cb.r_en && !cpuVif.cb.cpu_active) || pending_read) begin
                observe_external_read();
            end

            if (load_in_flight || (cpuVif.cb.cpu_active && cpuVif.cb.dsram_en) ||
                prev_store_valid || prev_load_valid) begin
                observe_cpu_memory();
            end

            prev_cpu_active = cpuVif.cb.cpu_active;
            prev_cpu_halted = cpuVif.cb.cpu_halted;
        end
    endtask: run

endclass: cpu_monitor