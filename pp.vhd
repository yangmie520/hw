library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity pp is
    Port (
        i_clk : in STD_LOGIC;
        i_rst : in STD_LOGIC;  -- active-low
        i_btL : in STD_LOGIC;  -- 左邊按鍵（擊球/發球）
        i_btR : in STD_LOGIC;  -- 右邊按鍵（擊球/發球）
        i_swL : in STD_LOGIC;  -- 左邊速度選擇：1=快，0=慢
        i_swR : in STD_LOGIC;  -- 右邊速度選擇：1=快，0=慢
        o_led : out STD_LOGIC_VECTOR (7 downto 0)
    );
end pp;

architecture Behavioral of pp is
    -- 狀態
    type STATE_TYPE is (MovingL, MovingR, Lwin, Rwin);
    signal state      : STATE_TYPE := MovingR;
    signal prev_state : STATE_TYPE := MovingR;
    signal led_r  : STD_LOGIC_VECTOR (7 downto 0) := "10000000";
    signal scoreL : STD_LOGIC_VECTOR (3 downto 0) := "0000";
    signal scoreR : STD_LOGIC_VECTOR (3 downto 0) := "0000";
    signal L : std_logic := '0';
    signal R : std_logic := '0';
    signal clk_div : unsigned(23 downto 0) := (others => '0');
    signal ball : std_logic := '1';
    signal btL_meta, btL_sync, btL_prev, btL_rise : std_logic := '0'; -- sync 防彈跳  prev  前個狀態     rise  避免長按連續發球  
    signal btR_meta, btR_sync, btR_prev, btR_rise : std_logic := '0';
    signal swL_meta, swL_sync : std_logic := '0';
    signal swR_meta, swR_sync : std_logic := '0';
    signal earlyL : std_logic := '0';
    signal earlyR : std_logic := '0';
    signal ball_tick      : std_logic;
    signal ball_tick_edge : std_logic := '0';
    constant FAST_BIT : integer := 22;  
    constant SLOW_BIT : integer := 23;
    signal at_left_end  : std_logic;
    signal at_right_end : std_logic;

