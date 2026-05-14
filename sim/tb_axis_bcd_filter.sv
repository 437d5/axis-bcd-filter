`timescale 1ns/1ps

module tb_axis_bcd_filter;

    parameter CHECK_BCD = 1;
    parameter CLK_PERIOD = 10;
    parameter TIMEOUT_CYC = 1_000_000;

    logic clk;
    logic rst;

    axis_if #(.DATA_WIDTH(8)) s_axis();
    axis_if #(.DATA_WIDTH(8)) m_axis();

    axis_bcd_filter #(.CHECK_BCD(CHECK_BCD)) dut (
        .clk(clk),
        .rst(rst),
        .s_axis(s_axis),
        .m_axis(m_axis)
    );

    initial clk = 0;
    always #(CLK_PERIOD/2) clk = ~clk;

    logic [7:0] expected_q[$]; // queue of expected output
    int         sent_cnt;      // count of sent words
    int         pass_cnt;      // count of words that should pass
    int         recv_cnt;      // count of received words
    int         error_cnt;     // count of mismatches

    function automatic logic pass(input logic [7:0] data);
        logic [3:0] t;
        logic [3:0] u;
        int val;
        
        t = data[7:4];
        u = data[3:0];
        
        if (CHECK_BCD && (t > 9 || u > 9))
            return 1'b0;
            
        val = t * 10 + u;
        return (val % 4 == 0);
    endfunction

    task automatic send_word(input logic [7:0] data);
        if (pass(data)) begin 
            expected_q.push_back(data);
            pass_cnt++;
        end
        sent_cnt++;

        @(posedge clk);
        s_axis.tvalid <= 1'b1;
        s_axis.tdata  <= data;

        do begin
            @(posedge clk);
        end while (!s_axis.tready);
        
        s_axis.tvalid <= 1'b0; 
        s_axis.tdata  <= 8'hxx;
    endtask

    initial begin
        logic [3:0] t, u;
        int val;

        recv_cnt = 0;
        error_cnt = 0;
        m_axis.tready = 1'b0;

        forever begin
            @(posedge clk);
            if (m_axis.tvalid && m_axis.tready) begin
                recv_cnt++;

                t = m_axis.tdata[7:4];
                u = m_axis.tdata[3:0];
                val = t * 10 + u;
                
                if (val % 4 !== 0) begin
                    $display("[ERROR] @%0t: received 0x%02h (%0d) is not div by 4", $time, m_axis.tdata, val);
                    error_cnt++;
                end else begin
                    automatic logic [7:0] exp = expected_q.pop_front();
                    if (m_axis.tdata !== exp) begin
                        $display("[ERROR] @%0t: order mismatch; got: 0x%02h, exp: 0x%02h", $time, m_axis.tdata, exp);
                        error_cnt++;
                    end
                end
            end 
        end
    end

    task automatic random_ready(input int cycles);
        repeat (cycles) begin
            @(posedge clk);
            m_axis.tready <= $urandom_range(0, 1);
        end
    endtask

    task automatic drain(input int max_cycles = 200);
        int i = 0;
        m_axis.tready <= 1'b1;
        
        while (i < max_cycles && expected_q.size() != 0) begin
            @(posedge clk);
            i++;
        end
        
        if (expected_q.size() != 0) begin
            $display("[ERROR] drain timeout: %0d words left", expected_q.size());
            error_cnt++;
        end
    endtask

    task automatic do_reset;
        s_axis.tvalid <= 1'b0;
        s_axis.tdata  <= 8'h00;
        m_axis.tready <= 1'b0;
        rst           <= 1'b1;
        repeat (4) @(posedge clk);
        rst <= 1'b0;
        @(posedge clk);
    endtask

    function automatic logic [7:0] bcd_of(input int v);
        return {4'(v / 10), 4'(v % 10)};
    endfunction

    task automatic directed;
        int v;
        $display("Directed test: 0..99, tready=1");
        m_axis.tready <= 1'b1;
        for (v = 0; v <= 99; v++) begin
            send_word(bcd_of(v));
        end
        drain();
        $display("sent=%0d, pass=%0d, recv=%0d, error=%0d", sent_cnt, pass_cnt, recv_cnt, error_cnt);
    endtask

    task automatic test_random;
        int i;
        logic [3:0] t, u;
        logic [7:0] word;
        
        $display("Random test: 500 random values, random tready");
        fork
            begin
                for (i = 0; i < 500; i++) begin
                    if ($urandom_range(0, 9) < 7) begin
                        t    = 4'($urandom_range(0, 9));
                        u    = 4'($urandom_range(0, 9));
                        word = {t, u};
                    end else begin
                        word = 8'($urandom_range(0, 255));
                        if (word[7:4] <= 9 && word[3:0] <= 9)
                            word[7:4] = 4'($urandom_range(10, 15));
                    end
                    
                    if ($urandom_range(0, 2) == 0) begin
                        s_axis.tvalid <= 1'b0;
                        repeat($urandom_range(1,3)) @(posedge clk);
                    end
                    send_word(word);
                end
            end
            random_ready(1000);
        join_any

        m_axis.tready <= 1'b1;
        drain(500);
        $display("sent=%0d, pass=%0d, recv=%0d, error=%0d", sent_cnt, pass_cnt, recv_cnt, error_cnt);
    endtask

    initial begin
        $dumpfile("tb_axis_bcd_filter.vcd");
        $dumpvars(0, tb_axis_bcd_filter);

        sent_cnt  = 0;
        pass_cnt  = 0;
        recv_cnt  = 0;
        error_cnt = 0;

        do_reset();
        directed();

        do_reset();
        sent_cnt = 0; pass_cnt = 0; recv_cnt = 0;
        test_random();

        repeat(10) @(posedge clk);
        $display("\n============================================================");
        if (error_cnt == 0)
            $display("RESULT: PASS - all checks passed.");
        else
            $display("RESULT: FAIL - %0d error(s) detected.", error_cnt);
        $display("============================================================\n");
        $finish;
    end

    initial begin
        #(CLK_PERIOD * TIMEOUT_CYC);
        $display("[WATCHDOG] Simulation timeout after %0d cycles", TIMEOUT_CYC);
        $finish;
    end
    
endmodule