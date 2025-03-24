localparam DECODED_SYNC_PATTERN = 8'b10000000;

localparam TOP_STATE_POWERED = 0;
localparam TOP_STATE_IDLE = 1;
localparam TOP_STATE_ACTIVE = 2;

localparam EOP_NEED_SE0_0 = 0;
localparam EOP_NEED_SE0_1 = 1;
localparam EOP_NEED_J = 2;

module usb(
    input clock48,
    inout usb_d_p,
    inout usb_d_n,
    output usb_pullup = 1,
    output reg got_usb_packet, 
    output reg [$clog2(USB_PACKET_BUFFER_SIZE / 4) - 1:0] packet_buffer_address = 0,
    input [31:0] packet_buffer_read_value,
    output reg [31:0] packet_buffer_write_value,
    output reg write_to_packet_buffer,
    input usb_packet_ready
);
    reg [1:0] top_state = TOP_STATE_POWERED;

    // decoding and sending interface
    reg write_enable;
    wire [63:0] read_bits = { nzri_decoded_data, read_write_buffer[63:1] };
    reg [63:0] read_write_buffer; // needs to be 64 bits to fit all data from a setup 
                                  // transaction
    reg [6:0] read_write_bits_count;

    wire differential_1 = usb_d_p && !usb_d_n;
    wire differential_0 = !usb_d_p && usb_d_n;
    wire se0 = !usb_d_p && !usb_d_n;
    wire data_j = differential_1;
    wire data_k = differential_0;
    wire idle = usb_d_p && !usb_d_n; // equivalent to differential_1 and data_j
    wire data = data_j; // this is the undecoded bit sent over the wire
    wire nzri_decoded_data = !(data ^ previous_data); // nzri decoded, but not bit-stuffing decoded
    reg previous_data;

    reg [1:0] read_write_clock_counter;
    reg [2:0] consecutive_nzri_data_ones = 0;
    wire skip_bit = consecutive_nzri_data_ones >= 6;
    assign usb_d_p = write_enable ? output_data : 1'bz;
    assign usb_d_n = write_enable ? output_data_n : 1'bz;
    reg output_data, output_data_n;
    reg send_eop = 0;

    always @* begin
        if (send_eop) begin
            output_data = 0;
            output_data_n = 0;
        end else begin
            if (!skip_bit) begin
                output_data = !(read_write_buffer[0] ^ previous_data);
            end else begin
                // insert bit-stuffed transition
                output_data = !previous_data;
            end

            output_data_n = !output_data;
        end
    end

    reg [31:0] reset_counter = 0; // needs to hold one reset time, TODO could be smaller

    always @(posedge clock48) begin
        read_write_clock_counter <= read_write_clock_counter + 1;

        case (top_state)
            TOP_STATE_POWERED: begin
                // TODO actually only needs to be 2.5 microseconds
                if (reset_counter > 48000 * 9) begin
                    top_state <= TOP_STATE_IDLE;
                end
            end
            TOP_STATE_IDLE: begin
                if (data_k) begin
                    top_state <= TOP_STATE_ACTIVE;
                    packet_state <= PACKET_STATE_SYNCING;
                    read_write_bits_count <= 8;
                    previous_data <= 1;
                    consecutive_nzri_data_ones <= 0;
                    read_write_clock_counter <= 3;
                end
            end
            TOP_STATE_ACTIVE: begin
                if (read_write_clock_counter == 3) begin
                    if (!skip_bit) begin
                        read_write_buffer <= read_bits;
                        if (read_write_bits_count > 0) begin
                            read_write_bits_count <= read_write_bits_count - 1;
                        end

                        if (read_write_bits_count == 1) begin
                            write_enable <= 0;
                        end
                    end

                    stall_counter <= stall_counter - 1;
                    if (read_write_bits_count == 0 || (!skip_bit && read_write_bits_count == 1)) begin 
                        read_write_complete();
                    end

                    if (nzri_decoded_data == 1) begin
                        consecutive_nzri_data_ones <= consecutive_nzri_data_ones + 1;
                    end else begin
                        consecutive_nzri_data_ones <= 0;
                    end

                    previous_data <= data;
                end
            end
        endcase

        if (se0) begin
            reset_counter <= reset_counter + 1;
        end else begin
            reset_counter <= 0;
        end
    end

    localparam PACKET_STATE_POWERED = 0;
    localparam PACKET_STATE_READING = 2;
    localparam PACKET_STATE_READ_COMPLETE = 3;
    localparam PACKET_STATE_DONE = 4;
    localparam PACKET_STATE_AWAIT_END_OF_PACKET = 5;
    localparam PACKET_STATE_SYNCING = 6;
    localparam PACKET_STATE_WRITE = 7;
    localparam PACKET_STATE_READING_PID = 8;
    localparam PACKET_STATE_READING_TOKEN = 9;
    localparam PACKET_STATE_READING_DATA = 10;
    localparam PACKET_STATE_FINISH = 11;
    localparam PACKET_STATE_WRITE_PAUSE = 12;
    localparam PACKET_STATE_WRITE_COMPLETE = 13;
    localparam PACKET_STATE_SEND_EOP = 14;

    localparam TRANSACTION_NONE = 0;
    localparam TRANSACTION_SETUP = 1;
    localparam TRANSACTION_IN = 2;
    localparam TRANSACTION_OUT = 3;

    localparam PENDING_SEND_NONE = 0;
    localparam PENDING_SEND_ACK = 1;
    localparam PENDING_SEND_NAK = 2;

    localparam TRANSACTION_STATE_IDLE = 0;
    localparam TRANSACTION_STATE_AWAIT_DATA = 1;

    localparam BREQUEST_GET_STATUS = 0;
    localparam BREQUEST_CLEAR_FEATURE = 1;
    localparam BREQUEST_SET_FEATURE = 3;
    localparam BREQUEST_SET_ADDRESS = 5;
    localparam BREQUEST_GET_DESCRIPTOR = 6;
    localparam BREQUEST_SET_DESCRIPTOR = 7;
    localparam BREQUEST_GET_CONFIGURATION = 8;
    localparam BREQUEST_SET_CONFIGURATION = 9;
    localparam BREQUEST_GET_INTERFACE = 10;
    localparam BREQUEST_SET_INTERFACE = 11;
    localparam BREQUEST_SYNCH_FRAME = 12;

    localparam PID_OUT = 4'b0001;
    localparam PID_IN = 4'b1001;
    localparam PID_SETUP = 4'b1101;
    localparam PID_DATA0 = 4'b0011;
    localparam PID_DATA1 = 4'b1011;
    localparam PID_ACK = 4'b0010;
    localparam PID_NAK = 4'b1010;
    localparam PID_STALL = 4'b1110;
    localparam PID_NYET = 4'b0110;

    reg [3:0] current_transaction = TRANSACTION_NONE;
    reg [3:0] pending_send = PENDING_SEND_NONE;
    reg [3:0] packet_state = PACKET_STATE_POWERED;
    reg [3:0] transaction_state = TRANSACTION_STATE_IDLE;
    reg [6:0] device_address = 0;
    reg [3:0] stall_counter;

    task read_write_complete();
        send_eop <= 0;

        case (packet_state)
            PACKET_STATE_SYNCING: begin
                if (read_bits[63:56] == 8'b10000000) begin
                    packet_state <= PACKET_STATE_READING_PID;
                    read_write_bits_count <= 8;
                end else begin
                    `ifdef simulation
                        $stop;
                    `else
                        packet_state <= PACKET_STATE_AWAIT_END_OF_PACKET;
                    `endif
                end
            end
            PACKET_STATE_READING_PID: begin
                if (read_bits[59:56] == ~read_bits[63:60]) begin // check PID check
                    case (transaction_state)
                        TRANSACTION_STATE_AWAIT_DATA: begin
                            if (read_bits[59:56] == PID_DATA0) begin
                                packet_state <= PACKET_STATE_READING_DATA;
                                read_write_bits_count <= 64;
                            end else begin
                                $stop;
                                packet_state <= PACKET_STATE_AWAIT_END_OF_PACKET;
                            end
                        end
                        TRANSACTION_STATE_IDLE: begin
                            case (read_bits[59:56])
                                PID_SETUP: begin
                                    read_write_bits_count <= 16;
                                    current_transaction <= TRANSACTION_SETUP;
                                    packet_state <= PACKET_STATE_READING_TOKEN;
                                    transaction_state <= TRANSACTION_STATE_AWAIT_DATA;
                                end
                                default: begin
                                    `ifdef simulation
                                        $stop;
                                    `endif
                                    packet_state <= PACKET_STATE_AWAIT_END_OF_PACKET;
                                end
                            endcase
                        end
                        default:
                            `ifdef simulation
                                $stop;
                            `endif
                    endcase
                end else begin
                    `ifdef simulation
                        $stop;
                    `else
                        packet_state <= PACKET_STATE_AWAIT_END_OF_PACKET;
                    `endif
                end
            end
            PACKET_STATE_READING_TOKEN: begin
                if (read_bits[54:48] == device_address && read_bits[58:55] == 0) begin
                    transaction_state <= TRANSACTION_STATE_AWAIT_DATA;
                    packet_state <= PACKET_STATE_AWAIT_END_OF_PACKET; // TODO ignore if not receiving EOP immediately?
                end else begin
                    $stop();
                    current_transaction <= TRANSACTION_NONE;
                    packet_state <= PACKET_STATE_AWAIT_END_OF_PACKET;
                end
            end
            PACKET_STATE_READING_DATA: begin
                if (current_transaction == TRANSACTION_SETUP) begin
                    case (read_bits[15:8]) // bRequest value
                        BREQUEST_CLEAR_FEATURE: begin
                        end
                        BREQUEST_GET_CONFIGURATION: begin
                        end
                        BREQUEST_GET_DESCRIPTOR: begin
                        end
                        BREQUEST_GET_INTERFACE: begin
                        end
                        BREQUEST_GET_STATUS: begin
                        end
                        BREQUEST_SET_ADDRESS: begin
                            device_address <= read_bits[22:16];
                        end
                        BREQUEST_SET_CONFIGURATION: begin
                        end
                        BREQUEST_SET_DESCRIPTOR: begin
                        end
                        BREQUEST_SET_FEATURE: begin
                        end
                        BREQUEST_SET_INTERFACE: begin
                        end
                        BREQUEST_SYNCH_FRAME: begin
                        end
                    endcase

                    packet_state <= PACKET_STATE_AWAIT_END_OF_PACKET;
                    pending_send <= PENDING_SEND_ACK;
                end else begin
                    $stop;
                end
            end
            PACKET_STATE_AWAIT_END_OF_PACKET: begin
                // TODO implement timeout?
                if (se0) begin
                    // end of packet
                    packet_state <= PACKET_STATE_FINISH;
                end
            end
            PACKET_STATE_FINISH: begin // to implement a pause after receiving eop
                if (pending_send != PENDING_SEND_NONE) begin
                    stall_counter <= 4; // could be shorter while still complying with spec
                    packet_state <= PACKET_STATE_WRITE_PAUSE;
                end else begin
                    top_state <= TOP_STATE_IDLE;
                end
            end
            PACKET_STATE_WRITE_PAUSE: begin
                if (stall_counter == 0) begin
                    case (pending_send)
                        PENDING_SEND_ACK: begin
                            consecutive_nzri_data_ones <= 0; // not sure if this is needed
                            packet_state <= PACKET_STATE_WRITE;
                            write_enable <= 1;
                            read_write_bits_count <= 16; // hardcode value could be changed later
                            read_write_buffer[15:0] <= { 4'b0, PID_ACK, DECODED_SYNC_PATTERN };
                        end
                        default: begin
                            $stop;
                        end
                    endcase
                end
            end
            PACKET_STATE_WRITE: begin
                write_enable <= 1;
                send_eop <= 1;
                packet_state <= PACKET_STATE_SEND_EOP;
            end
            PACKET_STATE_SEND_EOP: begin
                write_enable <= 1;
                send_eop <= 1;
                top_state <= TOP_STATE_IDLE;
            end
        endcase
    endtask
endmodule
