`timescale 1ns/1ps

module tb_i2c_master;

    logic        i_clk = 0;
    logic        i_rst_n = 1; // active low switch 
    logic [7:0]  din;
    logic [31:0] qtr_dvsr = 125; // 50MHz / (100kHz * 4)
    logic [2:0]  i_cmd;
    logic        i_wr_cmd;
    tri1          sda;
    logic [7:0]  dout;
    tri1          scl;
    logic        o_ready;
    logic        o_ack;
    logic        o_done;

    logic tb_sda_high;
    logic tb_scl_high;

    assign scl = tb_scl_high ? z : 0;
    assign sda = tb_sda_high ? z : 0;

    always #10 i_clk = ~i_clk; // 50MHz clock

    clocking cb @(posedge i_clk);
        default input #1step output #1ns;
        output i_rst_n, din, qtr_dvsr, i_cmd, i_wr_cmd;
        input  dout, o_ready, o_ack, o_done;
    endclocking

    initial begin
        reset();

    end

    i2c_master i2c_master_inst(
        .i_clk(i_clk),
        .i_rst_n(i_rst_n),
        .din(din),
        .qtr_dvsr(qtr_dvsr),
        .i_cmd(i_cmd),
        .i_wr_cmd(i_wr_cmd),
        .sda(sda),
        .dout(dout),
        .scl(scl),
        .o_ready(o_ready),
        .o_ack(o_ack),
        .o_done(o_done)
    );
    
    task automatic reset();
        @(cb);
        cb.i_rst_n <= 0;
        @(cb);
        cb.i_rst_n <= 1;
    endtask

    task automatic write(logic [7:0] din, logic [2:0] cmd);
        @(cb);
        cb.din <= din;
        cb.i_cmd <= cmd;
        cb.i_wr_cmd <= 1;

        wait(!cb.o_ready);
        @(cb);
        cb.i_wr_cmd <= 0;
    endtask

    task automatic wait_done();
        wait(o_done);
        @(cb);
    endtask


endmodule
