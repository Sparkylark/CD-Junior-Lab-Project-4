
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
--use IEEE.NUMERIC_STD.ALL;


entity ADC_Controller is
  Port ( sysClk         :in std_logic;
         Reset          :in std_logic;
         Pulse_2_4MHz   :in std_logic;
         sampleNow      :in std_logic;
         dataReady      :out std_logic;
         busy           :out std_logic;
         digiData       :out std_logic_vector(7 downto 0);
         chipClk        :out std_logic;
         A              :out std_logic;
         ALE            :out std_logic;
         Start          :out std_logic;
         OE             :out std_logic;
         EOC            :in std_logic;
         inData         :in std_logic_vector(7 downto 0)
  );
end ADC_Controller;

architecture Behavioral of ADC_Controller is

signal chipClkSig       :std_logic:='0';
type machine is(ready, start11, start12, start13, wait1, read11, read12, start21, start22, start23, wait2, read21, read22);
signal state            :machine;
signal count            :integer;

begin
chipClk <= chipClkSig;
-- divided clock creation
    process(sysClk, Pulse_2_4MHz, Reset)
    begin
        if (Reset = '1') then
            chipClkSig <= '0';
        elsif (rising_edge(sysClk) and Pulse_2_4MHz = '1') then
            chipClkSig <= not chipClkSig;
        end if;
    end process;

-- state machine
    process(Reset, chipClkSig)
    begin
        if(Reset = '1') then
            A <= '0';
            ALE <= '0';
            Start <= '0';
            OE <= '0';
            dataReady <= '0';
            digiData <= "00000000";
            busy <= '0';
            state <= ready;
        elsif rising_edge(chipClkSig) then
            case state is
            when ready =>
                if (sampleNow = '0') then
                    busy <= '0';
                else
                    busy <= '1';
                    dataReady <= '0';
                    A <= '0';
                    state <= start11;
                end if;
            when start11 =>
                ALE <= '1';
                count <= 0;
                state <= start12;
            when start12 =>
                if(count < 3) then -- could probably change to (count < 2)
                    count <= count + 1;
                else
                    ALE <= '0';
                    Start <= '1';
                    state <= start13;
                end if;
            when start13 =>
                start <= '0';
                state <= wait1;
            when wait1 =>
                if(EOC = '1') then
                    OE <= '1';
                    state <= read11;
                end if;
            when read11 =>
                digiData <= inData;
                dataReady <= '1';
                state <= read12;
            when read12 => 
                OE <= '0';
                A <= '1';
                state <= start21;
            when start21 => 
                ALE <= '1';
                count <= 0;
                state <= start22;
            when start22 =>
                if(count < 3) then
                    count <= count + 1;
                else
                    ALE <= '0';
                    Start <= '1';
                    state <= start23;
                end if;
            when start23 =>
                start <= '0';
                state <= wait2;
            when wait2 =>
                dataReady <= '0';
                if(EOC = '1') then
                    OE <= '1';
                    state <= read21;
                end if;
            when read21 =>
                digiData <= inData;
                dataReady <= '1';
                state <= read22;
            when read22 =>
                OE <= '0';
                A <= '0';
                busy <= '0';
                state <= ready;     
            end case;        
        end if;
    end process;
end Behavioral;
