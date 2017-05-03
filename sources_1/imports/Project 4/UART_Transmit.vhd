library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
--use IEEE.NUMERIC_STD.ALL;


entity UART_Transmit is
    Port(   sysClk          :in std_logic;
            baudClkEn       :in std_logic;
            reset           :in std_logic;
            enable          :in std_logic;
            transData       :in std_logic_vector(7 downto 0);
            busy            :out std_logic;
            TX              :out std_logic
  );
end UART_Transmit;

architecture Behavioral of UART_Transmit is

type machine is(ready, start, s0, s1, s2, s3, s4, s5, s6, s7, stop);
signal currentData      :std_logic_vector(7 downto 0);
signal state            :machine;

begin

process(reset, sysClk)
begin
    if(reset = '1') then
        busy <= '1';
        TX <= '1';
        state <= ready;
    elsif(rising_edge(sysClk) and baudClkEn = '1') then
        case state is
            when ready =>
                TX <= '1';
                busy <= '0';
                if (enable = '1') then
                    state <= start;
                end if;
            when start =>
                TX <= '0';
                busy <= '1';
                currentData <= transData;
                state <= s0;
            when s0 =>
                TX <= currentData(0);
                state <= s1;
            when s1 =>
                TX <= currentData(1);
                state <= s2;
            when s2 =>
                TX <= currentData(2);
                state <= s3;
            when s3 =>
                TX <= currentData(3);
                state <= s4;
            when s4 =>
                TX <= currentData(4);
                state <= s5;
            when s5 =>
                TX <= currentData(5);
                state <= s6;
            when s6 =>
                TX <= currentData(6);
                state <= s7;
            when s7 =>
                TX <= currentData(7);
                state <= stop;
            when stop =>
                TX <= '1';
                busy <= '0';
                if(enable = '1') then
                    state <= start;
                else
                    state <= ready;
                end if;
        end case;
    end if;
end process;

end Behavioral;