begin
    o_led <= led_r;
    at_left_end  <= '1' when led_r = "10000000" else '0';
    at_right_end <= '1' when led_r = "00000001" else '0';

    process(i_clk, i_rst)
    begin
        if i_rst = '0' then
            clk_div <= (others => '0');
        elsif rising_edge(i_clk) then
            clk_div <= clk_div + 1;
        end if;
    end process;

    ball_tick <= std_logic(clk_div(FAST_BIT)) when ball='0' else std_logic(clk_div(SLOW_BIT));

 ball_tic: process(i_clk, i_rst)
        variable prev : std_logic := '0';
    begin
        if i_rst='0' then
            ball_tick_edge <= '0';
            prev := '0';
        elsif rising_edge(i_clk) then
            if ball_tick='1' and prev='0' then
                ball_tick_edge <= '1';
            else
                ball_tick_edge <= '0';
            end if;
            prev := ball_tick;
        end if;
    end process;


  btL_met:  process(i_clk, i_rst)
    begin
        if i_rst='0' then
            btL_meta <= '0';
        elsif rising_edge(i_clk) then
            btL_meta <= i_btL;
        end if;
    end process;

   btL_syn: process(i_clk, i_rst)
    begin
        if i_rst='0' then
            btL_sync <= '0';
        elsif rising_edge(i_clk) then
            btL_sync <= btL_meta;
        end if;
    end process;

    process(i_clk, i_rst)
    begin
        if i_rst='0' then
            btL_prev <= '0';
        elsif rising_edge(i_clk) then
            btL_prev <= btL_sync;
        end if;
    end process;

    btL_rise <= '1' when (btL_sync='1' and btL_prev='0') else '0';

    process(i_clk, i_rst)
    begin
        if i_rst='0' then
            btR_meta <= '0';
        elsif rising_edge(i_clk) then
            btR_meta <= i_btR;
        end if;
    end process;

    process(i_clk, i_rst)
    begin
        if i_rst='0' then
            btR_sync <= '0';
        elsif rising_edge(i_clk) then
            btR_sync <= btR_meta;
        end if;
    end process;

    process(i_clk, i_rst)
    begin
        if i_rst='0' then
            btR_prev <= '0';
        elsif rising_edge(i_clk) then
            btR_prev <= btR_sync;
        end if;
    end process;

    btR_rise <= '1' when (btR_sync='1' and btR_prev='0') else '0';

    process(i_clk, i_rst)
    begin
        if i_rst='0' then
            swL_meta <= '0';
        elsif rising_edge(i_clk) then
            swL_meta <= i_swL;
        end if;
    end process;

    process(i_clk, i_rst)
    begin
        if i_rst='0' then
            swL_sync <= '0';
        elsif rising_edge(i_clk) then
            swL_sync <= swL_meta;
        end if;
    end process;

    process(i_clk, i_rst)
    begin
        if i_rst='0' then
            swR_meta <= '0';
        elsif rising_edge(i_clk) then
            swR_meta <= i_swR;
        end if;
    end process;

    process(i_clk, i_rst)
    begin
        if i_rst='0' then
            swR_sync <= '0';
        elsif rising_edge(i_clk) then
            swR_sync <= swR_meta;
        end if;
    end process;

 
    process(i_clk, i_rst)
    begin
        if i_rst='0' then
            earlyR <= '0';
        elsif rising_edge(i_clk) then
            if state = MovingR then
                if at_right_end = '0' and btR_sync = '1' then
                    earlyR <= '1';
                elsif at_right_end = '1' and ball_tick_edge='1' then
                    earlyR <= '0';
                end if;
            else
                earlyR <= '0';
            end if;
        end if;
    end process;

    process(i_clk, i_rst)
    begin
        if i_rst='0' then
            earlyL <= '0';
        elsif rising_edge(i_clk) then
            if state = MovingL then
                if at_left_end = '0' and btL_sync = '1' then
                    earlyL <= '1';
                elsif at_left_end = '1' and ball_tick_edge='1' then
                    earlyL <= '0';
                end if;
            else
                earlyL <= '0';
            end if;
        end if;
    end process;

    process(i_clk, i_rst)
    begin
        if i_rst='0' then
            state <= MovingR;
        elsif rising_edge(i_clk) then
            case state is
                when MovingR =>
                    if ball_tick_edge='1' and at_right_end='1' then
                        if earlyR='1' then
                            state <= Lwin;             -- 提前按：左勝
                        elsif btR_sync='1' then
                            state <= MovingL;          -- 當拍擊中：反向
                        else
                            state <= Lwin;             -- 慢按/沒按：左勝
                        end if;
                    end if;

                when MovingL =>
                    if ball_tick_edge='1' and at_left_end='1' then
                        if earlyL='1' then
                            state <= Rwin;
                        elsif btL_sync='1' then
                            state <= MovingR;
                        else
                            state <= Rwin;
                        end if;
                    end if;

                when Lwin =>
                    if btL_rise='1' then             
                        state <= MovingR;
                    end if;

                when Rwin =>
                    if btR_rise='1' then
                        state <= MovingL;
                    end if;

                when others =>
                    null;
            end case;
        end if;
    end process;

    process(i_clk, i_rst)
    begin
        if i_rst='0' then
            prev_state <= MovingR;
        elsif rising_edge(i_clk) then
            prev_state <= state;
        end if;
    end process;

    process(i_clk, i_rst)
    begin
        if i_rst='0' then
            ball <= '1';
        elsif rising_edge(i_clk) then
            if (prev_state = MovingR and state = MovingL) or
               (prev_state = Rwin    and state = MovingL) then
                if swR_sync='1' then ball <= '0'; else ball <= '1'; end if;
            end if;

            if (prev_state = MovingL and state = MovingR) or
               (prev_state = Lwin    and state = MovingR) then
                if swL_sync='1' then ball <= '0'; else ball <= '1'; end if;
            end if;
        end if;
    end process;

    process(i_clk, i_rst)
    begin
        if i_rst='0' then
            led_r <= "10000000";
        elsif rising_edge(i_clk) then
            if state = Lwin then
                led_r <= scoreL & "0000";
            elsif state = Rwin then
                led_r <= "0000" & scoreR;
            else
                if (prev_state = Lwin and state = MovingR) then
                    led_r <= "10000000";     -- 左發球
                elsif (prev_state = Rwin and state = MovingL) then
                    led_r <= "00000001";     -- 右發球
                else
                    if ball_tick_edge='1' then
                        if state = MovingR and at_right_end='0' then
                            led_r <= '0' & led_r(7 downto 1);         -- 右移
                        elsif state = MovingL and at_left_end='0' then
                            led_r <= led_r(6 downto 0) & '0';         -- 左移
                        end if;
                    end if;
                end if;
            end if;
        end if;
    end process;

    process(i_clk, i_rst)
    begin
        if i_rst='0' then
            L <= '0';
        elsif rising_edge(i_clk) then
            case state is
                when MovingR => L <= '1';
                when Lwin    => L <= '0';
                when others  => null;
            end case;
        end if;
    end process;

    process(i_clk, i_rst)
    begin
        if i_rst='0' then
            R <= '0';
        elsif rising_edge(i_clk) then
            case state is
                when MovingL => R <= '1';
                when Rwin    => R <= '0';
                when others  => null;
            end case;
        end if;
    end process;

    process(i_clk, i_rst)
    begin
        if i_rst='0' then
            scoreL <= "0000";
        elsif rising_edge(i_clk) then
            if state = Lwin and L = '1' then
                scoreL <= std_logic_vector(unsigned(scoreL) + 1);
            end if;
        end if;
    end process;

    process(i_clk, i_rst)
    begin
        if i_rst='0' then
            scoreR <= "0000";
        elsif rising_edge(i_clk) then
            if state = Rwin and R = '1' then
                scoreR <= std_logic_vector(unsigned(scoreR) + 1);
            end if;
        end if;
    end process;

end Behavioral;

