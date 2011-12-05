/******************************************************************************
*
*  Filename    :    intrCntrl_tb.v
*  Description :    Test  simple programmable interrupt controller IC.
*
*  Author      :    Aditya Shevade
*                   <aditya.shevade@gmail.com>
*  
*  Created     :    12/04/2011
*  Updated     :    12/04/2011
*
*  Version     :    1.0.0
* 
*  Changelog   :    
*       
******************************************************************************
*/

module INTR_CNTRL_TB;

    reg             clk_in;         // Clock
    reg             rst_in;         // Reset
    reg     [7:0]   intr_rq;        // Interrupt request
    reg     [7:0]   intr_bus_in;    // Bidirectional data bus
    reg             intr_in;        // Ack from processor
    wire            intr_out;       // Interrupt to processor
    wire            bus_oe;         // High if controller drives the bus.

    wire    [7:0]   intr_bus_test;
    wire    [7:0]   intr_bus_out;
    INTR_CNTRL DUT (
        .clk_in     (clk_in         ),
        .rst_in     (rst_in         ),
        .intr_rq    (intr_rq        ),
        .intr_bus   (intr_bus_test  ),
        .intr_in    (intr_in        ),
        .intr_out   (intr_out       ),
        .bus_oe     (bus_oe         )
        );
        
    assign intr_bus_test    =   (bus_oe == 0) ? intr_bus_in : 8'bz;
    assign intr_bus_out     =   (bus_oe == 1) ? intr_bus_test : 8'bz;

    reg     [2:0]   currentService;     // Store the ID of interrupt currently being serviced.
    integer j;

    initial begin
        // Reset the system.
        clk_in          =   1'b0;
        rst_in          =   1'b1;
        intr_rq         =   8'b0;
        intr_bus_in     =   8'b0;
        intr_in         =   1'b1;
        #20;
        rst_in          =   1'b0;
        #20;
        intr_bus_in     =   8'b0000_0001;   // Test the polling mode.
        #40;                                // Wait random time.
        intr_rq         =   8'b1010_1010;   // Activate random interrupts.
        for (j = 0; j < 8; j = j + 1) begin
            if (j == 4) begin               // Change the sources after servicing the first 4.
                intr_rq = 8'b0101_0101;
            end
            $display ("==================================================================");
            $display ("Servicing Interrupt Number %d / 8", (j+1));
            $display ("=================================================================="); 
            $display ("Interrupt Request = %b", intr_rq);

            $display ("Waiting for interrupt from controller");
            wait(intr_out);                     // Wait till controller gives interrupt.
            #60;                                // Wait for random cycles. Then Acknowledge interrupt.
            intr_in     =   1'b0;               // Ack Start
            #10                                 // Active for 1 clock.
            intr_in     =   1'b1;               // Ack End        
            $display ("Interrupt Acknowledged by processor.");
            $display("Currently servicing %b", intr_bus_out[2:0]);
            $display ("The controller is driving the bus, %b", intr_bus_out);
            currentService          =   intr_bus_out[2:0];
            intr_rq[currentService] =   1'b0;   // Disable the interrupt serviced. This will be done by the interrupt master.
            
            // INFO: This is is an explicit assertion in verilog.
            // Used instead of assert because no free compiler I know can simulate system verilog.
            if (intr_bus_out == {5'b01011, currentService}) begin
                $display ("Proper address on the bus");
            end else begin
                $display ("ERROR: Wrong address on the bus");
                $finish;
            end

            #60                                 // At this point controller sends the address on the bus.
            intr_in     =   1'b0;               // Ack Start
            #10                                 // Active for 1 clock.
            intr_in     =   1'b1;               // Ack End
            $display ("Address acknowledged by processor");

            #60                                                 // Wait for random time. Work on interrupt.
            intr_bus_in     =   {5'b10100, currentService};     // Send the ACK to controller.
            intr_in         =   1'b0;                           // Let the controller know this is an Ack.
            #10                                                 // Active for 1 clock.
            intr_in         =   1'b1;                           // Ack ends.
            $display ("ISR Routine complete by processor");
            $display ("The processor is driving the bus, %b", intr_bus_in);
            $display ("==================================================================\n\n\n"); 
            #100; 
        end

        $display ("=================================================================="); 
        $display ("========         All tests completed successfully         ========");
        $display ("=================================================================="); 
        $finish;
     
    end

    always
        #5 clk_in   =   ~clk_in;

endmodule // INTR_CNTRL_TB

