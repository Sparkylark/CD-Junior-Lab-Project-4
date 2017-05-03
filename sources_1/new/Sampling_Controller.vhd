library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;


entity Sampling_Controller is
    Generic(
        constant numSamples: integer:= 256;
        constant sampleRate: integer:= 4500 --Hz
    );
    Port (
        sysClk          :in std_logic;
        reset           :in std_logic;
        collectBtn      :in std_logic;
        ADC_busy        :in std_logic;
        dataReady       :in std_logic;
        digiData        :in std_logic_vector(7 downto 0);
        sampleNow       :out std_logic;
        UART_busy       :in std_logic;
        UART_En         :out std_logic;
        transData       :out std_logic_vector(7 downto 0);
        whichPWM        :in std_logic;
        PWM_Out         :out std_logic
    );
end Sampling_Controller;

architecture Behavioral of Sampling_Controller is

component blk_mem_gen_0 IS
  PORT (
    clka : IN STD_LOGIC;
    wea : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    addra : IN STD_LOGIC_VECTOR(8 DOWNTO 0);
    dina : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
    douta : OUT STD_LOGIC_VECTOR(7 DOWNTO 0)
  );
END component;

type machine is(ready, start, sample11, sample12, sample13, live1, live2, live3,
                 delay1, delay2, delay3, sample21, endSample, sendPrep1, sendPrep2, send1, send2, send3, btnRelease);
signal sampleCount, rateCount, rateCountMax: integer:= 0;
signal samplePulse      :std_logic:='0';
signal currentData      :std_logic_vector(7 downto 0);
signal RAM_Address      :unsigned(8 downto 0):="000000000";
signal state, returnTo  :machine:=ready;
signal wea              : STD_LOGIC_VECTOR(0 DOWNTO 0):= "0";
signal addra            : STD_LOGIC_VECTOR(8 DOWNTO 0);
signal addraTrue        : STD_LOGIC_VECTOR(8 DOWNTO 0);
signal dina             : STD_LOGIC_VECTOR(7 DOWNTO 0);
signal douta            : STD_LOGIC_VECTOR(7 DOWNTO 0);
signal PWMCount, PWMCountMax      :integer:=0;
signal PWMPulse         :std_logic:='0';
signal PWM_En           :std_logic:='0';
signal Count256         :integer range 0 to 255:=0;
signal PWMcurrentSample :integer;
signal PWMCurrentAddr   :unsigned(8 downto 0):="000000000";

begin
rateCountMax <= 100000000/sampleRate; -- for 100 MHz System Clock
PWMCountMax <= (100000000/sampleRate)/256;

init_RAM: blk_mem_gen_0
port map(
    clka => sysClk,
    wea => wea,
    addra => addraTrue,
    dina => dina,
    douta => douta
    );

--clock enabler pulse for desired sampling rate
	process(sysClk, reset)
	begin
	if (reset = '1') then
	   rateCount <= 0;
	elsif rising_edge(sysClk) then
		if (rateCount = rateCountMax) then
			rateCount <= 0;
			samplePulse <= '1';
		else
			rateCount <= rateCount + 1;
			samplePulse <= '0';
		end if;
	end if;
	end process;

--clock enabler pulse for PWM transmission. About 256 times faster than the above clock
	process(sysClk, reset)
	begin
	if (reset = '1') then
	   PWMCount <= 0;
	elsif rising_edge(sysClk) then
		if (PWMCount = PWMCountMax) then
			PWMCount <= 0;
			PWMPulse <= '1';
		else
			PWMCount <= PWMCount + 1;
			PWMPulse <= '0';
		end if;
	end if;
	end process;

    process(sysClk)
    begin
        if(PWM_En = '0') then
            addraTrue <= addra;
        else
            addraTrue <= std_logic_vector(PWMCurrentAddr);
        end if;   
    end process;

