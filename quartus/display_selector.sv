module display_selector (
    input  logic best_sw, last_sw, avg_sw,
    output logic [1:0] sel
);
    always_comb begin
        if (avg_sw)       sel = 2'd3; 
        else if (last_sw) sel = 2'd2; 
        else if (best_sw) sel = 2'd1; 
        else              sel = 2'd0; 
    end
endmodule