module eth_mac_tx_fifo #
(
    parameter DATA_WIDTH = 8,
    parameter BUFFER_SIZE = 4096
)
(
    input   wire [DATA_WIDTH-1:0]   s_axis_tdata,
    input   wire                    s_axis_tvalid,
    input   wire                    s_axis_tlast,
    input   wire                    s_axis_tuser,
    output  wire                    s_axis_tready,
    
    input   wire                    clk,

    output wire [DATA_WIDTH-1:0]    m_axis_tdata,
    output wire                     m_axis_tvalid,
    output wire                     m_axis_tlast,
    input  wire                     m_axis_tready
);
// state code
localparam [2:0]
    STATE_IDLE = 3'd0,
    STATE_TRANSFER = 3'd1,
    STATE_DROP = 3'd2;


parameter BUFFER_N = BUFFER_SIZE/DATA_WIDTH;
parameter FRAME_N = BUFFER_SIZE>>6;

reg [2:0]               state_in = STATE_IDLE, state_out = STATE_IDLE;

reg [DATA_WIDTH-1:0]    buffer[0:BUFFER_N];
integer                 buffer_head = 0;
integer                 buffer_tail = 0;

integer                 frame_st[0:FRAME_N];
integer                 frame_ed[0:FRAME_N];
integer                 frame_head = 0;
integer                 frame_tail = 0;

reg [DATA_WIDTH-1:0]    s_axis_tdata_reg = 0;
reg                     s_axis_tvalid_reg = 0;
reg                     s_axis_tuser_reg = 0;
reg                     s_axis_tlast_reg = 0;
reg                     s_axis_tready_reg = 0;

reg                     m_axis_tready_reg = 0;
reg [DATA_WIDTH-1:0]    m_axis_tdata_reg = 0;
reg                     m_axis_tlast_reg = 0;
reg                     m_axis_tvalid_reg = 0;

assign m_axis_tdata = m_axis_tdata_reg;
assign m_axis_tlast = m_axis_tlast_reg;
assign m_axis_tvalid = m_axis_tvalid_reg;
assign s_axis_tready = s_axis_tready_reg;

always @(negedge clk) begin
    

    s_axis_tdata_reg = s_axis_tdata;
    s_axis_tlast_reg = s_axis_tlast;
    s_axis_tuser_reg = s_axis_tuser;
    s_axis_tvalid_reg = s_axis_tvalid;

    case (state_in)
        STATE_IDLE: begin
            if(s_axis_tvalid_reg == 1'b1)begin
                if(buffer_tail+1==buffer_head||(buffer_tail==BUFFER_N&&buffer_head==0))
                    s_axis_tready_reg = 1'b0;
                else if(s_axis_tready_reg == 1'b0)
                    s_axis_tready_reg = 1'b1;
                else begin
                    if(s_axis_tuser_reg==1'b1)begin
                        state_in = (s_axis_tlast_reg== 1'b1)? STATE_IDLE:STATE_DROP;
                        s_axis_tready_reg = (s_axis_tlast_reg == 1'b1)?1'b0:1'b1;                  
                    end else begin
                        frame_st[frame_tail] = buffer_tail;
                        buffer[buffer_tail] = s_axis_tdata_reg;
                        if(buffer_tail == BUFFER_N) 
                            buffer_tail = 0;
                        else 
                            buffer_tail = buffer_tail + 1;
                        if(s_axis_tlast_reg == 1'b1)begin
                            frame_ed[frame_tail] = buffer_tail;
                            if(frame_tail == FRAME_N) 
                                frame_tail = 0;
                            else 
                                frame_tail = frame_tail + 1;    
                            s_axis_tready_reg = 1'b0;
                        end else begin
                            if(buffer_tail+1==buffer_head||(buffer_tail==BUFFER_N&&buffer_head==0))
                                s_axis_tready_reg = 1'b0;
                            else
                                s_axis_tready_reg = 1'b1;
                            state_in = STATE_TRANSFER;
                        end
                    end
                end
            end
        end 
        STATE_TRANSFER: begin
            if(s_axis_tvalid_reg == 1'b1&&s_axis_tready_reg == 1'b1)begin
                buffer[buffer_tail] = s_axis_tdata_reg;
                if(buffer_tail == BUFFER_N) 
                    buffer_tail = 0;
                else 
                    buffer_tail = buffer_tail + 1;
                if(s_axis_tuser_reg == 1'b1)begin
                    buffer_tail = frame_st[frame_tail];
                    s_axis_tready_reg = (s_axis_tlast_reg == 1'b1)?1'b0:1'b1;
                    state_in = (s_axis_tlast_reg == 1'b1)?STATE_IDLE:STATE_DROP;
                end else begin
                    if(s_axis_tlast_reg == 1'b1)begin
                        frame_ed[frame_tail] = buffer_tail;
                        if(frame_tail == FRAME_N) 
                            frame_tail = 0;
                        else 
                            frame_tail = frame_tail + 1;
                        s_axis_tready_reg = 1'b0;
                        state_in = STATE_IDLE;    
                    end else begin
                        if(buffer_tail+1==buffer_head||(buffer_tail==BUFFER_N&&buffer_head==0))
                            s_axis_tready_reg = 1'b0;
                        else
                            s_axis_tready_reg = 1'b1;
                    end
                end
            end else begin
                if(buffer_tail+1==buffer_head||(buffer_tail==BUFFER_N&&buffer_head==0))
                    s_axis_tready_reg = 1'b0;
                else
                    s_axis_tready_reg = 1'b1;
            end
        end
        STATE_DROP: begin
            if(s_axis_tlast_reg == 1'b1)begin
                state_in = STATE_IDLE;
                s_axis_tready_reg = 1'b0;
            end
        end
    endcase
end

always @(negedge clk)begin

    m_axis_tready_reg = m_axis_tready;

    if(frame_head!=frame_tail)begin
        m_axis_tvalid_reg = 1'b1;
        case (state_out)
            STATE_IDLE: begin
                m_axis_tdata_reg = buffer[frame_st[frame_head]];
                if(frame_st[frame_head]+1==frame_ed[frame_head] || (frame_st[frame_head]==BUFFER_N && frame_ed[frame_head]==0))
                    m_axis_tlast_reg = 1'b1;
                state_out = STATE_TRANSFER; 
            end
            STATE_TRANSFER: begin
                if(m_axis_tready_reg == 1'b1)begin
                    if(frame_st[frame_head] == BUFFER_N) 
                        frame_st[frame_head] = 0;
                    else 
                        frame_st[frame_head] = frame_st[frame_head] + 1;
                    
                    
                    if(frame_st[frame_head]==frame_ed[frame_head])begin
                        //frame_head <= inc(frame_head,FRAME_N);
                        if(frame_head == FRAME_N) 
                            frame_head = 0;
                        else 
                            frame_head = frame_head + 1;
                        state_out = STATE_IDLE;
                        m_axis_tvalid_reg = 1'b0;
                        m_axis_tlast_reg = 1'b0;
                    end else begin
                        m_axis_tdata_reg = buffer[frame_st[frame_head]];
                        if(frame_st[frame_head]+1==frame_ed[frame_head] || (frame_st[frame_head]==BUFFER_N && frame_ed[frame_head]==0))
                            m_axis_tlast_reg = 1'b1;
                    end
                end
            end
        endcase
    end else
        m_axis_tvalid_reg = 1'b0;
end


endmodule