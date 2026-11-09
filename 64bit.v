module behavioral_adder_64 (
    input  wire [63:0] a,
    input  wire [63:0] b,
    input  wire       cin,
    output wire [63:0] sum,
    output wire       cout
);

    assign {cout, sum} =
        {1'b0, a} + {1'b0, b} + cin;

endmodule