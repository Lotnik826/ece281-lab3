--+----------------------------------------------------------------------------
--| 
--| COPYRIGHT 2017 United States Air Force Academy All rights reserved.
--| 
--| United States Air Force Academy     __  _______ ___    _________ 
--| Dept of Electrical &               / / / / ___//   |  / ____/   |
--| Computer Engineering              / / / /\__ \/ /| | / /_  / /| |
--| 2354 Fairchild Drive Ste 2F6     / /_/ /___/ / ___ |/ __/ / ___ |
--| USAF Academy, CO 80840           \____//____/_/  |_/_/   /_/  |_|
--| 
--| ---------------------------------------------------------------------------
--|
--| FILENAME      : thunderbird_fsm.vhd
--| AUTHOR(S)     : Capt Phillip Warner, Capt Dan Johnson
--| CREATED       : 03/2017 Last modified 06/25/2020
--| DESCRIPTION   : This file implements the ECE 281 Lab 2 Thunderbird tail lights
--|					FSM using enumerated types.  This was used to create the
--|					erroneous sim for GR1
--|
--|					Inputs:  i_clk 	 --> 100 MHz clock from FPGA
--|                          i_left  --> left turn signal
--|                          i_right --> right turn signal
--|                          i_reset --> FSM reset
--|
--|					Outputs:  o_lights_L (2:0) --> 3-bit left turn signal lights
--|					          o_lights_R (2:0) --> 3-bit right turn signal lights
--|
--|					Upon reset, the FSM by defaults has all lights off.
--|					Left ON - pattern of increasing lights to left
--|						(OFF, LA, LA/LB, LA/LB/LC, repeat)
--|					Right ON - pattern of increasing lights to right
--|						(OFF, RA, RA/RB, RA/RB/RC, repeat)
--|					L and R ON - hazard lights (OFF, ALL ON, repeat)
--|					A is LSB of lights output and C is MSB.
--|					Once a pattern starts, it finishes back at OFF before it 
--|					can be changed by the inputs
--|					

--|                 One-Hot Encoding Table
                    ----------------------
                    
--|                 |  State | S7  | S6  | S5  | S4  | S3  | S2  | S1  | S0  |
--|                 | ------ | --- | --- | --- | --- | --- | --- | --- | --- |
--|                 | OFF    | 1   | 0   | 0   | 0   | 0   | 0   | 0   | 0   |
--|                 | ON     | 0   | 1   | 0   | 0   | 0   | 0   | 0   | 0   |
--|                 | R1     | 0   | 0   | 1   | 0   | 0   | 0   | 0   | 0   |
--|                 | R2     | 0   | 0   | 0   | 1   | 0   | 0   | 0   | 0   |
--|                 | R3     | 0   | 0   | 0   | 0   | 1   | 0   | 0   | 0   |
--|                 | L1     | 0   | 0   | 0   | 0   | 0   | 1   | 0   | 0   |
--|                 | L2     | 0   | 0   | 0   | 0   | 0   | 0   | 1   | 0   |
--|                 | L3     | 0   | 0   | 0   | 0   | 0   | 0   | 0   | 1   |
--|
--|
--|
--+----------------------------------------------------------------------------
--|
--| REQUIRED FILES :
--|
--|    Libraries : ieee
--|    Packages  : std_logic_1164, numeric_std
--|    Files     : None
--|
--+----------------------------------------------------------------------------
--|
--| NAMING CONVENSIONS :
--|
--|    xb_<port name>           = off-chip bidirectional port ( _pads file )
--|    xi_<port name>           = off-chip input port         ( _pads file )
--|    xo_<port name>           = off-chip output port        ( _pads file )
--|    b_<port name>            = on-chip bidirectional port
--|    i_<port name>            = on-chip input port
--|    o_<port name>            = on-chip output port
--|    c_<signal name>          = combinatorial signal
--|    f_<signal name>          = synchronous signal
--|    ff_<signal name>         = pipeline stage (ff_, fff_, etc.)
--|    <signal name>_n          = active low signal
--|    w_<signal name>          = top level wiring signal
--|    g_<generic name>         = generic
--|    k_<constant name>        = constant
--|    v_<variable name>        = variable
--|    sm_<state machine type>  = state machine type definition
--|    s_<signal name>          = state name
--|
--+----------------------------------------------------------------------------
library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;
  
  
 
entity thunderbird_fsm is
    port (
        i_clk, i_reset  : in    std_logic;
        i_left, i_right : in    std_logic;
        o_lights_L      : out   std_logic_vector(2 downto 0);
        o_lights_R      : out   std_logic_vector(2 downto 0)
    );
end thunderbird_fsm;

architecture thunderbird_fsm_arch of thunderbird_fsm is 

-- CONSTANTS ------------------------------------------------------------------
    --enum state types
    type sm_state is (s_OFF, s_ON, s_R1, s_R2, s_R3, s_L1, s_L2, s_L3);
    
    --signals for current state and next state
    signal f_Q, f_Q_next : sm_state;
    
    
  
begin

	-- CONCURRENT STATEMENTS --------------------------------------------------------	
	
    ---------------------------------------------------------------------------------
	
	-- PROCESSES --------------------------------------------------------------------
	
    -----------------------------------------------------
    --Handles clock and synchronus reset
    register_proc : process (i_clk)
    begin
        if rising_edge(i_clk) then
            if i_reset = '1' then	
               f_Q <= s_OFF;
            else
                f_Q <= f_Q_next;
            end if;
        end if;
    end process register_proc;
    
    --determines the next state based on current state and inputs
    next_state_proc : process(f_Q, i_left, i_right)
    begin
        f_Q_next <= s_OFF;
        
        case f_Q is
            when s_OFF =>
                if i_left = '1' and i_right = '1' then
                    f_Q_next <= s_ON;   --Hazards
                elsif i_left = '1' and i_right = '0' then
                    f_Q_next <= s_L1;   --Left Turn
                elsif i_left = '0' and i_right = '1' then
                    f_Q_next <= s_R1;   --Right Turn
                else
                    f_Q_next <= s_OFF;  --Off
                end if;
            
            --Left Turn
            when s_L1 => f_Q_next <= s_L2;
            when s_L2 => f_Q_next <= s_L3;
            when s_L3 => f_Q_next <= s_OFF;
            
            --Right Turn
            when s_R1 => f_Q_next <= s_R2;
            when s_R2 => f_Q_next <= s_R3;
            when s_R3 => f_Q_next <= s_OFF;
            
            --Hazards
            when s_ON => f_Q_next <= s_OFF;
            
            --else
            when others => f_Q_next <= s_OFF;
            
          end case;
    end process next_state_proc;
    
    output_proc : process (f_Q)
    begin
        
        o_lights_L <= "000";
        o_lights_R <= "000";
        
        case f_Q is
            when s_OFF =>
                o_lights_L <= "000";
                o_lights_R <= "000";
            when s_L1 =>
                o_lights_L <= "001"; --LA
            when s_L2 =>
                o_lights_L <= "011"; --LA, LB
            when s_L3 =>
                o_lights_L <= "111"; --LA, LB, LC
            when s_R1 =>
                o_lights_R <= "001"; --RA
            when s_R2 =>
                o_lights_R <= "011"; --RA, RB
            when s_R3 =>
                o_lights_R <= "111"; --RA, RB, RC
            when s_ON =>
                o_lights_L <= "111"; --all left
                o_lights_R <= "111"; --all right
            when others =>
                o_lights_L <= "000";
                o_lights_R <= "000";
            end case;
    end process output_proc;
                
                  
                    				   
				  
end thunderbird_fsm_arch;