--main state machine
    process(sysClk, reset)
    begin
        if (reset = '1') then
            sampleNow <= '0';
            UART_En <= '0';
            transData <= "00000000";
            RAM_Address <= "000000000";
            state <= start;
        elsif (rising_edge(sysClk)) then
            case state is
                when ready =>
                    if(collectBtn = '1') then
                        state <= start;
                    end if;
                when start =>
                    sampleCount <= 0;
                    RAM_Address <= "000000000";
                    PWM_En <= '0';
                    state <= sample11;
                when sample11 =>
                    if(ADC_busy = '0' and samplePulse = '1') then
                        sampleNow <= '1';
                        state <= sample12;
                    end if;
                when sample12 =>
                    if(ADC_busy = '1') then
                        sampleNow <= '0';
                        state <= sample13;
                    end if;
                when sample13 =>
                    if(dataReady = '1') then
                        currentData <= digiData;
                        returnTo <= sample21;
                        if(sampleRate < 5500) then
                            state <= live1;
                        else
                            state <= delay1;
                        end if;
                    end if;
                when live1 =>
                    UART_En <= '1';
                    if(UART_busy = '0') then
                        transData <= currentData;
                        --transData <= "01101110";
                        dina <= currentData;
                        addra <= std_logic_vector(RAM_Address);
                        state <= live2;
                    end if;
                when live2 =>
                    if(UART_busy = '1') then
                        UART_En <= '0';
                        wea <= "1";
                        RAM_Address <= RAM_Address + "1";
                        state <= live3;
                    end if;
                when live3 =>
                    wea <= "0";
                    state <= returnTo;
                when delay1 =>
                    dina <= currentData;
                    --dina <= std_logic_vector(RAM_Address(7 downto 0));
                    addra <= std_logic_vector(RAM_Address);
                    state <= delay2;
                when delay2 =>
                    wea <= "1";
                    state <= delay3;
                when delay3 =>
                    wea <= "0";
                    RAM_Address <= RAM_Address + "1";
                    state <= returnTo;
                when sample21 =>
                    if(ADC_busy = '0') then
                        currentData <= digiData;
                        sampleCount <= sampleCount + 1;
                        returnTo <= endSample;
                        if(sampleRate < 5500) then
                            state <= live1;
                        else
                            state <= delay1;
                        end if; 
                    end if;
                when endSample =>
                    if(sampleCount < numSamples) then
                        state <= sample11;
                    elsif (sampleRate < 5500) then
                        PWM_En <= '1';
                        state <= btnRelease;
                    elsif (sampleRate >= 5500) then
                        RAM_Address <= "000000000";
                        state <= sendPrep1;
                    end if; 
                when sendPrep1 =>
                    addra <= "000000000";
                    state <= sendPrep2;
                when sendPrep2 =>
                    transData <= douta;
                    RAM_Address <= RAM_Address;
                    state <= send1;
                when send1 =>
                    addra <= std_logic_vector(RAM_Address);
                    state <= send2;
                when send2 =>
                    if(UART_busy = '0') then
                        transData <= douta;
                        RAM_Address <= RAM_Address + 1;
                        UART_En <= '1';
                        state <= send3;
                    end if;            
                when send3 =>
                    if(UART_busy = '1') then
                        if(RAM_Address < numSamples*2 and RAM_Address /= "000000000") then
                            state <= send1;
                        else
                            UART_En <= '0';
                            PWM_En <= '1';
                            state <= btnRelease;
                        end if;
                    end if;      
                when btnRelease =>
                    if(collectBtn = '0') then
                        RAM_Address <= "000000000";
                        state <= ready;
                    end if;  
            end case;
        end if;
    end process;

--PWM Driver
    process(sysClk, reset)
    begin
        if(reset = '1' or PWM_En = '0') then
            Count256 <= 0;
            PWM_Out <= '0';
            if(whichPWM= '0') then
                PWMCurrentAddr <= "000000000";
            else
                PWMCurrentAddr <= "000000001";
            end if;
        elsif(rising_edge(sysClk) and PWMPulse = '1') then
            if(unsigned(douta) > Count256) then  --output is high while the current sample is higher than the pulse count
                PWM_Out <= '1';
            else
                PWM_Out <= '0';
            end if;
            if(Count256 < 255) then
                Count256 <= Count256 + 1;
            else
                Count256 <= 0;
                if(PWMCurrentSample < numSamples) then  --increment sample
                    PWMCurrentAddr <= PWMCurrentAddr + 2;
                    PWMCurrentSample <= PWMCurrentSample + 1;
                else    --loop to first sample
                    if(whichPWM= '0') then
                        PWMCurrentAddr <= "000000000";
                    else
                        PWMCurrentAddr <= "000000001";
                    end if;
                    PWMCurrentSample <= 0;
                end if;
            end if;
        end if;
    end process;
end Behavioral;
