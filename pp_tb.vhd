library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use IEEE.std_logic_unsigned.all;

entity pp is
    Port ( i_clk : in STD_LOGIC;
           i_rst : in STD_LOGIC;
           i_btL : in STD_LOGIC;  -- 左邊按鍵（擊球/發球）
           i_btR : in STD_LOGIC;  -- 右邊按鍵（擊球/發球）
           i_swL : in STD_LOGIC;  -- 左邊速度選擇：1=快(clk_div(0))，0=慢(clk_div(1))
           i_swR : in STD_LOGIC;  -- 右邊速度選擇：1=快(clk_div(0))，0=慢(clk_div(1))
           o_led : out STD_LOGIC_VECTOR (7 downto 0)
           );
end pp;

architecture Behavioral of pp is
    type STATE_TYPE is (MovingL, MovingR, Lwin, Rwin);
    signal state : STATE_TYPE;
    signal led_r : STD_LOGIC_VECTOR (7 downto 0);
    signal scoreL : STD_LOGIC_VECTOR (3 downto 0);
    signal scoreR : STD_LOGIC_VECTOR (3 downto 0);
    signal L      : std_logic := '0';
    signal R      : std_logic := '0';

    signal clk_div   : unsigned(23 downto 0) := (others => '0');
    signal ra1       : std_logic;

    -- LED 顯示用（在 ra1 域）狀態記憶
    signal prev_state : STATE_TYPE := MovingR;

    -- 球速選擇：0=>clk_div(0) 快，1=>clk_div(1) 慢
    signal ball : std_logic := '1';

    -- 球速選擇用（在 i_clk 域）狀態記憶
    signal prev_state_bi : STATE_TYPE := MovingR;

begin
    o_led <= led_r;

    -- 依 ball 選擇球的時脈來源
    ra1 <= clk_div(0) when ball = '0' else clk_div(1);

    clkdiv:process(i_clk, i_rst)
    begin
        if i_rst = '0' then
            clk_div <= (others => '0');
        elsif rising_edge(i_clk) then
            if clk_div(2) = '1' then
                clk_div <= (others => '0');
            else
                clk_div <= clk_div + 1;
            end if;
        end if;
    end process;

    -- 狀態機（不再在這裡設定 ball）
    FSM: process(i_clk, i_rst, i_btL, i_btR, led_r)
    begin
        if i_rst='0' then
            state <= MovingR;
        elsif rising_edge(i_clk) then
            case state is
                when MovingR => -- 球往右移
                    if (led_r < "00000001") or (led_r > "00000001" and i_btR = '1') then
                        state <= Lwin;
                    elsif led_r(0)='1' and i_btR='1' then -- 右邊成功擊球
                        state <= MovingL;
                    end if;

                when MovingL => -- 球往左移
                    if (led_r="00000000") or (led_r < "10000000" and i_btL = '1') then
                        state <= Rwin;
                    elsif led_r(7)='1' and i_btL='1' then -- 左邊成功擊球
                        state <= MovingR;
                    end if;

                when Lwin =>    -- 左勝，左鍵發球開始新回合
                    if i_btL='1' then
                        state <= MovingR;
                    end if;

                when Rwin =>    -- 右勝，右鍵發球開始新回合
                    if i_btR='1' then
                        state <= MovingL;
                    end if;

                when others =>
                    null;
            end case;
        end if;
    end process;

    -- ：球速選擇（在 i_clk 域偵測狀態轉換）
    SpeedSel_P: process(i_clk, i_rst)
    begin
        if i_rst='0' then
            ball <= '1';    
            prev_state_bi  <= MovingR;
        elsif rising_edge(i_clk) then
            if state /= prev_state_bi then
                -- 右邊出球
                if (prev_state_bi = MovingR and state = MovingL) or
                   (prev_state_bi = Rwin    and state = MovingL) then
                    if i_swR = '1' then
                        ball <= '0'; -- 快
                    else
                        ball <= '1'; -- 慢
                    end if;
                end if;

                -- 左邊出球
                if (prev_state_bi = MovingL and state = MovingR) or
                   (prev_state_bi = Lwin    and state = MovingR) then
                    if i_swL = '1' then
                        ball <= '0'; -- 快
                    else
                        ball <= '1'; -- 慢
                    end if;
                end if;

                prev_state_bi <= state;
            end if;
        end if;
    end process;

    -- LED 顯示與發球時球位置初始化（以 ra1 為時脈）
    LED_P: process(i_rst, state, ra1)
    begin
        if i_rst='0' then
            led_r <= "10000000";
            prev_state <= MovingR;
        elsif rising_edge(ra1) then
            if state /= prev_state then
                case state is
                    when MovingR =>
                        led_r <= "10000000";     -- 從左邊發球
                    when MovingL =>
                        led_r <= "00000001";     -- 從右邊發球
                    when Lwin =>
                        led_r <= scoreL & "0000";
                    when Rwin =>
                        led_r <= "0000" & scoreR;
                    when others =>
                        null;
                end case;
            else
                case state is
                    when MovingR =>
                        led_r(7         ) <= '0';
                        led_r(6 downto 0) <= led_r(7 downto 1);
                    when MovingL =>
                        led_r(7 downto 1) <= led_r(6 downto 0);
                        led_r(         0) <= '0';
                    when Lwin =>
                        led_r <= scoreL & "0000";
                    when Rwin =>
                        led_r <= "0000" & scoreR;
                    when others =>
                        null;
                end case;
            end if;
            prev_state <= state;
        end if;
    end process;

    -- 計分
    score_L_p: process(i_clk, i_rst, state)
    begin
        if i_rst='0' then
            scoreL <= "0000";
        elsif rising_edge(i_clk) then
            case state is
                when Lwin =>
                    if L = '1' then
                        scoreL <= scoreL + '1';
                    end if;
                when others =>
                    null;
            end case;
        end if;
    end process;

    score_R_p: process(i_clk, i_rst, state)
    begin
        if i_rst='0' then
            scoreR <= "0000";
        elsif rising_edge(i_clk) then
            case state is
                when Rwin =>
                    if R = '1' then
                        scoreR <= scoreR + '1';
                    end if;
                when others =>
                    null;
            end case;
        end if;
    end process;

    score: process(i_clk, i_rst, state, L)
    begin
        if i_rst='0' then
            L <= '0';
            R <= '0';
        elsif rising_edge(i_clk) then
            case state is
                when MovingR =>
                    L <= '1';
                when MovingL =>
                    R <= '1';
                when Lwin =>
                    L <= '0';
                when Rwin =>
                    R <= '0';
                when others =>
                    null;
            end case;
        end if;
    end process;

