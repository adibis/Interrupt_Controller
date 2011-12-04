/*
******************************************************************************
*
*  Filename     :   intrCntrl.v
*  Description  :   Simple programmable interrupt controller IC.
*
*  Author       :   Aditya Shevade
*                   <aditya.shevade@gmail.com>
*
*  License      :   This program is free software: you can redistribute it and/or modify
*                   it under the terms of the GNU General Public License as published by
*                   the Free Software Foundation, either version 3 of the License, or
*                   (at your option) any later version.
*
*                   This program is distributed in the hope that it will be useful,
*                   but WITHOUT ANY WARRANTY; without even the implied warranty of
*                   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
*                   GNU General Public License for more details.
*
*                   You should have received a copy of the GNU General Public License
*                   along with this program.  If not, see <http://www.gnu.org/licenses/>.
*  
*  Created      :   07/20/2011
*  Updated      :   12/04/2011
*
*  Version      :   1.4.0
* 
*  Changelog    :    
*       
*       07/20/2011  :   Created the project
*       07/23/2011  :   Improved FSM logic removed some glitches
*       07/25/2011  :   Made lot of changes to make code synthesizable
*                       Expanded the 2D array, added flag_reg and flag_next
*       07/25/2011  :   Added reg and next registers to priority table to
*                       remove the latches generated at synthesis
*       12/04/2011  :   Removed the flags completely.
*                       Modified the DONE stages a bit.
*                       Added a lot of comments.
*
*  TODO :
*       1. Make the interrupts positive or negative edge triggered depending
*       on the status of a status register.
*       2. Add vectored interrupts depending on status register. Add more
*       states to get vectoring information.
*
******************************************************************************
*/
 
