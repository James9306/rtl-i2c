module i2c_master(
    input  logic        i_clk,
    input  logic        i_rst_n, // active low switch 
    input  logic [7:0]  din,
    input  logic [31:0] i_clk_dvsr,
    input  logic [2:0]  i_cmd,
    input  logic        i_wr_cmd,
    inout  tri          sda,
    output logic [7:0]  dout,
    output tri          scl,
    output logic        o_ready,
    output logic        o_ack,
    output logic        o_done
);

    localparam START_CMD   = 3'b000;
    localparam STOP_CMD    = 3'b001;
    localparam RESTART_CMD = 3'b010;
    localparam WR_CMD      = 3'b011;
    localparam RD_CMD      = 3'b100;

    localparam MSB = 7;
    localparam LSB = 0;

    typedef enum {
        IDLE, START1, START2, HOLD, RESTART, 
        STOP1, STOP2, DATA1, DATA2, DATA3, DATA4, DATA_END
    } state_type;

    state_type state, n_state;
    logic [31:0] count, n_count;
    logic scl_drive_h, n_scl_drive_h;
    logic sda_drive_h, n_sda_drive_h;
    logic ready, n_ready;
    logic [3:0] d_count, n_d_count;
    logic [2:0] cmd_reg, n_cmd_reg;
    logic [7:0] din_reg, n_din_reg;
    logic [7:0] rx_reg, n_rx_reg;
    logic ack, n_ack;
    logic done, n_done;

    always_ff @ (posedge i_clk) begin
        if (!i_rst_n) begin 
            state <= IDLE;
            scl_drive_h <= 1;
            sda_drive_h <= 1;
            count <= 0;
            ready <= 0;
            cmd_reg <= 0;
            d_count <= 0;
            din_reg <= 0;
            rx_reg <= 0;
            ack <= 0;
            done <= 0;
        end 
        else begin
            state <= n_state;
            scl_drive_h <= n_scl_drive_h;
            sda_drive_h <= n_sda_drive_h;
            count <= n_count;
            ready <= n_ready;
            d_count <= n_d_count;
            cmd_reg <= n_cmd_reg;
            din_reg <= n_din_reg;
            rx_reg <= n_rx_reg;
            ack <= n_ack;
            done <= n_done;
        end
    end

    always_comb begin
        n_state = state;
        n_scl_drive_h = scl_drive_h;
        n_sda_drive_h = sda_drive_h;
        n_count = count;
        n_ready = ready;
        n_cmd_reg = cmd_reg;
        n_din_reg = din_reg;
        n_rx_reg = rx_reg;
        n_d_count = d_count;
        n_ack = ack;
        n_done = done;
        case (state) 
            IDLE: begin
                n_scl_drive_h = 1;
                n_sda_drive_h = 1;
                n_ready = 1;
                if ((i_cmd == START_CMD) && i_wr_cmd) begin
                    n_state = START1;
                    n_cmd_reg = i_cmd;
                end
            end

            START1: begin
                n_sda_drive_h = 0; 
                n_ready = 0;
                if (count < ((i_clk_dvsr >> 1) - 1)) begin
                    n_count = count + 1;
                end
                else begin
                    n_state = START2;
                end
            end 

            START2: begin
                n_scl_drive_h = 0;
                if (count < (i_clk_dvsr - 1)) begin
                    n_count = count + 1;
                end
                else begin
                    n_state = HOLD;
                    n_count = 0;
                end
            end

            HOLD: begin
                n_scl_drive_h = 0;
                n_sda_drive_h = 0;
                n_ready = 1;
                if (((i_cmd == WR_CMD) || (i_cmd == RD_CMD)) && i_wr_cmd) begin
                    n_state = DATA1;
                    n_cmd_reg = i_cmd;
                    n_d_count = 0;
                    n_din_reg = din;
                end
                else if ((i_cmd == STOP_CMD) && i_wr_cmd) begin
                    n_state = STOP1;
                    n_cmd_reg = i_cmd;
                end
                else if ((i_cmd == RESTART_CMD) && i_wr_cmd) begin
                    n_state = RESTART;
                    n_cmd_reg = i_cmd;
                end
            end

            DATA1: begin 
                n_ready = 0;
                if (cmd_reg == WR_CMD && d_count < 8) begin
                    n_sda_drive_h = din_reg[MSB];
                    n_din_reg = din_reg << 1;
                end
                else if (cmd_reg == WR_CMD) begin
                    n_sda_drive_h = 0; 
                end
                else if (cmd_reg == RD_CMD && d_count >= 8) begin
                    n_sda_drive_h = din_reg[LSB]; // send ack
                end

                if (count < (i_clk_dvsr >> 2) - 1) begin
                    n_count = count + 1;
                end
                else begin
                    n_state = DATA2;
                    n_count = 0;
                end
            end 

            DATA2: begin
                n_scl_drive_h = 1;
                if (count < (i_clk_dvsr >> 2) - 1) begin
                    n_count = count + 1;
                end
                else begin
                    n_state = DATA3;
                    n_count = 0;
                end
            end

            DATA3: begin
                if (cmd_reg == RD_CMD && !count) begin
                    n_rx_reg = {rx_reg[6:0], sda};
                end
                else if (cmd_reg == WR_CMD && d_count >= 8) begin
                    n_ack = sda;
                end

                if (count < (i_clk_dvsr >> 2) - 1) begin
                    n_count = count + 1;
                end
                else begin
                    n_state = DATA4;
                    n_count = 0;
                end
            end

            DATA4: begin
                n_scl_drive_h = 0;
                if (count < (i_clk_dvsr >> 2) - 1) begin
                    n_count = count + 1;
                end
                else if (d_count < 8) begin
                    n_state = DATA1;
                    n_d_count = d_count + 1;
                    n_count = 0;
                end
                else begin
                    n_state = DATA_END;
                    n_count = 0;
                end
            end

            DATA_END: begin
                n_sda_drive_h = 0;
                n_done = 1;
                n_d_count = 0;
                if (count < (i_clk_dvsr >> 2) - 1) begin
                    n_count = count + 1;
                end
                else begin
                    n_state = HOLD;
                    n_count = 0;
                    n_done = 0;
                end
            end



        endcase
    end 

    assign o_ack = ack;
    assign o_ready = ready;
    assign o_done = done;
    assign scl = scl_drive_h ? 1'bz : 1'b0;
    assign sda = sda_drive_h ? 1'bz : 1'b0;

endmodule

