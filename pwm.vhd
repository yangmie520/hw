library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use IEEE.std_logic_unsigned.all;

entity breath is
    Port ( i_clk : in STD_LOGIC;
           i_rst : in STD_LOGIC;
           i_sw  : in STD_LOGIC;  -- ?s?W?G?}????J
           i_btn : in STD_LOGIC;  -- ?s?W?G???s??J
           o_led : out STD_LOGIC
         );
end breath;

architecture Behavioral of breath is
    component hw1_2cnters 
        Port (
           i_clk       : in STD_LOGIC;
           i_rst        : in STD_LOGIC;
           i_upperBound1: in STD_LOGIC_VECTOR (7 downto 0);
           i_upperBound2: in STD_LOGIC_VECTOR (7 downto 0);
           o_state        : out STD_LOGIC
             );           
    end component;
    
    type STATE2TYPE is (gettingBright, gettingDark);
    signal              upbnd1 : STD_LOGIC_VECTOR (7 downto 0);
    signal              upbnd2 : STD_LOGIC_VECTOR (7 downto 0);
    signal              state2 : STATE2TYPE;
    signal alreadyP_PWM_cycles : STD_LOGIC;
    signal              pwmCnt : STD_LOGIC_VECTOR (10 downto 0);
    -- SIM: 調小 P 初值，加速模擬（原本是 (others => '1') = 2047）
    signal                   P : STD_LOGIC_VECTOR (10 downto 0) := "00000001000"; -- P=8
    signal           pwm_pedge : STD_LOGIC;
    signal              pwm : STD_LOGIC;
    signal             pwm_old : STD_LOGIC;
    -- ?s?W?G???s??u????H??
    signal             btn_old : STD_LOGIC;
    signal             btn_pedge : STD_LOGIC;

begin

    hw1: hw1_2cnters 
        port map (
            i_clk         => i_clk,
            i_rst         => i_rst,
            i_upperBound1 => upbnd1,
            i_upperBound2 => upbnd2,
            o_state         => pwm
        );
        
    FSM2: process(i_clk, i_rst, upbnd1, upbnd2)
    begin
        if i_rst = '0' then
            state2 <= gettingBright;
        elsif i_clk'event and i_clk = '1' then
            case state2 is
                when gettingBright =>
                    if upbnd1 = "11111111" then 
                        state2 <= gettingDark;
                    end if;
                when gettingDark =>
                    if upbnd1 = "00000000" then 
                        state2 <= gettingBright;
                    end if;
                when others =>
                    null;
            end case;
        end if;        
    end process;

    upbnd1p: process(i_clk, i_rst, state2, alreadyP_PWM_cycles)
    begin
        if i_rst = '0' then
            upbnd1 <= "00000000";
        elsif i_clk'event and i_clk = '1' then
            case state2 is
                when gettingBright =>
                   if alreadyP_PWM_cycles = '1' then
                       upbnd1 <= upbnd1 + '1';
                   end if;
                when gettingDark =>
                   if alreadyP_PWM_cycles = '1' then
                       upbnd1 <= upbnd1 - '1';
                   end if;
                when others =>
                    null;
            end case;
        end if;
    end process upbnd1p;

    upbnd2p: process(i_clk, i_rst, state2, alreadyP_PWM_cycles)
    begin
        if i_rst = '0' then
            upbnd2 <= "11111111";
        elsif i_clk'event and i_clk = '1' then
            case state2 is
                when gettingBright =>
                   if alreadyP_PWM_cycles = '1' then
                       upbnd2 <= upbnd2 - '1';                    
                   end if;
                when gettingDark =>
                   if alreadyP_PWM_cycles = '1' then                
                      upbnd2 <= upbnd2 + '1';
                   end if;
                when others =>
                    null;
            end case;
        end if;
    end process upbnd2p;
        
    P_PWM_cycles: process(i_clk, i_rst, pwm_pedge)
    begin
        if i_rst = '0' then
            pwmCnt <= "00000000000";
            alreadyP_PWM_cycles <= '0';  
        elsif i_clk'event and i_clk = '1' then        
            if pwmCnt >= P then
                pwmCnt <= "00000000000";
                alreadyP_PWM_cycles <= '1';
            else
                alreadyP_PWM_cycles <= '0';
                if pwm_pedge = '1' then
                    pwmCnt <= pwmCnt+'1';
                end if;
            end if;
        end if;
    end process P_PWM_cycles;

    -- ?s?W?G???s??u???
    detect_btn_edge: process(i_clk, i_rst)
    begin
        if i_rst = '0' then
            btn_pedge <= '0';
            btn_old <= '0';
        elsif i_clk'event and i_clk = '1' then    
            btn_old <= i_btn;
            if btn_old = '0' and i_btn = '1' then
                btn_pedge <= '1';
            else
                btn_pedge <= '0';
            end if;
        end if;
    end process;

    -- ?s?W?GP?????（SIM: 步進改為 1，並調整上下界檢查）
    P_control: process(i_clk, i_rst)
    begin
        if i_rst = '0' then
            P <= "00000001000"; -- SIM: P=8
        elsif i_clk'event and i_clk = '1' then
            if btn_pedge = '1' then -- ???s???U??????
                if i_sw = '1' then -- sw=1, btn=1 -> P+1
                    if P <= "11111111110" then -- <= max-1 避免溢位
                        P <= P + "00000000001";
                    end if;
                else -- sw=0, btn=1 -> P-1
                    if P > "00000000000" then -- > 0 避免 underflow
                        P <= P - "00000000001";
                    end if;
                end if;
            end if;
        end if;
    end process P_control;
	
    detect_PWM_edge: process(i_clk, i_rst, pwm)
    begin
        if i_rst = '0' then
            pwm_pedge <= '0';
            pwm_old <='0';
        elsif i_clk'event and i_clk = '1' then    
            pwm_old <= pwm;
            if pwm_old = '0' and pwm='1' then
                pwm_pedge <= '1';
            else
                pwm_pedge <= '0';
            end if;
        end if;
    end process;

    o_led <= pwm;

end Behavioral;