module INTR_CNTRL (
        input   wire            clk_in,     // Clock
        input   wire            rst_in,     // Reset
        input   wire    [7:0]   intr_rq,    // Interrupt request
        inout   wire    [7:0]   intr_bus,   // Bidirectional data bus
        input   wire            intr_in,    // Ack from processor
        output  wire            intr_out    // Interrupt to processor
    );
 
    localparam  [3:0]   S_Reset                 = 4'b0000,  // Reset or start state
                        S_GetCommands           = 4'b0001,  // Command mode - set polling or priority mode
                        S_JumpIntMethod         = 4'b0010,  // Determine which mode was selected
                        S_StartPolling          = 4'b0011,  // Polling each interrupt source periodically
                        S_TxIntInfoPolling      = 4'b0100,  // Assert intr_out if interrupt present and send source ID on intr_bus 
                        S_AckTxInfoRxPolling    = 4'b0101,  // Wait for intr_in to go high
                        S_AckISRDonePolling     = 4'b0110,  // De-assert intr_out signal
                        S_StartPriority         = 4'b0111,  // Start priority check
                        S_TxIntInfoPriority     = 4'b1000,  // Assert intr_out if interrupt present and sent source ID on intr_bus
                        S_AckTxInfoRxPriority   = 4'b1001,  // Wait for intr_in to go high
                        S_AckISRDonePriority    = 4'b1010,  // De-assert intr_out signal
                        S_Reserved1             = 4'b1011,  // Optional - Transition to S_Reset
                        S_Reserved2             = 4'b1100,  // Optional - Transition to S_Reset
                        S_Reserved3             = 4'b1101,  // Optional - Transition to S_Reset
                        S_Reserved4             = 4'b1110,  // Optional - Transition to S_Reset
                        S_Reserved5             = 4'b1111;  // Optional - Transition to S_Reset
 
   
    reg     [3:0]   state_reg, state_next;          // State registers
    reg     [1:0]   cmdMode_reg, cmdMode_next;      // Interrupt mode
    reg     [1:0]   cmdCycle_reg, cmdCycle_next;    // Machine cycle
    reg     [2:0]   intrIndex_reg, intrIndex_next;  // Cycle through all 8 in polling
    reg     [2:0]   intrPtr_reg, intrPtr_next;      // Interrupt pointer 
    reg     [2:0]   prior_table_0_next, prior_table_0_reg;  // FIXME - 2 interrupts with same priority?
    reg     [2:0]   prior_table_1_next, prior_table_1_reg;
    reg     [2:0]   prior_table_2_next, prior_table_2_reg;
    reg     [2:0]   prior_table_3_next, prior_table_3_reg;
    reg     [2:0]   prior_table_4_next, prior_table_4_reg;
    reg     [2:0]   prior_table_5_next, prior_table_5_reg;
    reg     [2:0]   prior_table_6_next, prior_table_6_reg;
    reg     [2:0]   prior_table_7_next, prior_table_7_reg;
    reg             oe_reg, oe_next;                // Output enable for the bidirectional bus
    reg     [7:0]   intrBus_reg, intrBus_next;      // Bus <= register if using bus as output
    reg             intrOut_reg, intrOut_next;      // Interrupt output

    //
    // Main FSM of the controller. The state machine is clocked. The output and next state logic
    // are purely combinational.
    //
    always @ (posedge clk_in or posedge rst_in) begin

        if (rst_in) begin
            state_reg           <=  S_Reset;
            cmdMode_reg         <=  2'b00;
            cmdCycle_reg        <=  2'b00;
            oe_reg              <=  1'b0;
            intrBus_reg         <=  8'bzzzzzzzz;
            intrOut_reg         <=  1'b0;
            intrIndex_reg       <=  3'b000;
            intrPtr_reg         <=  3'b000;
            prior_table_0_reg   <=  3'b000;
            prior_table_1_reg   <=  3'b000;
            prior_table_2_reg   <=  3'b000;
            prior_table_3_reg   <=  3'b000;
            prior_table_4_reg   <=  3'b000;
            prior_table_5_reg   <=  3'b000;
            prior_table_6_reg   <=  3'b000;
            prior_table_7_reg   <=  3'b000;
        end
 
        else begin
            state_reg           <=  state_next;
            cmdMode_reg         <=  cmdMode_next;
            cmdCycle_reg        <=  cmdCycle_next;
            intrBus_reg         <=  intrBus_next;
            intrOut_reg         <=  intrOut_next;
            oe_reg              <=  oe_next;
            intrIndex_reg       <=  intrIndex_next;
            intrPtr_reg         <=  intrPtr_next;
            prior_table_0_reg   <=  prior_table_0_next;
            prior_table_1_reg   <=  prior_table_1_next;
            prior_table_2_reg   <=  prior_table_2_next;
            prior_table_3_reg   <=  prior_table_3_next;
            prior_table_4_reg   <=  prior_table_4_next;
            prior_table_5_reg   <=  prior_table_5_next;
            prior_table_6_reg   <=  prior_table_6_next;
            prior_table_7_reg   <=  prior_table_7_next;
        end
    end

    //
    // The next state logic and the output functions.
    //
    always @(*) begin

        state_next          =   state_reg;
        cmdMode_next        =   cmdMode_reg;
        cmdCycle_next       =   cmdCycle_reg;
        oe_next             =   oe_reg;
        intrOut_next        =   intrOut_reg;
        intrBus_next        =   intrBus_reg;
        intrIndex_next      =   intrIndex_reg;
        intrPtr_next        =   intrPtr_reg;
        prior_table_0_next  =   prior_table_0_reg;
        prior_table_1_next  =   prior_table_1_reg;
        prior_table_2_next  =   prior_table_2_reg;
        prior_table_3_next  =   prior_table_3_reg;
        prior_table_4_next  =   prior_table_4_reg;
        prior_table_5_next  =   prior_table_5_reg;
        prior_table_6_next  =   prior_table_6_reg;
        prior_table_7_next  =   prior_table_7_reg;
 
        case (state_reg)
            // Reset state, every variable is set to zero and the bus is tristated.
            S_Reset: begin // 4'b0000
                cmdMode_next        =   2'b00;
                cmdCycle_next       =   2'b00;
                intrIndex_next      =   3'b000;
                intrPtr_next        =   3'b000;
                prior_table_0_next  =   3'b000;         // FIXME - Can this be in a loop?
                prior_table_1_next  =   3'b000;
                prior_table_2_next  =   3'b000;
                prior_table_3_next  =   3'b000;
                prior_table_4_next  =   3'b000;
                prior_table_5_next  =   3'b000;
                prior_table_6_next  =   3'b000;
                prior_table_7_next  =   3'b000;
                intrBus_next        =   8'bzzzzzzzz;
                oe_next             =   1'b0;
 
                state_next  =   S_GetCommands;          // Wait for commands.
            end
 
            // Wait for commands. The possible commands are,
            //
            // 01 - Polling mode where the priorities are fixed.
            // 10 - Priority mode. In this mode the controller receives the priorities
            //      for 4 cycles starting from the 2 highest to the lowest ones.
            //
            // Then set proper mode internally and start executing that sequence.
            //
            S_GetCommands: begin // 4'b0001
                oe_next =   1'b0;
                case (intr_bus[1:0])
                    2'b01: begin                                                // Polling mode.
                        cmdMode_next    =   2'b01;                              // Set mode to polling (internal).
                        state_next      =   S_JumpIntMethod;                    // Once done, start proper interrupt sequence.
                    end
 
                    2'b10: begin                                                // Priority mode.
                        case (cmdCycle_reg)
                            2'b00: begin
                                prior_table_0_next  =   intr_bus[7:5];          // Priority 0, highest priority.
                                prior_table_1_next  =   intr_bus[4:2];          // Priority 1
                                state_next          =   S_GetCommands;
                                cmdCycle_next       =   cmdCycle_reg + 1'b1;
                            end
                            2'b01: begin
                                prior_table_2_next  =   intr_bus[7:5];          // Priority 2
                                prior_table_3_next  =   intr_bus[4:2];          // Priority 3
                                state_next          =   S_GetCommands;
                                cmdCycle_next       =   cmdCycle_reg + 1'b1;
                            end
                            2'b10: begin
                                prior_table_4_next  =   intr_bus[7:5];          // Priority 4
                                prior_table_5_next  =   intr_bus[4:2];          // Priority 5
                                state_next          =   S_GetCommands;
                                cmdCycle_next       =   cmdCycle_reg + 1'b1;
                            end
                            2'b11: begin
                                prior_table_6_next  =   intr_bus[7:5];          // Priority 6
                                prior_table_7_next  =   intr_bus[4:2];          // Priority 7, lowest priority.
                                state_next          =   S_JumpIntMethod;        // Once done, start proper interrupt sequence.
                                cmdCycle_next       =   cmdCycle_reg + 1'b1;
                                cmdMode_next        =   2'b10;                  // Set mode to priority (internal).
                            end
                            default: begin
                                state_next      =   S_GetCommands;              // IMPORTANT: If there is any interruption in receiving
                                cmdCycle_next   =   2'b00;                      // priorities then the controller is reset.
                                cmdMode_next    =   2'b00;                      // Entire sequence must be restarted.
                            end
                        endcase
 
                    end
                    default: begin                                              // Stay in the state till valid commands are entered.
                        state_next  =   S_GetCommands;
                    end
                endcase
            end
 
            // Command mode is set to either polling or priority in the last state.
            // Depending on that value, either the polling routine begins or the
            // priority routine begins.
            //
            S_JumpIntMethod: begin // 4'b0010
                intrIndex_next  =   3'b000;
                intrPtr_next    =   3'b000;
 
                case (cmdMode_reg)
                    2'b01: begin                            // Start polling.
                        state_next  =   S_StartPolling;
                    end
                    2'b10: begin                            // State priority.
                        state_next  =   S_StartPriority;
                    end
                    default: begin                          // Invalid mode - reset the controller.
                        state_next  =   S_Reset;
                    end
                endcase
 
                intrBus_next    =   8'bzzzzzzzz;            // The bus is tristated.
                oe_next         =   1'b0;                   // Controller is not driving the bus.
            end
 
            // If the mode is polling then the controller enters this state.
            // The priorities are fixed in this mode.
            // It checks one source every clock cycle. If an interrupt input is active then
            // the output is set high and then the controller waits for an acknowledgement from the processor.
            //
            S_StartPolling: begin // 4'b0011
                if (intr_rq[intrIndex_reg]) begin           // If the current interrupt source is active.
                    intrOut_next    =   1'b1;               // Set the interrupt output bit to 1.
                    state_next      =   S_TxIntInfoPolling; // Transmit the information about this interrupt.
                end
                else begin                                  // If the current interrupt source is not active.
                    intrOut_next    =   1'b0;               // Make sure interrupt output is zero, redundant.
                    intrIndex_next  =   intrIndex_reg + 1;  // Check the next interrupt source.
                end

                intrBus_next    =   8'bzzzzzzzz;            // The bus is tristated.
                oe_next         =   1'b0;                   // Controller is not driving the bus.
            end
 
            // If the interrupt is active then we next send the information about it to the processor.
            // This information is sent on the bidirectional bus. It is sent after the interrupt has been acknowledged.
            //
            // The processor receives the request, processes it and returns acknowledgement on intr_in. (High to Low).
            // Upon receiving this acknowledgement, the controller sends the information about the interrupt on the bus.
            // Processor then sends the acknowlegement back to the controller. This is checked in the S_AckTxInfoRxPolling state.
            // 
            S_TxIntInfoPolling: begin // 4'b0100
                if (~intr_in) begin                                 // intr_in is from the processor to the controller.
                    intrOut_next    =   1'b0;                       // If processor has acknowledged the interrupt, lower it.
                    intrBus_next    =   {5'b01011, intrIndex_reg};  // 01011 is the control code that the lower 3 bits are the interrupt ID.
                    oe_next         =   1'b1;                       // Controller will drive the bus with this data.
                    state_next      =   S_AckTxInfoRxPolling;       // Go to acknowledge state and wait for the acknowledge.
                end                                                 // Wait until processor acknowledges the interrupt. Keep output high till that time.
            end

            // In the previous state, the processor had acknowledged the interrupt and the controller had sent the interrupt ID
            // to the processor. Upon receiving it, the processor again acknowledges it on the intr_in pin. (High to Low).
            // Once the processor acknowledges the address, the controller stops driving the bus and tristates it.
            // Then it waits for the processor to return when the interrupt is serviced.
            //
            S_AckTxInfoRxPolling: begin // 4'b0101
                if (~intr_in) begin                                 // The processor has acknowledged the interrupt address.
                    intrBus_next    =   8'bzzzzzzzz;                // Tristate the bus.
                    oe_next         =   1'b0;                       // Controller no longer drives the bus.
                    state_next      =   S_AckISRDonePolling;        // Go do polling done state.
                end                                                 // Wait until processor acknowledges the address. Keep bus active till that time.
            end
 
            // Once the processor has acknowledged the interrupt and the address of the interrupt,
            // It will send the acknowledge on the bus once the interrupt has been serviced.
            // Wait till that information is received and then go back to poll next source.
            //
            S_AckISRDonePolling: begin // 4'b0110
                // If the proper source and condition has been acknowleged, check next interrupt.
                if ((~intr_in) && (intr_bus[7:3] == 5'b10100) && (intr_bus[2:0] == intrIndex_reg)) begin
                    state_next  =   S_StartPolling;
                end
                // If the acknowledgement did not have proper condition codes then that is an error and
                // controller goes back to reset.
                else if ((~intr_in) && (intrBus_reg[7:3] != 5'b10100) && (intrBus_reg[2:0] != intrIndex_reg)) begin
                    state_next  =   S_Reset;
                end
                else begin
                    state_next  =   S_AckISRDonePolling;            // Else wait in the current state.
                end
            end
 
            // If the mode is priority mode then the controller enters this state.
            // The priorities are decided by the 4 cycles received during initialization.
            // It checks one source every clock cycle. If an interrupt input is active then
            // the output is set high and then the controller waits for an acknowledgement from the processor.
            //
            // Instead of checking the sources from 0 to 7, it checks the internal storage sorted according to
            // the priorities received during the initialization.
            //
            S_StartPriority: begin // 4'b0111
                if (intr_rq[prior_table_0_reg]) begin               // Check if the highest priority source is active.
                    intrPtr_next    =   prior_table_0_reg;          // If the highest priority interrupt is active,
                    intrOut_next    =   1'b1;                       // set the output high.
                    state_next      =   S_TxIntInfoPriority;        // Go wait for acknowledgement.
                end
 
                else if (intr_rq[prior_table_1_reg]) begin          // Else check the next highest priority.
                    intrPtr_next    =   prior_table_1_reg;          // Continue as above.
                    intrOut_next    =   1'b1;
                    state_next      =   S_TxIntInfoPriority;
                end
 
                else if (intr_rq[prior_table_2_reg]) begin
                    intrPtr_next    =   prior_table_2_reg;
                    intrOut_next    =   1'b1;
                    state_next      =   S_TxIntInfoPriority;
                end
 
                else if (intr_rq[prior_table_3_reg]) begin
                    intrPtr_next    =   prior_table_3_reg;
                    intrOut_next    =   1'b1;
                    state_next      =   S_TxIntInfoPriority;
                end
 
                else if (intr_rq[prior_table_4_reg]) begin
                    intrPtr_next    =   prior_table_4_reg;
                    intrOut_next    =   1'b1;
                    state_next      =   S_TxIntInfoPriority;
                end
 
                else if (intr_rq[prior_table_5_reg]) begin
                    intrPtr_next    =   prior_table_5_reg;
                    intrOut_next    =   1'b1;
                    state_next      =   S_TxIntInfoPriority;
                end
 
                else if (intr_rq[prior_table_6_reg]) begin
                    intrPtr_next    =   prior_table_6_reg;
                    intrOut_next    =   1'b1;
                    state_next      =   S_TxIntInfoPriority;
                end
 
                else if (intr_rq[prior_table_7_reg]) begin
                    intrPtr_next    =   prior_table_7_reg;
                    intrOut_next    =   1'b1;
                    state_next      =   S_TxIntInfoPriority;
                end
 
                else begin                                          // If none of the sources is active, then wait
                    state_next  =   S_StartPriority;                // till one of them is active.
                end

                intrBus_next    =   8'bzzzzzzzz;                    // The bus is tristated.
                oe_next         =   1'b0;                           // Controller is not driving the bus.
            end

            // Once the interrupt output is set active, the controller then waits for an acknowledgement from the processor.
            // The processor acknowledges the interrupt by the intr_in pin (High to Low).
            //
            // Once the interrupt is acknowledged, we have to send the information about the interrupt to the processor.
            // It's sent on the bidirectional bus along with some condition code bits.
            //
            S_TxIntInfoPriority: begin // 4'b1000
                if (~intr_in) begin                                 // If the processor has acknowledged the interrupt.
                    intrOut_next    =   1'b0;                       // Make the interrupt output low.
                    intrBus_next    =   {5'b10011, intrPtr_reg};    // Send the address and the condition codes.
                    oe_next         =   1'b1;                       // Controller is driving the bus.
                    state_next      =   S_AckTxInfoRxPriority;      // Wait for address acknowledgement from the processor.
                end                                                 // Else wait till interrupt is acknowledged.
            end
            
            // After the address is sent to the processor, the controller again waits for an acknowledgement from the processor.
            // It's again given on the intr_in pin (High to Low).
            //
            // After receiving this acknowledgement, the controller then waits for the processor to finish executing the
            // interrupt service routine. 
            // 
            S_AckTxInfoRxPriority: begin // 4'b1001
                if (~intr_in) begin                                 // Address has been acknowledged.
                    intrBus_next    =   8'bzzzzzzzz;                // The bus is tristated.
                    oe_next         =   1'b0;                       // Controller no longer drives the bus.
                    state_next      =   S_AckISRDonePriority;       // Go and wait for interrupt to be serviced.
                end
            end
            
            // Once the processor acknowledges that the interrupt has been serviced, it sends condition codes
            // along with the interrupt priority to the controller.
            //
            // It also acknowledges this on the intr_in pin (High to Low).
            // Once this has been acknowledged, the controller returns to check the interrrupt sources.
            S_AckISRDonePriority: begin // 4'b1010
                // If the proper source and condition has been acknowleged, check next interrupt.
                if ((~intr_in) && (intrBus_reg[7:3] == 5'b01100) && (intrBus_reg[2:0] == intrPtr_reg)) begin
                    state_next  =   S_StartPriority;
                end
                // Else, the controller assumes this to be an error. (If the condition codes are wrong).
                // In that case it returns to reset state.
                else if ((~intr_in) && (intrBus_reg[7:3] != 5'b01100) && (intrBus_reg[2:0] != intrPtr_reg)) begin
                    state_next  =   S_Reset;
                end
                else begin
                    state_next  =   S_AckISRDonePriority;           // Else wait in the current state.
                end
            end
            
            // If the state bits are invalid then go to reset.
            default: begin
                state_next      =   S_Reset;
                intrBus_next    =   8'bzzzzzzzz;
                oe_next         =   1'b0;
            end
        endcase
    end

    // Interrupt output. It's the same as the intrOut_reg but done like this for clarity.
    assign intr_out =   intrOut_reg;
    // Bus is bidirectional. oe (output enable) decides if the controller is driving it
    // or is expecting input on it.
    assign intr_bus =   (oe_reg) ? intrBus_reg : 8'bzzzzzzzz;

endmodule // INTR_CNTRL

