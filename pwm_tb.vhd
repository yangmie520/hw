library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use IEEE.std_logic_unsigned.all;

entity breath_tb is
end entity breath_tb;

architecture test of breath_tb is
  signal clk  : std_logic := '0';
  signal rst  : std_logic := '0';
  signal sw   : std_logic := '0';  -- 新增開關信號
  signal btn  : std_logic := '0';
  signal o_led: std_logic := '0';
    component breath
        Port ( i_clk : in STD_LOGIC;
           i_rst : in STD_LOGIC;
           i_sw  : in STD_LOGIC;  -- 新增開關輸入
           i_btn : in STD_LOGIC;
           o_led : out STD_LOGIC
         );
    end component;  
begin

-- Clock process definitions
clk_gen: process
 begin
    clk <= '0';
    wait for 10ns;
    clk <= '1';
    wait for 10ns;
 end process;
  
  -- Instantiate the design under test
  dut: breath
    Port map( 
           i_clk => clk,
           i_rst => rst,
           i_sw  => sw,   -- 連接開關信號
           i_btn => btn,
           o_led => o_led
         );
    
  -- Generate the test stimulus
  stimulus:
  process begin
      rst <= '0';
      sw <= '0';   -- 開始時 P=3
      btn <='0';
      wait for 100 ns;
      rst <= '1';
      
      wait for 1 ms;  -- 觀察 P=3 的效果
      
      sw <= '1';  -- 切換到 P=7
       btn <='1'; 
      wait for 100 us;  -- 觀察 P=7 的效果
      
       sw <= '1';  -- 切換到 P=7
       btn <='0'; 
      wait for 1000 us;  -- 觀察 P=7 的效果
      
       sw <= '1';  -- 切換到 P=7
       btn <='1'; 
      wait for 100 us;  -- 觀察 P=7 的效果
      
          sw <= '1';  -- 切換到 P=7
       btn <='0'; 
      wait for 1000 us;  -- 觀察 P=7 的效果
      
      
      sw <= '0';   -- 切換回 P=3
      btn <='1';
      wait for 100 us;  -- 再次觀察 P=3 的效果
      
      sw <= '0';   -- 切換回 P=3
      btn <='0';
      wait for 100 us;  -- 再次觀察 P=3 的效果

    -- Testing complete
    wait;
  end process stimulus;
  
end architecture test;