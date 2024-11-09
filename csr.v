localparam ADDRESS_MVENDORID = 12'hF11;
localparam ADDRESS_MARCHID = 12'hF12;
localparam ADDRESS_MIMPID = 12'hF13;
localparam ADDRESS_MHARTID = 12'hF14;
localparam ADDRESS_MCONFIGPTR = 12'hF15;

localparam ADDRESS_MSTATUS = 12'h300;
localparam ADDRESS_MISA = 12'h301;
localparam ADDRESS_MIE = 12'h304;
localparam ADDRESS_MTVEC = 12'h305;
localparam ADDRESS_MCOUNTEREN = 12'h306;
localparam ADDRESS_MSTATUSH = 12'h310;

localparam ADDRESS_MSCRATCH = 12'h340;
localparam ADDRESS_MEPC = 12'h341;
localparam ADDRESS_MCAUSE = 12'h342;
localparam ADDRESS_MTVAL = 12'h343;
localparam ADDRESS_MIP = 12'h344;
localparam ADDRESS_MTINST = 12'h34A;
localparam ADDRESS_MTVAL2 = 12'h34B;

localparam ADDRESS_MENVCFG = 12'h30A;
localparam ADDRESS_MENVCFGH = 12'h31A;

localparam ADDRESS_MHPMCOUNTER3 = 12'hB03;
localparam ADDRESS_MHPMCOUNTER31 = 12'hB1F;
localparam ADDRESS_MHPMCOUNTER3H = 12'hB83;
localparam ADDRESS_MHPMCOUNTER31H = 12'hB9F;

localparam ADDRESS_MHPMEVENT3 = 12'h323;
localparam ADDRESS_MHPMEVENT31 = 12'h33F;
localparam ADDRESS_MHPMEVENT3H = 12'h723;
localparam ADDRESS_MHPMEVENT31H = 12'h73F;

localparam ADDRESS_MCYCLE = 12'hB00;
localparam ADDRESS_MINSTRET = 12'hB02;

localparam ADDRESS_MCYCLEH = 12'hB80;
localparam ADDRESS_MINSTRETH = 12'hB82;

