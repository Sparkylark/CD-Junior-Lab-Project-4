library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity top_level is
    PORT (
            CLK100MHZ        :in std_logic;
            Btn_Reset        :in std_logic; -- BTNC
            Btn_Collect      :in std_logic; -- BTNR
            Btn_PWM          :in std_logic; -- BTNL
            serialTrans      :out std_logic; -- Pmod C 1
            PWM_Out          :out std_logic; -- Pmod C 2
            ADC_CLK          :out std_logic; -- Pmod A 3
			ADC_A            :out std_logic; -- Pmod A 4
			ADC_ALE          :out std_logic; -- Pmod A 7
			ADC_START        :out std_logic; -- Pmod A 8
			ADC_OE           :out std_logic; -- Pmod A 9
			ADC_EOC          :in std_logic; -- Pmod A 10
			ADC_Data         :in std_logic_vector(7 downto 0) --Pmod B
         );
END top_level;

architecture Behavioral of top_level is

component Reset_Delay IS	
    PORT (
        iCLK : IN std_logic;	
        oRESET : OUT std_logic
			);	
END component;

component btn_debounce_toggle is
GENERIC (
	CONSTANT CNTR_MAX : std_logic_vector(15 downto 0) := X"FFFF");  
	--CONSTANT CNTR_MAX : std_logic_vector(15 downto 0) := X"000F");  --Simulation ONLY
    Port ( BTN_I 	: in  STD_LOGIC;
           CLK 		: in  STD_LOGIC;
           BTN_O 	: out  STD_LOGIC;
           TOGGLE_O : out  STD_LOGIC);
end component;

component clk_enabler is
	GENERIC (
		CONSTANT cnt_max : integer := 49999999); -- 1 second
	port(	
		clock:		in std_logic;
		Reset:      in std_logic; 
		clk_en: 	out std_logic
	);
end component;

component Sampling_Controller is
    Generic(
        constant numSamples: integer;
        constant sampleRate: integer --Hz
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
end component;

component ADC_Controller is
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
end component;

component UART_Transmit is
    Port(   sysClk          :in std_logic;
            baudClkEn       :in std_logic;
            reset           :in std_logic;
            enable          :in std_logic;
            transData       :in std_logic_vector(7 downto 0);
            busy            :out std_logic;
            TX              :out std_logic
  );
end component;

signal initReset  	:std_logic;
signal resetDeb, collectDeb :std_logic;
signal Reset		:std_logic;
signal chipClkTog, baudClkEn			:std_logic;
signal sampleNow, dataReady, ADC_busy   :std_logic;
signal UART_En, UART_busy                  :std_logic;
signal digiData, transData         :std_logic_vector(7 downto 0);
signal PWMToggle                :std_logic;


begin	
Reset <= initReset or resetDeb;
init_reset_Delay: reset_Delay
port map (iCLK => CLK100MHZ, oRESET => initReset);

init_reset_Debounce: btn_debounce_toggle
GENERIC map(CNTR_MAX => X"FFFF")
	--CONSTANT CNTR_MAX : std_logic_vector(15 downto 0) := X"000F");  --Simulation ONLY
Port map( 	BTN_I => Btn_Reset,	
				CLK => CLK100MHZ,
				BTN_O => resetDeb,
				TOGGLE_O => open);

init_capture_Debounce: btn_debounce_toggle
GENERIC map(CNTR_MAX => X"FFFF")
	--CONSTANT CNTR_MAX : std_logic_vector(15 downto 0) := X"000F");  --Simulation ONLY
Port map( 	BTN_I => Btn_Collect,	
				CLK => CLK100MHZ,
				BTN_O => collectDeb,
				TOGGLE_O => open);

init_PWM_Toggle: btn_debounce_toggle
GENERIC map(CNTR_MAX => X"FFFF")
	--CONSTANT CNTR_MAX : std_logic_vector(15 downto 0) := X"000F");  --Simulation ONLY
Port map( 	BTN_I => Btn_PWM,	
				CLK => CLK100MHZ,
				BTN_O => open,
				TOGGLE_O => PWMToggle);
				
--this enable pulse is to be used as the toggle signal for a 1.2MHz clock.			
init_2_4MHz_Enabler: clk_enabler
Generic map(cnt_max => 42)
Port map(   clock => CLK100MHZ,
            Reset => Reset,
            clk_en => chipClkTog);
            
init_115_2KHz_Enabler: clk_enabler
Generic map(cnt_max => 868)
Port map(   clock => CLK100MHZ,
            Reset => Reset,
            clk_en => baudClkEn);

init_sampling_controller: Sampling_Controller
Generic map(
    numSamples => 256,
    sampleRate => 6500 --Hz
)
Port map(
    sysClk => CLK100MHZ,
    reset => Reset,
    collectBtn => collectDeb,
    ADC_busy => ADC_busy,
    dataReady => dataReady,
    digiData => digiData,
    sampleNow => sampleNow,
    UART_busy => UART_busy,
    UART_En => UART_En,
    transData => transData,
    whichPWM => PWMToggle,
    PWM_Out => PWM_Out
);


init_ADC_controller: ADC_Controller
Port map( sysClk => CLK100MHZ,        
       Reset => Reset,         
       Pulse_2_4MHz => chipClkTog,
       sampleNow => sampleNow,  
       dataReady => dataReady, 
       busy => ADC_busy,    
       digiData => digiData,   
       chipClk => ADC_CLK,     
       A => ADC_A,
       ALE => ADC_ALE, 
       Start => ADC_START,
       OE => ADC_OE,
       EOC => ADC_EOC,
       inData => ADC_Data
);

init_UART: UART_Transmit
Port map(   sysClk => CLK100MHZ,      
            baudClkEn => baudClkEn,
            reset => Reset,
            enable => UART_En,
            transData => transData,
            busy => UART_busy,
            TX => serialTrans
  );
END Behavioral;