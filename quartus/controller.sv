// ==========================================================
// Main Controller for Reaction Timer Project - Altera DE0
// Final Adjustments: Faster RUN blink, Slower CELEB animation
// ==========================================================

module controller (
    input  logic clk, rst_n,          // 50MHz Clock, Reset (Active Low)
    input  logic start_n, react_n,    // KEY0 and KEY2
    input  logic [3:0] cur_s_ones, cur_s_tens, cur_m_ones, cur_m_tens, // Stopwatch BCD
    output logic sw_en, sw_rst_n,     // Stopwatch control signals
    output logic [9:0] leds,          // LEDG[0..9] pins 
    output logic [15:0] bcd_avg, bcd_last, bcd_best, bcd_current,
    output logic [2:0] ctrl_state     
);

    // FSM State Definitions
    typedef enum logic [2:0] {
        STARTUP = 3'd0, // Loading animation on power-up
        IDLE    = 3'd1, // Game ready - displays "----"
        CDOWN   = 3'd2, // 3..2..1 Countdown
        WAIT    = 3'd3, // Random wait period
        RUN     = 3'd4, // Reaction time window - LEDs blinking
        RES     = 3'd5, // Show reaction time result
        ERR     = 3'd6, // False start (cheat) error
        CELEB   = 3'd7  // New high score animation
    } state_t;
    
    state_t curr, next;

    // Internal Registers
    logic [31:0] fast_cnt, rnd_reg, delay_cnt, sec_cnt, main_timer, anim_timer;
    logic [4:0]  anim_step; 
    logic [3:0]  startup_step;
    logic [15:0] cd_total;
    
    // Score Storage (BCD)
    logic [3:0]  b_s1, b_s10, b_m1, b_m10; 
    logic [3:0]  l_s1, l_s10, l_m1, l_m10; 
    
    // Average Calculation
    logic [13:0] r1, r2, r3, r4; 
    logic [2:0]  game_count; 
    logic [13:0] avg_bin;
    logic [3:0]  a_s1, a_s10, a_m1, a_m10;

    assign bcd_best = {b_s10, b_s1, b_m10, b_m1};
    assign bcd_last = {l_s10, l_s1, l_m10, l_m1};
    assign bcd_avg  = {a_s10, a_s1, a_m10, a_m1};

    // New High Score Detection
    logic is_new;
    assign is_new = ({cur_s_tens, cur_s_ones, cur_m_tens, cur_m_ones} < {b_s10, b_s1, b_m10, b_m1});

    // Global High-speed counter for RNG and Blinking
    always_ff @(posedge clk) begin
        fast_cnt <= fast_cnt + 32'd1;
        if (curr == IDLE && !start_n) rnd_reg <= fast_cnt;
    end

    // Sequential Logic (State Transitions and Timers)
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            curr <= STARTUP;
            main_timer <= 32'd0;
            sec_cnt <= 32'd0;
            delay_cnt <= 32'd0;
            anim_timer <= 32'd0;
            startup_step <= 4'd0;
            anim_step <= 5'd0;
            cd_total <= 16'd300;
            {b_s10, b_s1, b_m10, b_m1} <= 16'h9999;
            game_count <= 3'd0;
        end else begin
            curr <= next;
            
            // Capture scores on game finish
            if (curr == RUN && (next == RES || next == CELEB)) begin
                {l_s10, l_s1, l_m10, l_m1} <= {cur_s_tens, cur_s_ones, cur_m_tens, cur_m_ones};
                r4 <= r3; r3 <= r2; r2 <= r1;
                r1 <= (cur_s_tens * 1000) + (cur_s_ones * 100) + (cur_m_tens * 10) + cur_m_ones;
                if (game_count < 3'd4) game_count <= game_count + 3'd1;
                if (next == CELEB) {b_s10, b_s1, b_m10, b_m1} <= {cur_s_tens, cur_s_ones, cur_m_tens, cur_m_ones};
            end

            case (curr)
                STARTUP: begin
                    // SLOW Loading animation: 10M cycles = 0.2s per step
                    if (main_timer >= 32'd10000000) begin 
                        main_timer <= 32'd0;
                        startup_step <= startup_step + 4'd1;
                    end else begin
                        main_timer <= main_timer + 32'd1;
                    end
                end
                CDOWN: begin
                    if (sec_cnt >= 32'd500000) begin 
                        sec_cnt <= 32'd0; 
                        if (cd_total > 16'd0) cd_total <= cd_total - 16'd1; 
                    end else begin
                        sec_cnt <= sec_cnt + 32'd1;
                    end
                end
                WAIT:  delay_cnt <= delay_cnt + 32'd1;
                CELEB: begin
                    // --- Change 1: SLOWER Celebration Animation (5M instead of 2M) ---
                    anim_timer <= anim_timer + 32'd1;
                    if (anim_timer >= 32'd5000000) begin
                        anim_timer <= 32'd0;
                        anim_step <= (anim_step >= 5'd17) ? 5'd0 : anim_step + 5'd1;
                    end
                end
                RES, ERR: main_timer <= main_timer + 32'd1;
                default: begin
                    main_timer <= 32'd0;
                    sec_cnt <= 32'd0;
                    delay_cnt <= 32'd0;
                    anim_timer <= 32'd0;
                    if (curr != CDOWN) cd_total <= 16'd300;
                end
            endcase
        end
    end

    // Average Calculation Logic
    always_comb begin
        case (game_count)
            3'd1:    avg_bin = r1;
            3'd2:    avg_bin = (r1 + r2) >> 1;
            3'd3:    avg_bin = (r1 + r2 + r3) / 3;
            3'd4:    avg_bin = (r1 + r2 + r3 + r4) >> 2;
            default: avg_bin = 14'd0;
        endcase
    end

    assign a_s10 = (avg_bin / 1000) % 10;
    assign a_s1  = (avg_bin / 100) % 10;
    assign a_m10 = (avg_bin / 10) % 10;
    assign a_m1  = avg_bin % 10;

    // Next State Transition Logic
    always_comb begin
        next = curr;
        case (curr)
            STARTUP: if (startup_step >= 4'd12) next = IDLE;
            IDLE:    if (!start_n) next = CDOWN;
            CDOWN:   if (!react_n) next = ERR;   else if (cd_total == 16'd0) next = WAIT;
            WAIT:    if (!react_n) next = ERR;   else if (delay_cnt >= (rnd_reg % 32'd200000000) + 32'd50000000) next = RUN;
            RUN:     if (!react_n) next = is_new ? CELEB : RES;
            CELEB, RES: if (!start_n) next = IDLE;
            ERR:     if (main_timer >= 32'd150000000) next = IDLE;
            default: next = IDLE;
        endcase
    end

    // LED Output Logic 
    always_comb begin
        leds = 10'b0;
        case (curr)
            STARTUP: for (int i=0; i<10; i++) if (startup_step > i) leds[i] = 1'b1;
            CDOWN:   leds = (cd_total > 16'd200) ? 10'b111 : (cd_total > 16'd100 ? 10'b011 : 10'b001);
            
            // --- Change 2: FASTER Blink in RUN mode (Bit 24 instead of 25) ---
            RUN:     leds = (fast_cnt[24]) ? 10'b1111111111 : 10'b0; 
            
            CELEB:   begin
                case (anim_step)
                    5'd0: leds=10'h001; 5'd1: leds=10'h002; 5'd2: leds=10'h004; 5'd3: leds=10'h008;
                    5'd4: leds=10'h010; 5'd5: leds=10'h020; 5'd6: leds=10'h040; 5'd7: leds=10'h080;
                    5'd8: leds=10'h100; 5'd9: leds=10'h200; 5'd10: leds=10'h100; 5'd11: leds=10'h080;
                    5'd12: leds=10'h040; 5'd13: leds=10'h020; 5'd14: leds=10'h010; 5'd15: leds=10'h008;
                    5'd16: leds=10'h004; 5'd17: leds=10'h002; default: leds = 10'b0;
                endcase
            end
            default: leds = 10'b0;
        endcase
    end

    // 7-Segment Display Controller (HEX0-HEX3) [cite: 64-94]
    always_comb begin
        case (curr)
            STARTUP: begin
                case (startup_step)
                    4'd0:        bcd_current = 16'hFFFF; 
                    4'd1, 4'd9:  bcd_current = 16'h0FFF; // HEX3
                    4'd2, 4'd8:  bcd_current = 16'hF0FF; // HEX2
                    4'd3, 4'd7:  bcd_current = 16'hFF0F; // HEX1
                    4'd4, 4'd6:  bcd_current = 16'hFFF0; // HEX0
                    4'd5:        bcd_current = 16'hFFFF; 
                    default:     bcd_current = 16'hFFFF; 
                endcase
            end
            IDLE:    bcd_current = 16'hFFFF; // "----"
            ERR:     bcd_current = (main_timer[24]) ? 16'hEFAA : 16'hDDDD;
            CDOWN:   bcd_current = {4'h0, 4'((cd_total/100)%10), 4'((cd_total/10)%10), 4'(cd_total%10)};
            default: bcd_current = {cur_s_tens, cur_s_ones, cur_m_tens, cur_m_ones};
        endcase
    end

    assign sw_en = (curr == RUN);
    assign sw_rst_n = rst_n && (curr != IDLE && curr != STARTUP && curr != CDOWN && curr != WAIT);
    assign ctrl_state = curr;

endmodule