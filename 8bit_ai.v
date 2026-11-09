// ECE M216A Lab 1C: three alternative 8-bit adders for power comparison.
// Verilog-2001 (does not require read_hdl -sv).
// Choose ONE top module in Genus for each run.
// Port order and names: a[7:0], b[7:0], cin, sum[7:0], cout.

// Candidate 1: shared XOR propagate and AND generate.
module low_power_pg_8 (
    input  wire [7:0] a,
    input  wire [7:0] b,
    input  wire       cin,
    output wire [7:0] sum,
    output wire       cout
);
    wire [7:0] p, g;
    wire [8:0] c;
    genvar i;

    assign p = a ^ b;
    assign g = a & b;
    assign c[0] = cin;
    assign sum = p ^ c[7:0];
    assign cout = c[8];

    generate
        for (i = 0; i < 8; i = i + 1) begin : CARRY
            assign c[i+1] = g[i] | (p[i] & c[i]);
        end
    endgenerate
endmodule

// Candidate 2: share XOR propagate between sum and MUX carry logic.
// If a[i] == b[i], carry-out equals a[i]; otherwise carry-out equals carry-in.
module low_power_mux_8 (
    input  wire [7:0] a,
    input  wire [7:0] b,
    input  wire       cin,
    output wire [7:0] sum,
    output wire       cout
);
    wire [7:0] p;
    wire [8:0] c;
    genvar i;

    assign p = a ^ b;
    assign c[0] = cin;
    assign sum = p ^ c[7:0];
    assign cout = c[8];

    generate
        for (i = 0; i < 8; i = i + 1) begin : CARRY
            assign c[i+1] = p[i] ? c[i] : a[i];
        end
    endgenerate
endmodule

// Candidate 3: OR-propagate for carry, XOR-propagate for sum.
// The carry identity is (a & b) | ((a | b) & cin).
module low_power_or_8 (
    input  wire [7:0] a,
    input  wire [7:0] b,
    input  wire       cin,
    output wire [7:0] sum,
    output wire       cout
);
    wire [7:0] p_xor, p_or, g;
    wire [8:0] c;
    genvar i;

    assign p_xor = a ^ b;
    assign p_or  = a | b;
    assign g     = a & b;
    assign c[0] = cin;
    assign sum = p_xor ^ c[7:0];
    assign cout = c[8];

    generate
        for (i = 0; i < 8; i = i + 1) begin : CARRY
            assign c[i+1] = g[i] | (p_or[i] & c[i]);
        end
    endgenerate
endmodule