end Behavioral;

























LIBRARY ieee;
USE ieee.std_logic_1164.ALL;

ENTITY pingpong_tb IS
END pingpong_tb;

ARCHITECTURE behavior OF pingpong_tb IS

  -- Component Declaration for the Unit Under Test (UUT)
  COMPONENT pingpong
    Port (
      i_clk : in  STD_LOGIC;
      i_rst : in  STD_LOGIC;
      i_btL : in  STD_LOGIC;
      i_btR : in  STD_LOGIC;
      i_swL : in  STD_LOGIC;  -- 新增：左側出球速度選擇
      i_swR : in  STD_LOGIC;  -- 新增：右側出球速度選擇
      o_led : out STD_LOGIC_VECTOR (7 downto 0)
    );
  END COMPONENT;

  -- Inputs
  signal clock : std_logic := '0';
  signal reset : std_logic := '0';
  signal btL   : std_logic := '0';
  signal btR   : std_logic := '0';
  signal swL   : std_logic := '0';  -- 0=慢 clk_div(1), 1=快 clk_div(0)
  signal swR   : std_logic := '0';  -- 0=慢 clk_div(1), 1=快 clk_div(0)

  -- Outputs
  signal led : std_logic_vector(7 downto 0);

  -- Clock period definitions
  constant clock_period : time := 20 ns;

BEGIN

  -- Instantiate the Unit Under Test (UUT)
  uut: pingpong
    PORT MAP (
      i_clk => clock,
      i_rst => reset,
      i_btL => btL,
      i_btR => btR,
      i_swL => swL,
      i_swR => swR,
      o_led => led
    );

  -- Clock process
  clock_process : process
  begin
    clock <= '0';
    wait for clock_period/2;
    clock <= '1';
    wait for clock_period/2;
  end process;

  -- Stimulus process
  stim_proc: process
  begin
    -- 全域重置
    reset <= '0';
    btL   <= '0';
    btR   <= '0';
    swL   <= '0'; -- 左側預設慢速
    swR   <= '0'; -- 右側預設慢速
    wait for 100 ns;
    reset <= '1';

    -- 等遊戲開始移動後，等待球到「最右邊」再由右邊擊球
    -- 此時 swR=0 => 出球使用 clk_div(1)（慢速）
    wait until led = "00000001";
    btR <= '1'; wait for 40 ns; btR <= '0';

    -- 等待球回到左邊邊界，切換左側開關為「快速」，再擊球
    -- swL=1 => 出球使用 clk_div(0)（快速）
    
    wait until led = "10000000";
    swL <= '1';
    btL <= '1';
     wait for 40 ns;
     btL <= '0';
    

  wait for 40 ns;
    swL <= '0';
    wait until led = "00000001";
    swR <= '1';
    btR <= '1'; 
    wait for 40 ns;
     btR <= '0';
    
    wait for 40 ns;
    swR <= '0';
    wait until led = "10000000";
    btL <= '1'; 
    wait for 40 ns; 
    btL <= '0';

    -- 觀察一段時間
    wait for 2 us;

    -- 結束模擬
    wait;
  end process;

END;


