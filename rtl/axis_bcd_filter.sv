`timescale 1ns/1ps

module axis_bcd_filter #(
    parameter CHECK_BCD = 1 // 1 = filter | 0 = pass all 
) (
    input wire clk,
    input wire rst,

    axis_if.slave  s_axis,
    axis_if.master m_axis
);

    wire [3:0] tens = s_axis.tdata[7:4];
    wire [3:0] units = s_axis.tdata[3:0];

    wire [6:0] dec_value = (tens << 3) + (tens << 1) + units; // 8tens + 2tens + units

    wire bcd_valid = (tens <= 4'd9) && (units <= 4'd9);
    wire div_by_4  = (dec_value[1:0] == 2'b00);

    wire pass;
    generate
        if (CHECK_BCD) begin : check_bcd
            assign pass = bcd_valid && div_by_4;
        end else begin : no_check_bcd
            assign pass = div_by_4;
        end
    endgenerate

    logic       obuf_valid;
    logic [7:0] obuf_data;

    assign s_axis.tready = ~obuf_valid;
    
    assign m_axis.tvalid = obuf_valid;
    assign m_axis.tdata  = obuf_data;

    always @(posedge clk) begin
        if (rst) begin
            obuf_valid <= 1'b0;
            obuf_data  <= 8'b0;
        end else begin
            if (obuf_valid && m_axis.tready) begin
                obuf_valid <= 1'b0;
            end
            
            if (s_axis.tready && s_axis.tvalid) begin
                if (pass) begin
                    obuf_valid <= 1'b1;
                    obuf_data  <= s_axis.tdata;
                end else begin
                    obuf_valid <= 1'b0;
                end
            end
        end
    end 

endmodule