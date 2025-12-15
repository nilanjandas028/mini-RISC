`timescale 1ns/1ps
module mini_risc #(
    parameter DATA_W = 32,
    parameter ADDR_W = 12,
    parameter IMEM_WORDS = 128,
    parameter DMEM_WORDS = 64
)(
    input wire clk,
    input wire rst_n,
    output wire [ADDR_W-1:0] dbg_pc_low
);

    reg [ADDR_W-1:0] pc;
    wire [31:0] instr;
    reg [31:0] imem [0:IMEM_WORDS-1];
    reg [DATA_W-1:0] dmem [0:DMEM_WORDS-1];
    assign dbg_pc_low = pc;

    reg [DATA_W-1:0] regs [0:255]; 
    integer j, k; 

    wire [7:0] opcode  = instr[31:24];
    wire [7:0] rd_idx  = instr[23:16];
    wire [7:0] rs1_idx = instr[15:8];
    wire [7:0] rs2_idx = instr[7:0];
    wire [7:0] imm8    = instr[7:0];

    assign instr = imem[pc];

    reg [31:0] instr_latched; 
    reg [7:0]  opcode_latched;
    reg [7:0]  rd_idx_latched;
    reg [7:0]  rs1_idx_latched;
    reg [7:0]  rs2_idx_latched;
    reg [DATA_W-1:0] rs1_latched;
    reg [DATA_W-1:0] rs2_latched;
    reg [DATA_W-1:0] imm_se_latched;

    reg [1:0] add_state;
    localparam ADD_IDLE    = 2'b00;
    localparam ADD_CAPTURE = 2'b01;
    localparam ADD_LOW     = 2'b11; 
    localparam ADD_HIGH    = 2'b10; 

    reg [DATA_W-1:0] add_op1, add_op2, add_result;
    reg add_done;
    wire [16:0] low_sum_w = add_op1[15:0] + add_op2[15:0]; 
    reg [15:0] sum_low;
    reg carry_low;

    reg add_cooldown;
    reg mul_cooldown;

    always @(posedge clk) begin
        if (!rst_n) begin
            add_cooldown <= 0;
            mul_cooldown <= 0;
        end else begin
            add_cooldown <= add_done;
            mul_cooldown <= mul_done;
        end
    end

    wire is_add  = (opcode == 8'h00);
    wire is_addi = (opcode == 8'h08);
    wire add_start = (is_add | is_addi) && (add_state == ADD_IDLE) && !add_done && !add_cooldown;

    wire is_mul = (opcode == 8'h02);
    wire mul_busy; 
    wire mul_done;
    wire [DATA_W-1:0] mul_result;
    wire mul_start = is_mul && !mul_busy && !mul_done && !mul_cooldown;

    wire stall = (add_state != ADD_IDLE) || (is_mul && !mul_done) 
               || add_cooldown || mul_cooldown 
               || add_start || mul_start;

    wire [DATA_W-1:0] raw_r1 = (rs1_idx == 0) ? 32'd0 : regs[rs1_idx];
    wire [DATA_W-1:0] raw_r2 = (rs2_idx == 0) ? 32'd0 : regs[rs2_idx];

    wire [DATA_W-1:0] mul_op_a_isolated = is_mul ? raw_r1 : 32'd0;
    wire [DATA_W-1:0] mul_op_b_isolated = is_mul ? raw_r2 : 32'd0;

    wire is_alu_op = (opcode == 8'h01) || (opcode >= 8'h03 && opcode <= 8'h07);
    
    wire [DATA_W-1:0] alu_op1_isolated = is_alu_op ? raw_r1 : 32'd0;
    wire [DATA_W-1:0] alu_op2_isolated = is_alu_op ? raw_r2 : 32'd0;

    seq_multiplier #(.DATA_W(DATA_W)) u_low_power_mult (
        .clk(clk),
        .rst_n(rst_n),
        .start(mul_start),
        .a(mul_op_a_isolated), 
        .b(mul_op_b_isolated), 
        .result(mul_result),
        .done(mul_done),
        .busy(mul_busy)
    );

    wire fwd_rs1 = (add_done || mul_done) && (rd_idx_latched != 0) && (rd_idx_latched == rs1_idx);
    wire fwd_rs2 = (add_done || mul_done) && (rd_idx_latched != 0) && (rd_idx_latched == rs2_idx);
    
    wire [DATA_W-1:0] fwd_val = add_done ? add_result : mul_result;
    
    wire [DATA_W-1:0] rs1_val = fwd_rs1 ? fwd_val : raw_r1;
    wire [DATA_W-1:0] rs2_val = fwd_rs2 ? fwd_val : raw_r2;

    always @(posedge clk) begin
        if (!rst_n) begin
            add_state <= ADD_IDLE;
            add_op1 <= 0; add_op2 <= 0; sum_low <= 0; carry_low <= 0;
            add_result <= 0; add_done <= 0;
            rd_idx_latched <= 0; rs1_latched <= 0; rs2_latched <= 0; imm_se_latched <= 0; 
            opcode_latched <= 0; rs1_idx_latched <= 0; rs2_idx_latched <= 0;
        end else begin
            case (add_state)
                ADD_IDLE: begin
                    add_done <= 1'b0;
                    if (add_start) begin
                        opcode_latched  <= opcode;
                        rd_idx_latched  <= rd_idx;
                        rs1_idx_latched <= rs1_idx;
                        rs2_idx_latched <= rs2_idx;
                        rs1_latched     <= rs1_val;
                        rs2_latched     <= rs2_val;
                        imm_se_latched  <= {{(DATA_W-8){imm8[7]}}, imm8}; 
                        add_state <= ADD_CAPTURE;
                    end else if (mul_start) begin
                         rd_idx_latched <= rd_idx;
                         rs1_idx_latched <= rs1_idx; 
                         rs2_idx_latched <= rs2_idx;
                    end
                end
                ADD_CAPTURE: begin
                    add_op1 <= rs1_latched;
                    add_op2 <= (opcode_latched == 8'h08) ? imm_se_latched : rs2_latched;
                    add_state <= ADD_LOW;
                end
                ADD_LOW: begin
                    sum_low <= low_sum_w[15:0];
                    carry_low <= low_sum_w[16];
                    if ((|add_op1[31:16]) || (|add_op2[31:16]) || low_sum_w[16])
                        add_state <= ADD_HIGH;
                    else begin
                        add_result <= {16'd0, low_sum_w[15:0]};
                        add_done <= 1'b1;
                        add_state <= ADD_IDLE;
                    end
                end
                ADD_HIGH: begin
                    add_result <= { (add_op1[31:16] + add_op2[31:16] + carry_low), sum_low };
                    add_done <= 1'b1;
                    add_state <= ADD_IDLE;
                end
                default: add_state <= ADD_IDLE;
            endcase
        end
    end

    reg [DATA_W-1:0] alu_comb;
    wire [DATA_W-1:0] iso_op1 = is_alu_op ? rs1_val : 32'd0;
    wire [DATA_W-1:0] iso_op2 = is_alu_op ? rs2_val : 32'd0;

    always @(*) begin
        case (opcode)
            8'h01: alu_comb = iso_op1 - iso_op2;
            8'h03: alu_comb = iso_op1 & iso_op2;
            8'h04: alu_comb = iso_op1 | iso_op2;
            8'h05: alu_comb = iso_op1 ^ iso_op2;
            8'h06: alu_comb = iso_op1 << iso_op2[4:0];
            8'h07: alu_comb = iso_op1 >> iso_op2[4:0];
            default: alu_comb = {DATA_W{1'b0}};
        endcase
    end

    wire [DATA_W-1:0] load_data = dmem[rs1_val[ADDR_W-1:0]]; 

    always @(posedge clk) begin
        if (!rst_n) begin
            for (j = 0; j < DMEM_WORDS; j = j + 1) dmem[j] <= 0;
        end else begin
            if (!stall) begin
                if (opcode == 8'h0A) dmem[rs1_val[ADDR_W-1:0]] <= rs2_val; 
            end
        end
    end

    always @(posedge clk) begin
        if (!stall) begin
            case (opcode)
                8'h01, 8'h03, 8'h04,
                8'h05, 8'h06, 8'h07: if(rd_idx!=0) regs[rd_idx] <= alu_comb;
                8'h09: if(rd_idx!=0) regs[rd_idx] <= load_data; 
                8'h0C: if(rd_idx!=0) regs[rd_idx] <= {20'b0, pc} + 1; 
            endcase
        end
        
        if (add_done && rd_idx_latched != 0) regs[rd_idx_latched] <= add_result;
        if (mul_done && rd_idx_latched != 0) regs[rd_idx_latched] <= mul_result;
    end

    wire signed [ADDR_W-1:0] offset_signed = {{(ADDR_W-8){imm8[7]}}, imm8};

    always @(posedge clk) begin
        if (!rst_n) pc <= 0;
        else if (!stall) begin
            case (opcode)
                8'h0B: pc <= (rs1_val == rs2_val) ? pc + offset_signed : pc + 1;
                8'h0C: pc <= pc + offset_signed; 
                default: pc <= pc + 1;
            endcase
        end
    end

    initial begin
        for (k=0; k<IMEM_WORDS; k=k+1) imem[k] = 0;
        $readmemh("/home/esdcs/Nilanjan/Project/mini_risc/hex/imem.hex", imem);
        for (k=0; k<256; k=k+1) regs[k] = 0;
    end

endmodule