module csr(clock, address, read_value, write_value, write_enable);
    input clock;
    input write_enable;
    input [11:0] address;
    input [31:0] write_value;
    output reg [31:0] read_value;

    // machine interrupt enable
    reg mstatus_mie;
    reg mstatus_mpie;

    reg [29:0] base;

    // machine interrupt pending
    // machine external interrupt pending
    reg mip_meip;
    // machine timer interrupt pending
    reg mip_mtip;
    // machine software interrupt pending
    reg mip_msip;

    // machine interrupt enable
    // machine external interrupt enable
    reg mie_meie;
    // machine timer interrupt enable
    reg mie_mtie;
    // machine software interrupt enable
    reg mie_msie;

    reg [63:0] mcycle;
    initial mcycle = 0;
    reg [63:0] minstret;
    initial minstret = 0;

    reg [31:0] mscratch;

    // machine exception program counter
    reg [29:0] mepc;

    reg mcause_interrupt;
    reg [30:0] mcause_exception_code;

    wire [63:0] next_mcycle;
    assign next_mcycle = mcycle + 1;

    wire [63:0] next_minstret;
    assign next_minstret = core.stall ? minstret : minstret + 1;

    wire [63:0] menvcfg = {
        1'b0 /* STCE */,
        1'b0 /* PBMTE */,
        1'b0 /* ADUE */,
        1'b0 /* CDE */,
        26'b0 /* WPRI */,
        2'b0 /* PMM */,
        24'b0 /* WPRI */,
        1'b0 /* CBZE */,
        1'b0 /* CBCFE */,
        2'b0 /* CBIE */,
        3'b0 /* WPRI */,
        1'b0 /* FIOM */
    };

    always @* begin
        case (address)
            ADDRESS_MISA: begin
                read_value = {
                    2'b01 /* MXL */,
                    4'b0,
                    26'b1 << 8 /* Extensions */
                };
            end
            ADDRESS_MVENDORID: begin
                read_value = 0;
            end
            ADDRESS_MARCHID: begin
                read_value = 0;
            end
            ADDRESS_MIMPID: begin
                read_value = 0;
            end
            ADDRESS_MHARTID: begin
                read_value = 0;
            end
            ADDRESS_MSTATUS: begin
                read_value = {
                    1'b0 /* SD */,
                    8'b0 /* WPRI */,
                    1'b0 /* TSR */,
                    1'b0 /* TW */,
                    1'b0 /* TVM */,
                    1'b0 /* MXR */,
                    1'b0 /* SUM */,
                    1'b0 /* MPRV */,
                    2'b0 /* XS */,
                    2'b0 /* FS */,
                    2'b11 /* MPP */,
                    2'b0 /* VS */,
                    1'b0 /* SPP */,
                    mstatus_mpie,
                    1'b0 /* UBE */,
                    1'b0 /* SPIE */,
                    1'b0 /* WPRI */,
                    mstatus_mie,
                    1'b0 /* WPRI */,
                    1'b0 /* SIE */,
                    1'b0 /* WPRI */
                };
            end
            ADDRESS_MSTATUSH: begin
                read_value = {
                    26'b0 /* WPRI */,
                    1'b0 /* MBE */,
                    1'b0 /* SBE */,
                    4'b0 /* WPRI */
                };
            end
            ADDRESS_MTVEC: begin
                read_value = {
                    base,
                    2'b0 /* MODE */
                };
            end
            ADDRESS_MIP: begin
                read_value = {
                    16'b0 /* platform defined */,
                    2'b0,
                    1'b0 /* LCOFIP */,
                    1'b0,
                    mip_meip,
                    1'b0,
                    1'b0 /* SEIP */,
                    1'b0,
                    mip_mtip,
                    1'b0,
                    1'b0 /* STIP */,
                    1'b0,
                    mip_msip,
                    1'b0,
                    1'b0 /* SSIP */,
                    1'b0
                };
            end
            ADDRESS_MIE: begin
                read_value = {
                    16'b0 /* platform defined */,
                    2'b0,
                    1'b0 /* LCOFIE */,
                    1'b0,
                    mie_meie,
                    1'b0,
                    1'b0 /* SEIP */,
                    1'b0,
                    mie_mtie,
                    1'b0,
                    1'b0 /* STIP */,
                    1'b0,
                    mie_msie,
                    1'b0,
                    1'b0 /* SSIP */,
                    1'b0
                };
            end
            ADDRESS_MCYCLE: begin
                read_value = mcycle[31:0];
            end
            ADDRESS_MCYCLEH: begin
                read_value = mcycle[63:32];
            end
            ADDRESS_MINSTRET: begin
                read_value = minstret[31:0];
            end
            ADDRESS_MINSTRETH: begin
                read_value = minstret[63:32];
            end
            ADDRESS_MSCRATCH: begin
                read_value = mscratch;
            end
            ADDRESS_MEPC: begin
                read_value = { mepc, 2'b0 };
            end
            ADDRESS_MCAUSE: begin
                read_value = { mcause_interrupt, mcause_exception_code };
            end
            ADDRESS_MTVAL: begin
                read_value = 0;
            end
            ADDRESS_MCONFIGPTR: begin
                read_value = 0;
            end
            ADDRESS_MENVCFG: begin
                read_value = menvcfg[31:0];
            end
            ADDRESS_MENVCFGH: begin
                read_value = menvcfg[63:32];
            end
            default: begin
                if ((address >= ADDRESS_MHPMCOUNTER3 && address <= ADDRESS_MHPMCOUNTER31)
                    || (address >= ADDRESS_MHPMCOUNTER3H && address <= ADDRESS_MHPMCOUNTER31H)
                    || (address >= ADDRESS_MHPMEVENT3 && address <= ADDRESS_MHPMEVENT31)
                    || (address >= ADDRESS_MHPMEVENT3H && address <= ADDRESS_MHPMEVENT31H)) begin
                    read_value = 0;
                end else begin
                    read_value = 32'bx;
                end
            end
        endcase
    end

    always @(posedge clock) begin
        if (core.trap) begin
            mcause_exception_code <= core.exception_code;
            mcause_interrupt <= core.interrupt;
            mepc <= core.program_counter[31:2];
        end else if (write_enable) begin
            case (address)
                ADDRESS_MSTATUS: begin
                    mstatus_mie <= write_value[3];
                    mstatus_mpie <= write_value[7];
                end
                ADDRESS_MTVEC: begin
                    base <= write_value[31:2];
                end
                ADDRESS_MIP: begin
                    // all are read-only
                end
                ADDRESS_MIE: begin
                    // this could be read-only, TODO consider
                    mie_msie <= write_value[3];
                    mie_mtie <= write_value[7];
                    mie_meie <= write_value[11];
                end
                ADDRESS_MSCRATCH: begin
                    mscratch <= write_value;
                end
                ADDRESS_MEPC: begin
                    mepc <= write_value[31:2];
                end
                ADDRESS_MCAUSE: begin
                    mcause_interrupt <= write_value[31];
                    mcause_exception_code <= write_value[30:0];
                end
                default: begin
                end
            endcase
        end

        if (write_enable) begin
            case (address)
                ADDRESS_MCYCLE: mcycle[31:0] <= write_value;
                ADDRESS_MCYCLEH: mcycle[63:32] <= write_value;
                default: mcycle <= next_mcycle;
            endcase

            case (address)
                ADDRESS_MINSTRET: minstret[31:0] <= write_value;
                ADDRESS_MINSTRETH: minstret[63:32] <= write_value;
                default: minstret <= next_minstret;
            endcase
        end else begin
            mcycle <= next_mcycle;
            minstret <= next_minstret;
        end
    end

endmodule
