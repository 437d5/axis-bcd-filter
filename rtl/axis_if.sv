`timescale 1ns/1ps

interface axis_if # (parameter DATA_WIDTH = 8);
    logic                  tvalid;
    logic                  tready;
    logic [DATA_WIDTH-1:0] tdata;

    modport master (
        output tvalid,
        input  tready,
        output tdata
    );

    modport slave (
    input  tvalid,
    output tready,
    input  tdata
    );

endinterface //axis_if # (parameter DATA_WIDTH = 8;)